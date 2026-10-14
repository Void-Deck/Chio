@testable import ChioMaps
import Chio
import Foundation
import Testing

@MainActor
struct MapExampleRoutingTests {
    @Test("Replacement waits for acknowledgement, keeps only latest pending, and rejects stale A-B-A")
    func latestRequest() async throws {
        let provider = HeldRoutingProvider()
        let owner = MapExampleRouting(provider: provider)
        let publications = RoutePublications()
        let a = try request(1)
        let b = try request(2)
        let c = try request(3)
        owner.submit(a, publish: publications.record)
        try await provider.waitForRequests(1)
        owner.submit(b, publish: publications.record)
        owner.submit(c, publish: publications.record)
        owner.submit(a, publish: publications.record)
        #expect(await provider.requests == [a])
        await provider.release(0)
        try await provider.waitForRequests(2)
        #expect(await provider.requests == [a, a])
        #expect(await provider.maximumActive == 1)
        #expect(publications.ready.isEmpty)
        await provider.release(1)
        try await publications.waitForTerminalCount(1)
        #expect(publications.ready.count == 1)
        #expect(publications.credits[0].map(\.text) == ["Response 1"])
        #expect(publications.loading == [a, b, c, a])
        owner.close()
    }

    @Test("Clear and teardown discard pending requests and late completions")
    func cancellation() async throws {
        let provider = HeldRoutingProvider()
        let owner = MapExampleRouting(provider: provider)
        let publications = RoutePublications()
        owner.submit(try request(1), publish: publications.record)
        try await provider.waitForRequests(1)
        owner.submit(try request(2), publish: publications.record)
        owner.cancel()
        await provider.release(0)
        try await provider.waitForCompletions(1)
        owner.submit(try request(3), publish: publications.record)
        try await provider.waitForRequests(2)
        #expect(await provider.requests.map(\.origin.latitude) == [1, 3])
        owner.submit(try request(4), publish: publications.record)
        owner.close()
        await provider.release(1)
        try await provider.waitForCompletions(2)
        await Task.yield()
        owner.submit(try request(5), publish: publications.record)
        #expect(await provider.requests.count == 2)
        #expect(publications.ready.isEmpty)
        #expect(publications.failures == 0)
    }

    @Test("No route is a normal outcome; failure and a later accepted response remain distinct")
    func outcomesAndSnapping() async throws {
        let provider = HeldRoutingProvider()
        let owner = MapExampleRouting(provider: provider)
        let publications = RoutePublications()
        let submitted = try request(1)
        owner.submit(submitted, publish: publications.record)
        try await provider.waitForRequests(1)
        await provider.release(0, outcome: .noRoute)
        try await publications.waitForTerminalCount(1)
        #expect(publications.noRoutes == [submitted])
        #expect(publications.credits[0].map(\.text) == ["Response 0"])
        #expect(publications.failures == 0)
        owner.submit(submitted, publish: publications.record)
        try await provider.waitForRequests(2)
        await provider.release(1, outcome: .failure)
        try await publications.waitForTerminalCount(2)
        #expect(publications.failures == 1)
        owner.submit(submitted, publish: publications.record)
        try await provider.waitForRequests(3)
        await provider.release(2)
        try await publications.waitForTerminalCount(3)
        let overlay = try #require(publications.overlays.first)
        #expect(overlay.markers.map(\.id) == ["routed-start", "routed-finish"])
        // Held provider deliberately returns a snapped start differing from the request.
        #expect(overlay.markers[0].coordinate.latitude == 10)
        #expect(overlay.markers[1].coordinate.latitude == 11)
        #expect(overlay.routes[0].path.coordinates.map(\.latitude) == [10, 11])
        #expect(submitted.origin.latitude == 1)
        owner.close()
    }

    @Test("Bundled trace answers only its exact request and supplies no invented metrics")
    func fixture() async throws {
        let response = try await MapFixtureRouter().route(MapRoutingDemo.request)
        let route = try #require(response.route)
        #expect(route.path.coordinates.count == 84)
        #expect(route.path.coordinates.first?.latitude == 1.2930831)
        #expect(route.path.coordinates.last?.longitude == 103.8587798)
        #expect(route.distanceMeters == nil)
        #expect(route.durationSeconds == nil)
        #expect(response.attributions.map(\.text) == ["© OpenStreetMap contributors · synthetic road trace"])
        let unknown = try await MapFixtureRouter().route(request(1))
        #expect(unknown.route == nil)
    }

    private func request(_ latitude: Double) throws -> MapRouteRequest {
        MapRouteRequest(origin: try MapCoordinate(latitude: latitude, longitude: 2),
                        destination: try MapCoordinate(latitude: latitude + 1, longitude: 3))
    }
}

private actor HeldRoutingProvider {
    enum Outcome { case route, noRoute, failure }
    private(set) var requests: [MapRouteRequest] = []
    private(set) var maximumActive = 0
    private var active = 0
    private var completed = 0
    private var held: [Int: CheckedContinuation<Outcome, Never>] = [:]

    func release(_ index: Int, outcome: Outcome = .route) { held.removeValue(forKey: index)?.resume(returning: outcome) }

    func waitForRequests(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while requests.count < count, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        guard requests.count >= count else { throw WaitTimeout() }
    }

    func waitForCompletions(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while completed < count, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        guard completed >= count else { throw WaitTimeout() }
    }

    private struct WaitTimeout: Error {}
    private struct FixtureFailure: Error {}
}

extension HeldRoutingProvider: MapRoutingProvider {
    func route(_ request: MapRouteRequest) async throws -> MapRouteResponse {
        let index = requests.count
        requests.append(request)
        active += 1
        maximumActive = max(maximumActive, active)
        let outcome = await withCheckedContinuation { held[index] = $0 }
        active -= 1
        completed += 1
        let credits = try [MapAttribution(text: "Response \(index)", link: URL(string: "https://example.test/credits")!)]
        switch outcome {
        case .failure: throw FixtureFailure()
        case .noRoute: return try MapRouteResponse(route: nil, attributions: credits)
        case .route:
            return try MapRouteResponse(route: MapRouteResponse.Route(path: MapPolyline(coordinates: [
                MapCoordinate(latitude: 10, longitude: 20), MapCoordinate(latitude: 11, longitude: 21)
            ])), attributions: credits)
        }
    }
}

@MainActor
private final class RoutePublications {
    private(set) var loading: [MapRouteRequest] = []
    private(set) var ready: [MapRouteResponse.Route] = []
    private(set) var credits: [[MapAttribution]] = []
    private(set) var overlays: [MapOverlays] = []
    private(set) var noRoutes: [MapRouteRequest] = []
    private(set) var failures = 0

    func record(_ phase: MapExampleRouting.Phase) {
        switch phase {
        case .idle, .start: break
        case .loading(let request): loading.append(request)
        case .ready(_, let route, let attributions, let overlay): ready.append(route); credits.append(attributions); overlays.append(overlay)
        case .noRoute(let request, let attributions): noRoutes.append(request); credits.append(attributions)
        case .failed: failures += 1
        }
    }

    func waitForTerminalCount(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ready.count + noRoutes.count + failures < count, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        guard ready.count + noRoutes.count + failures >= count else { throw WaitTimeout() }
    }

    private struct WaitTimeout: Error {}
}
