/// An explicit effect boundary; applications own submission and publication lifetime.
public protocol MapGeocodingProvider: Sendable {
    func search(_ query: MapPlaceQuery) async throws -> MapPlaceMatches
}
