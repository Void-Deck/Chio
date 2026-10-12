@testable import ChioMaps
@testable import Chio
import Foundation
import SwiftTUIRuntime
import Testing

@MainActor
@Suite(.serialized)
struct MapPlaceSearchInteractionTests {
    @Test("Geocoder endpoint is an independent explicit interactive option")
    func commandLine() throws {
        #expect(try MapExampleCommand.parse([]).geocoderEndpoint.isEmpty)
        let endpoint = "https://example.test/api"
        let search = try MapExampleCommand.parse(["--geocoder-endpoint", endpoint])
        #expect(search.geocoderEndpoint == endpoint)
        #expect(!search.online)
        let both = try MapExampleCommand.parse(["--online", "--geocoder-endpoint", endpoint])
        #expect(both.online && both.geocoderEndpoint == endpoint)
        for arguments in [["--geocoder-endpoint", endpoint, "--snapshot"],
                          ["--geocoder-endpoint", "https://user:password@example.test/api"],
                          ["--geocoder-endpoint", "http://example.test/api"],
                          ["--geocoder-endpoint", "https://example.test/api?q=hidden"]] {
            #expect(throws: (any Error).self) { try MapExampleCommand.parse(arguments) }
        }
    }

    @Test("Light result rows keep readable semantic colors as native selection moves")
    func lightRowColors() async throws {
        let frames = PlaceFrames()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 100, height: 30), appearance: .fallback,
                                          onFrame: { frames.latest = $0 })
        let app = MapExampleApplication(fixtures: try MapFixtures.load(), scene: .street, appearance: .light,
                                        geocoder: EightResultGeocoder())
        let session = try HostedSceneSession(for: app, sceneID: WindowIdentifier("Chio maps"), surface: surface)
        let run = Task { try await session.start() }
        do {
            let initial = try await frames.wait { $0.focusedIdentity != nil }
            session.send([.key(.character("/"))] + "eight".map { .key(.character($0)) } + [.key(.return)])
            let matches = try await frames.wait(after: initial.sequence) {
                $0.placeText.contains("8 matches") && $0.focusesPlaceResults
            }
            let selected = try matches.placeRowCells(named: "Fixture 1")
            let unselected = try matches.placeRowCells(named: "Fixture 2")
            #expect(selected.allSatisfy { $0.style?.foregroundColor == ChioTheme.light.colors.foreground })
            #expect(selected.allSatisfy { $0.style?.backgroundColor == ChioTheme.light.colors.selectedSurface })
            #expect(unselected.allSatisfy { $0.style?.foregroundColor == ChioTheme.light.colors.foreground })
            #expect(unselected.allSatisfy { $0.style?.backgroundColor == ChioTheme.light.colors.surface })
            session.send(.key(.arrowDown))
            let moved = try await frames.wait(after: matches.sequence) {
                $0.placeText.contains("Detail for fixture 2") && $0.focusesPlaceResults
            }
            let previous = try moved.placeRowCells(named: "Fixture 1")
            let current = try moved.placeRowCells(named: "Fixture 2")
            #expect(previous.allSatisfy { $0.style?.backgroundColor == ChioTheme.light.colors.surface })
            #expect(current.allSatisfy { $0.style?.foregroundColor == ChioTheme.light.colors.foreground })
            #expect(current.allSatisfy { $0.style?.backgroundColor == ChioTheme.light.colors.selectedSurface })
            #expect(moved.focusedIdentity == matches.focusedIdentity)
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }

    @Test("Eight accepted results scroll compactly without runtime issues and retain focus through expansion")
    func eightResultsViewport() async throws {
        let frames = PlaceFrames()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 36, height: 18), appearance: .fallback,
                                          onFrame: { frames.latest = $0 })
        let app = MapExampleApplication(fixtures: try MapFixtures.load(), scene: .world, appearance: .default,
                                        geocoder: EightResultGeocoder())
        let session = try HostedSceneSession(
            for: app, sceneID: WindowIdentifier("Chio maps"), surface: surface,
            runtimeIssueSink: RuntimeIssueSink { issue in
                Issue.record("Unexpected place-search runtime issue: \(issue)")
            }
        )
        let run = Task { try await session.start() }
        do {
            let initial = try await frames.wait { $0.focusedIdentity != nil }
            session.send([.key(.character("/"))] + "eight".map { .key(.character($0)) } + [.key(.return)])
            let matches = try await frames.wait(after: initial.sequence) {
                $0.placeText.contains("8 matches") && $0.focusesPlaceResults
            }
            #expect(matches.placeText.contains("Center 0.000, 0.000"))
            session.send(Array(repeating: .key(.arrowDown), count: 7))
            let last = try await frames.wait(after: matches.sequence) { $0.placeText.contains("Fixture 8") }
            #expect(last.focusedIdentity == matches.focusedIdentity)
            #expect(last.placeText.contains("Selected: None"))
            #expect(last.placeText.contains("Eight result fixtures"))
            surface.updateSurfaceSize(CellSize(width: 100, height: 30))
            session.requestSurfaceRefresh()
            let expanded = try await frames.wait(after: last.sequence) {
                $0.raster.size.width == 100 && $0.placeText.contains("Detail for fixture 8")
                    && $0.focusesPlaceResults
            }
            #expect(expanded.focusedIdentity == last.focusedIdentity)
            #expect(expanded.placeText.contains("Center 0.000, 0.000 · span 360.0000°"))
            #expect(expanded.placeText.contains("Selected: None"))
            session.send(.key(.return))
            let opened = try await frames.wait(after: expanded.sequence) {
                !$0.placeText.contains("Place search") && $0.placeText.contains("Opened Fixture 8")
            }
            #expect(opened.placeText.contains("Center 8.000, 28.000 · span 360.0000°"))
            #expect(opened.placeText.contains("Place: Eight result fixtures"))
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }

    @Test("Compact search retains a native result row and all four provider credits")
    func compactCredits() async throws {
        let frames = PlaceFrames()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 36, height: 18), appearance: .fallback,
                                          onFrame: { frames.latest = $0 })
        let app = MapExampleApplication(fixtures: try MapFixtures.load(), scene: .world, appearance: .default,
                                        geocoder: CompactCreditGeocoder())
        let session = try HostedSceneSession(for: app, sceneID: WindowIdentifier("Chio maps"), surface: surface)
        let run = Task { try await session.start() }
        do {
            let initial = try await frames.wait { $0.focusedIdentity != nil }
            session.send([.key(.character("/"))] + "fixture".map { .key(.character($0)) } + [.key(.return)])
            let matches = try await frames.wait(after: initial.sequence) {
                $0.placeText.contains("1 match") && $0.placeText.contains("Fixture place")
                    && $0.placeText.contains("Credit 4") && $0.focusesPlaceResults
            }
            for index in 1...4 { #expect(matches.placeText.contains("Credit \(index)")) }
            #expect(!matches.placeText.contains("Supporting detail"))
            session.send(.key(.return))
            let opened = try await frames.wait(after: matches.sequence) {
                !$0.placeText.contains("Place search") && $0.placeText.contains("Selected: Fixture place")
            }
            for index in 1...4 { #expect(opened.placeText.contains("Place: Credit \(index)")) }
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }

    @Test("Search and compact recovery preserve the online tile source and camera independently of geocoding")
    func onlineContinuity() async throws {
        let tiles = PlaceTileRecorder()
        let endpoint = URL(string: "https://example.test")!
        let source = try OpenMapTilesSource(template: "https://example.test/{z}/{x}/{y}.pbf", zoomRange: 1...14,
            metadata: MapSourceMetadata(attribution: "Controlled tile credits", license: "Fixture license",
                                        licenseURL: endpoint, sourceURL: endpoint, sourceRevision: "search-test"))
        let loader = MapTileLoader(source: source, transport: { url, _ in await tiles.fetch(url) })
        let provider = CountedFixtureGeocoder()
        let frames = PlaceFrames()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 140, height: 30), appearance: .fallback,
                                          onFrame: { frames.latest = $0 })
        let app = MapExampleApplication(fixtures: try MapFixtures.load(), scene: .world, appearance: .default,
                                        acquisition: .cached(loader), geocoder: provider)
        let session = try HostedSceneSession(for: app, sceneID: WindowIdentifier("Chio maps"), surface: surface)
        let run = Task { try await session.start() }
        do {
            let initial = try await frames.wait { $0.placeText.contains("Online · z1") && $0.focusedIdentity != nil }
            let initialCount = await tiles.count
            #expect(initialCount == 4)
            session.send([.key(.character("/"))] + "Merlion".map { .key(.character($0)) } + [.key(.return)])
            let matches = try await frames.wait(after: initial.sequence) {
                $0.placeText.contains("1 match") && $0.placeText.contains("Controlled tile credits")
                    && $0.focusesPlaceResults
            }
            #expect(matches.placeText.contains("Center 0.000, 0.000 · span 360.0000°"))
            surface.updateSurfaceSize(CellSize(width: 60, height: 26))
            session.requestSurfaceRefresh()
            let narrow = try await frames.wait(after: matches.sequence) {
                $0.raster.size.width == 60 && $0.placeText.contains("1 match")
            }
            session.send(.key(.escape))
            let recovered = try await frames.wait(after: narrow.sequence) {
                !$0.placeText.contains("Place search") && $0.placeText.contains("Online paused")
                    && $0.placeText.contains("Controlled tile credits")
            }
            #expect(!recovered.placeText.contains("No map source loaded"))
            #expect(recovered.placeText.contains("Center 0.000, 0.000 · span 360.0000°"))
            surface.updateSurfaceSize(CellSize(width: 140, height: 30))
            session.requestSurfaceRefresh()
            _ = try await frames.wait(after: recovered.sequence) {
                $0.placeText.contains("Online · z1") && $0.placeText.contains("Controlled tile credits")
            }
            #expect(await tiles.count == initialCount)
            #expect(await provider.queries == ["Merlion"])
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }

    @Test("Hosted teardown cancels a held search before its late completion can publish")
    func teardown() async throws {
        let provider = TeardownPlaceGeocoder()
        let frames = PlaceFrames()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 100, height: 30), appearance: .fallback,
                                          onFrame: { frames.latest = $0 })
        let app = MapExampleApplication(fixtures: try MapFixtures.load(), scene: .street, appearance: .default,
                                        geocoder: provider)
        let session = try HostedSceneSession(for: app, sceneID: WindowIdentifier("Chio maps"), surface: surface)
        let run = Task { try await session.start() }
        do {
            _ = try await frames.wait { $0.focusedIdentity != nil }
            session.send([.key(.character("/"))] + "held".map { .key(.character($0)) } + [.key(.return)])
            try await provider.waitForStart()
            _ = try await frames.wait { $0.placeText.contains("Searching: held") }
            session.stop()
            #expect(try await run.value == .inputEnded)
            let stoppedSequence = frames.latest?.sequence
            await provider.release()
            try await provider.waitForTermination()
            #expect(await provider.wasCancelled)
            #expect(frames.latest?.sequence == stoppedSequence)
            #expect(frames.latest?.placeText.contains("Fixture place") == false)
        } catch {
            session.stop()
            await provider.release()
            _ = await run.result
            throw error
        }
    }

    @Test("Native search submits explicitly, opens without changing zoom, retains credits and rejects pole projection")
    func nativeInteraction() async throws {
        let provider = CountedFixtureGeocoder()
        let frames = PlaceFrames()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 100, height: 30), appearance: .fallback,
                                          onFrame: { frames.latest = $0 })
        let application = MapExampleApplication(fixtures: try MapFixtures.load(), scene: .street,
                                               appearance: .default, geocoder: provider)
        let session = try HostedSceneSession(for: application, sceneID: WindowIdentifier("Chio maps"), surface: surface)
        let run = Task { try await session.start() }
        do {
            let initial = try await frames.wait { $0.placeText.contains("Center 1.289, 103.866") && $0.focusedIdentity != nil }
            session.send([.key(.character("+")), .key(.character("t"))])
            let zoomed = try await frames.wait(after: initial.sequence) {
                $0.placeText.contains("span 0.0210°") && $0.placeText.contains("light")
            }
            #expect(await provider.queries.isEmpty)
            // All characters arrive in the same input batch as the focus request.
            session.send([.key(.character("/"))] + "Merli".map { .key(.character($0)) })
            let draft = try await frames.wait(after: zoomed.sequence) {
                $0.placeText.contains("Place search") && $0.placeText.contains("Merli") && $0.focusesPlaceField
            }
            #expect(await provider.queries.isEmpty)
            #expect(draft.placeText.contains("Center 1.289, 103.866 · span 0.0210°"))
            // Down has no results to focus yet; native editing must continue.
            session.send([.key(.arrowDown), .key(.character("o")), .key(.character("n"))])
            let completedDraft = try await frames.wait(after: draft.sequence) { $0.placeText.contains("Merlion") }
            #expect(completedDraft.focusedIdentity == draft.focusedIdentity)
            session.send(.key(.return))
            let matches = try await frames.wait(after: draft.sequence) {
                $0.placeText.contains("1 match") && $0.placeText.contains("Synthetic place")
                    && $0.focusesPlaceResults
            }
            #expect(await provider.queries == ["Merlion"])
            #expect(matches.focusedIdentity != completedDraft.focusedIdentity)
            #expect(matches.placeText.contains("Center 1.289, 103.866 · span 0.0210°"))
            surface.updateSurfaceSize(CellSize(width: 60, height: 26))
            session.requestSurfaceRefresh()
            let narrow = try await frames.wait(after: matches.sequence) {
                $0.raster.size.width == 60 && $0.placeText.contains("1 match")
            }
            #expect(await provider.queries == ["Merlion"])
            #expect(narrow.focusedIdentity == matches.focusedIdentity)
            session.send(.key(.return))
            let opened = try await frames.wait(after: narrow.sequence) {
                !$0.placeText.contains("Place search") && $0.placeText.contains("Opened Merlion")
                    && $0.placeText.contains("Center 1.287, 103.855 · span 0.0210°")
            }
            #expect(opened.placeText.contains("Place: Chio synthetic place fixtures"))
            #expect(opened.focusedIdentity != nil)
            surface.updateSurfaceSize(CellSize(width: 100, height: 30))
            session.requestSurfaceRefresh()
            let expanded = try await frames.wait(after: opened.sequence) { $0.raster.size.width == 100 }
            session.send([.key(.character("/"))] + Array(repeating: .key(.backspace), count: 7)
                         + "absent".map { .key(.character($0)) } + [.key(.return)])
            let empty = try await frames.wait(after: expanded.sequence) { $0.placeText.contains("No matches") }
            #expect(empty.placeText.contains("Place: Chio synthetic place fixtures"))
            #expect(empty.placeText.contains("Selected: Merlion"))
            session.send(.key(.escape))
            let dismissed = try await frames.wait(after: empty.sequence) { !$0.placeText.contains("Place search") }
            #expect(dismissed.focusedIdentity == expanded.focusedIdentity)
            session.send([.key(.character("/"))] + Array(repeating: .key(.backspace), count: 6)
                         + "North Pole".map { .key(.character($0)) } + [.key(.return)])
            let pole = try await frames.wait(after: dismissed.sequence) {
                $0.placeText.contains("1 match") && $0.placeText.contains("North Pole") && $0.focusesPlaceResults
            }
            session.send(.key(.return))
            let rejected = try await frames.wait(after: pole.sequence) { $0.placeText.contains("outside Mercator projection") }
            #expect(rejected.placeText.contains("Center 1.287, 103.855 · span 0.0210°"))
            #expect(rejected.placeText.contains("Selected: Merlion"))
            #expect(rejected.placeText.contains("Place: Chio synthetic place fixtures"))
            #expect(await provider.queries == ["Merlion", "absent", "North Pole"])
            session.send(.key(.escape))
            _ = try await frames.wait(after: rejected.sequence) { !$0.placeText.contains("Place search") }
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }
}

private actor CountedFixtureGeocoder {
    private(set) var queries: [String] = []
}

extension CountedFixtureGeocoder: MapGeocodingProvider {
    func search(_ query: MapPlaceQuery) async throws -> MapPlaceMatches {
        queries.append(query.text)
        return try await MapFixtureGeocoder().search(query)
    }
}

@MainActor
private final class PlaceFrames {
    var latest: SemanticHostFrame?

    func wait(after sequence: UInt64? = nil,
              matching predicate: (SemanticHostFrame) -> Bool) async throws -> SemanticHostFrame {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline {
            if let latest, sequence.map({ latest.sequence > $0 }) ?? true, predicate(latest) { return latest }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw FrameTimeout(text: latest?.placeText ?? "No frame received")
    }

    private struct FrameTimeout: Error, CustomStringConvertible {
        let text: String
        var description: String { "Timed out waiting for place search frame:\n\(text)" }
    }
}

private extension SemanticHostFrame {
    var placeText: String { raster.lines.joined(separator: "\n") }
    var focusesPlaceField: Bool {
        semantics.accessibilityNodes.contains {
            $0.identity == focusedIdentity && $0.role == .textField && $0.label == "Place name"
        }
    }
    var focusesPlaceResults: Bool {
        semantics.accessibilityNodes.contains { $0.identity == focusedIdentity && $0.role == .list }
    }

    func placeRowCells(named title: String) throws -> [RasterCell] {
        let list = try #require(semantics.accessibilityNodes.first { $0.role == .list })
        let minX = max(0, list.rect.origin.x)
        let maxX = min(raster.size.width, list.rect.maxX)
        let minY = max(0, list.rect.origin.y)
        let maxY = min(raster.size.height, list.rect.maxY)
        for y in minY..<maxY {
            let cells = Array(raster.cells[y][minX..<maxX])
            let text = cells.map { String($0.character) }.joined()
            if let range = text.range(of: title) {
                let start = text.distance(from: text.startIndex, to: range.lowerBound)
                return Array(cells[start..<(start + title.count)])
            }
        }
        throw MissingPlaceRow(title: title)
    }

    private struct MissingPlaceRow: Error { let title: String }
}

private struct CompactCreditGeocoder {}

extension CompactCreditGeocoder: MapGeocodingProvider {
    func search(_ query: MapPlaceQuery) async throws -> MapPlaceMatches {
        try MapPlaceMatches(places: [MapPlace(coordinate: MapCoordinate(latitude: 1, longitude: 2),
                                             name: "Fixture place", detail: "Supporting detail for a compact place")],
                            attributions: (1...4).map { index in
            try MapPlaceMatches.Attribution(text: "Credit \(index)", link: URL(string: "https://example.test/credit/\(index)")!)
        })
    }
}

private actor TeardownPlaceGeocoder {
    private var held: CheckedContinuation<Void, Never>?
    private var hasStarted = false
    private var hasTerminated = false
    private(set) var wasCancelled = false

    func release() { held?.resume(); held = nil }

    func waitForStart() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !hasStarted, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        guard hasStarted else { throw WaitTimeout() }
    }

    func waitForTermination() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !hasTerminated, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        guard hasTerminated else { throw WaitTimeout() }
    }

    private struct WaitTimeout: Error {}
}

extension TeardownPlaceGeocoder: MapGeocodingProvider {
    func search(_ query: MapPlaceQuery) async throws -> MapPlaceMatches {
        hasStarted = true
        await withCheckedContinuation { held = $0 }
        wasCancelled = Task.isCancelled
        hasTerminated = true
        try Task.checkCancellation()
        return try await CompactCreditGeocoder().search(query)
    }
}

private actor PlaceTileRecorder {
    private(set) var count = 0

    func fetch(_ url: URL) -> MapHTTPClient.Response {
        count += 1
        // An empty protobuf tile is valid; retained cache bytes must survive UI changes.
        return MapHTTPClient.Response(data: Data(), headers: ["cache-control": "max-age=3600"])
    }
}

private struct EightResultGeocoder {}

extension EightResultGeocoder: MapGeocodingProvider {
    func search(_ query: MapPlaceQuery) async throws -> MapPlaceMatches {
        try MapPlaceMatches(places: (1...8).map { index in
            try MapPlace(coordinate: MapCoordinate(latitude: Double(index), longitude: 20 + Double(index)),
                         name: "Fixture \(index)", detail: "Detail for fixture \(index)")
        }, attributions: [MapPlaceMatches.Attribution(text: "Eight result fixtures", link: URL(string: "https://example.test/credits")!)])
    }
}
