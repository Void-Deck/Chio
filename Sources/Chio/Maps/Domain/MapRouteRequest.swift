/// Explicit submitted endpoints. Equal coordinates and geographic poles remain valid requests.
public struct MapRouteRequest {
    public let origin: MapCoordinate
    public let destination: MapCoordinate

    public init(origin: MapCoordinate, destination: MapCoordinate) {
        self.origin = origin
        self.destination = destination
    }
}

extension MapRouteRequest: Codable {}
extension MapRouteRequest: Hashable {}
extension MapRouteRequest: Sendable {}
