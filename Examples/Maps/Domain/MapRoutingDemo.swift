import Chio

/// Fixed request for the bundled synthetic road trace, within the street extract.
enum MapRoutingDemo {
    static let request = MapRouteRequest(
        origin: try! MapCoordinate(latitude: 1.2930831, longitude: 103.8559769),
        destination: try! MapCoordinate(latitude: 1.2815196, longitude: 103.8587798))
    static let camera = try! MapCamera(
        center: MapCoordinate(latitude: 1.2875, longitude: 103.86), longitudeSpan: 0.04)
}
