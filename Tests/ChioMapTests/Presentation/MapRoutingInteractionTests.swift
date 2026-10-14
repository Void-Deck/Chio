@testable import ChioMaps
import Chio
import Foundation
import SwiftTUIRuntime
import Testing

@MainActor
@Suite(.serialized)
struct MapRoutingInteractionTests {
    @Test("Routing endpoint is explicit, interactive, and independent of tiles and places")
    func commandLine() throws {
        #expect(try MapExampleCommand.parse([]).routerEndpoint.isEmpty)
        #expect(try !MapExampleCommand.parse([]).routeDemo)
        let endpoint = "https://example.test/route/v1/driving"
        let command = try MapExampleCommand.parse(["--router-endpoint", endpoint])
        #expect(command.routerEndpoint == endpoint)
        #expect(!command.online)
        #expect(command.geocoderEndpoint.isEmpty)
        #expect(command.reverseGeocoderEndpoint.isEmpty)
        #expect(try MapExampleCommand.parse(["--route-demo", "--snapshot"]).routeDemo)
        for arguments in [["--router-endpoint", endpoint, "--snapshot"],
                          ["--router-endpoint", endpoint, "--snapshot-json"],
                          ["--router-endpoint", endpoint, "--benchmark"],
                          ["--router-endpoint", "https://example.test"],
                          ["--router-endpoint", "https://user:password@example.test/route/v1/driving"],
                          ["--router-endpoint", "http://example.test/route/v1/driving"],
                          ["--router-endpoint", "https://example.test/route/v1/driving?secret=hidden"],
                          ["--route-demo", "--benchmark"]] {
            #expect(throws: (any Error).self) { try MapExampleCommand.parse(arguments) }
        }
    }

    @Test("Explicit map routing retains credits through pan/style, rejects search typing, and clears honestly")
    func routingKeys() async throws {
        let provider = CountedRoutingFixture()
        let frames = RoutingFrames()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 120, height: 40), appearance: .fallback,
                                          onFrame: { frames.latest = $0 })
        let app = MapExampleApplication(fixtures: try MapFixtures.load(), scene: .world, appearance: .default, router: provider)
        let session = try HostedSceneSession(for: app, sceneID: WindowIdentifier("Chio maps"), surface: surface,
                                            runtimeIssueSink: RuntimeIssueSink { Issue.record("Unexpected routing issue: \($0)") })
        let run = Task { try await session.start() }
        do {
            let initial = try await frames.wait { $0.focusedIdentity != nil && $0.routingText.contains("Center 0.000") }
            session.send(.key(.character("g")))
            let accepted = try await frames.wait(after: initial.sequence) { $0.routingText.contains("Route ready") && !$0.routingText.contains("Preparing map") }
            #expect(accepted.routingText.contains("Synthetic road trace"))
            #expect(accepted.routingText.contains("distance unknown"))
            #expect(accepted.routingText.contains("duration unknown"))
            #expect(accepted.routingText.contains("Route: © OpenStreetMap contributors"))
            #expect(accepted.routingText.contains("Requested 1.2931, 103.8560 → 1.2815, 103.8588"))
            #expect(accepted.routingText.contains("path endpoints may snap"))
            #expect(accepted.routingText.contains("Center 1.288, 103.860 · span 0.0400°"))
            #expect(accepted.routingText.contains("Selected: Routed start"))
            #expect(!accepted.routingText.contains("synthetic guide"))
            #expect(await provider.requests.count == 1)
            session.send([.key(.arrowRight), .key(.character("+")), .key(.character("t"))])
            let moved = try await frames.wait(after: accepted.sequence) { $0.routingText.contains("light") && $0.routingText.contains("span 0.0280°") }
            #expect(moved.routingText.contains("Route: © OpenStreetMap contributors"))
            #expect(await provider.requests.count == 1)
            session.send([.key(.character("/"))] + "gx12".map { .key(.character($0)) })
            let search = try await frames.wait(after: moved.sequence) { $0.routingText.contains("Place search") && $0.routingText.contains("gx12") }
            #expect(await provider.requests.count == 1)
            session.send(.key(.escape))
            let dismissed = try await frames.wait(after: search.sequence) { !$0.routingText.contains("Place search") }
            session.send(.key(.character("1")))
            let start = try await frames.wait(after: dismissed.sequence) { $0.routingText.contains("Requested start set") }
            #expect(!start.routingText.contains("Route: © OpenStreetMap contributors"))
            #expect(await provider.requests.count == 1)
            session.send([.key(.arrowRight), .key(.character("2"))])
            let empty = try await frames.wait(after: start.sequence) { $0.routingText.contains("No route for these locations") }
            let requests = await provider.requests
            #expect(requests.count == 2)
            #expect(requests[1].origin != requests[1].destination)
            #expect(!empty.routingText.contains("Route ready"))
            #expect(empty.routingText.contains("Route: © OpenStreetMap contributors"))
            session.send(.key(.character("x")))
            let cleared = try await frames.wait(after: empty.sequence) { !$0.routingText.contains("No route for these locations") }
            #expect(!cleared.routingText.contains("Requested start set"))
            #expect(await provider.requests.count == 2)
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }

    @Test("Route demo captures use the accepted offline trace in every theme", arguments: MapExampleCommand.Appearance.allCases)
    func captures(_ appearance: MapExampleCommand.Appearance) async throws {
        let capture = try await MapCapture.snapshot(fixtures: MapFixtures.load(), scene: .world, appearance: appearance,
                                                    width: 100, height: 34, routeDemo: true)
        let text = capture.raster.lines.joined(separator: "\n")
        #expect(text.contains("Route ready"))
        #expect(text.contains("Synthetic road trace"))
        #expect(text.contains("Route: © OpenStreetMap contributors"))
        #expect(text.contains("Selected: Routed start"))
        #expect(!text.contains("synthetic guide"))
        let expected = appearance == .light ? Color(hexRGB: 0x00606B) : Color(hexRGB: 0x7DFFF3)
        let routeCells = capture.raster.cells.flatMap { $0 }.filter { cell in
            let isBraille = (0x2801...0x28FF).contains(cell.character.unicodeScalars.first?.value ?? 0)
            return isBraille && cell.style?.foregroundColor == expected
        }
        #expect(routeCells.count > 10)
    }

    @Test("Standard-height route demo retains the selected gold start and suppresses geographic labels")
    func standardHeightCapture() async throws {
        let capture = try await MapCapture.snapshot(fixtures: MapFixtures.load(), scene: .world, appearance: .default,
                                                    width: 100, height: 30, routeDemo: true)
        let text = capture.raster.lines.joined(separator: "\n")
        #expect(text.contains("Route ready"))
        #expect(text.contains("Selected: Routed start"))
        #expect(text.contains("Routed start"))
        #expect(!text.contains("synthetic guide"))
        #expect(!text.contains("Sheares Avenue"))
        #expect(!text.contains("Preparing map"))
        let startCells = capture.raster.cells.flatMap { $0 }.filter { cell in
            let isBraille = (0x2801...0x28FF).contains(cell.character.unicodeScalars.first?.value ?? 0)
            return isBraille && cell.style?.foregroundColor == ChioTheme.default.colors.warning
        }
        #expect(!startCells.isEmpty)
    }

    @Test("Below-minimum route demo preserves native compact fallback and recovers without resubmitting")
    func compactRecovery() async throws {
        let provider = CountedRoutingFixture()
        let frames = RoutingFrames()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 36, height: 18), appearance: .fallback,
                                          onFrame: { frames.latest = $0 })
        let session = try HostedSceneSession(for: MapExampleApplication(fixtures: MapFixtures.load(), scene: .world,
                                                                       appearance: .default, router: provider, routeDemo: true),
                                            sceneID: WindowIdentifier("Chio maps"), surface: surface)
        let run = Task { try await session.start() }
        do {
            let compact = try await frames.wait { $0.routingText.contains("Route ready") && $0.focusedIdentity != nil }
            #expect(compact.routingText.contains("Resize"))
            #expect(await provider.requests.count == 1)
            surface.updateSurfaceSize(CellSize(width: 100, height: 34))
            session.requestSurfaceRefresh()
            let expanded = try await frames.wait(after: compact.sequence) {
                $0.raster.size.width == 100 && $0.routingText.contains("Route ready") && !$0.routingText.contains("Preparing map")
            }
            #expect(expanded.focusedIdentity == compact.focusedIdentity)
            #expect(expanded.routingText.contains("Route: © OpenStreetMap contributors"))
            #expect(await provider.requests.count == 1)
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }
}

private actor CountedRoutingFixture {
    private(set) var requests: [MapRouteRequest] = []
}

extension CountedRoutingFixture: MapRoutingProvider {
    func route(_ request: MapRouteRequest) async throws -> MapRouteResponse {
        requests.append(request)
        return try await MapFixtureRouter().route(request)
    }
}

@MainActor
private final class RoutingFrames {
    var latest: SemanticHostFrame?

    func wait(after sequence: UInt64? = nil, matching predicate: (SemanticHostFrame) -> Bool) async throws -> SemanticHostFrame {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline {
            if let latest, sequence.map({ latest.sequence > $0 }) ?? true, predicate(latest) { return latest }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw FrameTimeout(text: latest?.routingText ?? "No frame received")
    }

    private struct FrameTimeout: Error, CustomStringConvertible {
        let text: String
        var description: String { "Timed out waiting for routing frame:\n\(text)" }
    }
}

private extension SemanticHostFrame {
    var routingText: String { raster.lines.joined(separator: "\n") }
}
