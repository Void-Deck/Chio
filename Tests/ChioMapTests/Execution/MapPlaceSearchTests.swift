@testable import ChioMaps
import Chio
import Foundation
import Testing

@MainActor
struct MapPlaceSearchTests {
    @Test("Latest submitted work waits for cancellation acknowledgement and rejects stale A-B-A completion")
    func latestSubmission() async throws {
        let provider = HeldPlaceProvider()
        let owner = MapPlaceSearch(provider: provider)
        let published = PlacePublications()
        owner.open()
        owner.submit(text: "A", publish: published.record)
        try await provider.waitForRequests(1)
        owner.submit(text: "B", publish: published.record)
        owner.submit(text: "C", publish: published.record)
        owner.submit(text: "A", publish: published.record)
        #expect(await provider.texts == ["A"])
        // The held provider deliberately acknowledges cancellation only on release.
        await provider.release(0)
        try await provider.waitForRequests(2)
        #expect(await provider.texts == ["A", "A"])
        #expect(await provider.maximumActive == 1)
        #expect(published.names.isEmpty)
        await provider.release(1)
        try await published.waitForMatches(1)
        #expect(published.names == ["A response 1"])
        owner.submit(text: "A", publish: published.record)
        #expect(published.names == ["A response 1", "A response 1"])
        #expect(await provider.texts == ["A", "A"])
        owner.close()
    }

    @Test("Forward and reverse submissions share one cancellation slot and retain the submitted coordinate")
    func mixedSubmissions() async throws {
        let provider = HeldPlaceProvider()
        let owner = MapPlaceSearch(provider: provider, reverseProvider: provider)
        let published = PlacePublications()
        let first = try MapCoordinate(latitude: 1, longitude: 2)
        let latest = try MapCoordinate(latitude: 3, longitude: 4)
        owner.open()
        owner.submit(text: "A", publish: published.record)
        try await provider.waitForRequests(1)
        owner.lookup(coordinate: first, publish: published.record)
        owner.submit(text: "discard", publish: published.record)
        owner.lookup(coordinate: latest, publish: published.record)
        #expect(await provider.texts == ["A"])
        await provider.release(0)
        try await provider.waitForRequests(2)
        #expect(await provider.coordinates == [latest])
        #expect(await provider.texts == ["A", "reverse"])
        #expect(await provider.maximumActive == 1)
        #expect(published.names.isEmpty)
        await provider.release(1)
        try await published.waitForMatches(1)
        #expect(published.names == ["reverse response 1"])
        #expect(published.subjects == ["Near 3.0000, 4.0000"])
        owner.lookup(coordinate: latest, publish: published.record)
        #expect(published.names.count == 2)
        #expect(await provider.texts.count == 2)
        owner.submit(text: "A", publish: published.record)
        try await provider.waitForRequests(3)
        owner.lookup(coordinate: first, publish: published.record)
        owner.close()
        await provider.release(2)
        try await provider.waitForCompletions(3)
        await Task.yield()
        #expect(published.names.count == 2)
        #expect(await provider.coordinates == [latest])
    }

    @Test("Dismissal discards queued work and racing completion; reopening starts only newly submitted work")
    func dismissal() async throws {
        let provider = HeldPlaceProvider()
        let owner = MapPlaceSearch(provider: provider)
        let published = PlacePublications()
        owner.open()
        owner.submit(text: "before", publish: published.record)
        try await provider.waitForRequests(1)
        owner.submit(text: "discard", publish: published.record)
        owner.close()
        owner.open()
        owner.submit(text: "after", publish: published.record)
        #expect(await provider.texts == ["before"])
        await provider.release(0)
        try await provider.waitForRequests(2)
        #expect(await provider.texts == ["before", "after"])
        #expect(published.names.isEmpty)
        owner.close()
        await provider.release(1)
        try await provider.waitForCompletions(2)
        await Task.yield()
        #expect(published.names.isEmpty)
        #expect(await provider.maximumActive == 1)
    }

    @Test("Invalid submissions never call the provider and retain a distinct failure")
    func invalidSubmission() async throws {
        let provider = HeldPlaceProvider()
        let owner = MapPlaceSearch(provider: provider)
        let published = PlacePublications()
        owner.open()
        owner.submit(text: "  ", publish: published.record)
        #expect(published.failures == 1)
        #expect(await provider.texts.isEmpty)
        owner.close()
    }

    @Test("Fixture matching is attributed even when empty, and an opened marker retains its response credits")
    func fixtureAndOpenedPlace() async throws {
        let provider = MapFixtureGeocoder()
        let empty = try await provider.search(MapPlaceQuery(text: "not a fixture"))
        #expect(empty.places.isEmpty)
        #expect(empty.attributions.map(\.text) == ["Chio synthetic place fixtures"])
        let nearby = try await provider.reverse(MapPlaceLookup(coordinate: MapCoordinate(latitude: 1.289, longitude: 103.866)))
        #expect(nearby.places.map(\.name) == ["Singapore Flyer"])
        #expect(nearby.attributions.map(\.text) == ["Chio synthetic place fixtures"])
        let noNearby = try await provider.reverse(MapPlaceLookup(coordinate: MapCoordinate(latitude: 0, longitude: 0)))
        #expect(noNearby.places.isEmpty)
        #expect(noNearby.attributions.map(\.text) == ["Chio synthetic place fixtures"])
        let matches = try await provider.search(MapPlaceQuery(text: "Singapore"))
        #expect(matches.places.map(\.name) == ["Merlion", "Singapore Flyer"])
        let opened = try MapOpenedPlace(place: matches.places[0], attributions: matches.attributions, overlays: .empty)
        #expect(opened.marker.coordinate.latitude == 1.2868)
        #expect(opened.marker.coordinate.longitude == 103.8545)
        #expect(opened.attributions == matches.attributions)
        #expect(opened.overlays.markers == [opened.marker])
    }
}

private actor HeldPlaceProvider {
    private(set) var texts: [String] = []
    private(set) var coordinates: [MapCoordinate] = []
    private var held: [Int: CheckedContinuation<Void, Never>] = [:]
    private var active = 0
    private(set) var maximumActive = 0
    private var completed = 0

    func release(_ index: Int) { held.removeValue(forKey: index)?.resume() }

    func waitForRequests(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while texts.count < count, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(texts.count >= count)
        guard texts.count >= count else { throw WaitTimeout() }
    }

    func waitForCompletions(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while completed < count, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        guard completed >= count else { throw WaitTimeout() }
    }

    private struct WaitTimeout: Error {}
}

extension HeldPlaceProvider: MapGeocodingProvider {
    func search(_ query: MapPlaceQuery) async throws -> MapPlaceMatches {
        try await respond(text: query.text)
    }
}

extension HeldPlaceProvider: MapReverseGeocodingProvider {
    func reverse(_ query: MapPlaceLookup) async throws -> MapPlaceMatches {
        coordinates.append(query.coordinate)
        return try await respond(text: "reverse")
    }
}

private extension HeldPlaceProvider {
    func respond(text: String) async throws -> MapPlaceMatches {
        let index = texts.count
        texts.append(text)
        active += 1
        maximumActive = max(maximumActive, active)
        await withCheckedContinuation { held[index] = $0 }
        active -= 1
        completed += 1
        return try MapPlaceMatches(places: [
            MapPlace(coordinate: MapCoordinate(latitude: 1, longitude: 2), name: "\(text) response \(index)")
        ], attributions: [MapPlaceMatches.Attribution(text: "Held fixtures", link: URL(string: "https://example.test/credits")!)])
    }
}

@MainActor
private final class PlacePublications {
    var names: [String] = []
    var failures = 0
    var subjects: [String] = []

    func record(_ phase: MapPlaceSearch.Phase) {
        switch phase {
        case .matches(let request, let matches, _):
            names.append(contentsOf: matches.places.map(\.name))
            subjects.append(request.subject)
        case .failed: failures += 1
        case .idle, .loading: break
        }
    }

    func waitForMatches(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while names.count < count, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        guard names.count >= count else { throw WaitTimeout() }
    }

    private struct WaitTimeout: Error {}
}
