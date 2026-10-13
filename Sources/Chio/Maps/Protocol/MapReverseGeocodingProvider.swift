/// An explicit coordinate lookup effect; applications own submission and publication lifetime.
public protocol MapReverseGeocodingProvider: Sendable {
    func reverse(_ query: MapPlaceLookup) async throws -> MapPlaceMatches
}
