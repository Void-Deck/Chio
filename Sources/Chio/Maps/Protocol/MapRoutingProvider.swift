/// Explicit routing effects; applications own submission, publication and overlay identities.
public protocol MapRoutingProvider: Sendable {
    func route(_ request: MapRouteRequest) async throws -> MapRouteResponse
}
