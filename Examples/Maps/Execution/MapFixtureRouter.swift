import Chio
import Foundation

/// Offline demonstration only; the path was copied from connected OSM segments,
/// not calculated or validated for driving, walking, direction or turn restrictions.
struct MapFixtureRouter {}

extension MapFixtureRouter: MapRoutingProvider {
    func route(_ request: MapRouteRequest) async throws -> MapRouteResponse {
        try Task.checkCancellation()
        let credits = try [MapAttribution(text: "© OpenStreetMap contributors · synthetic road trace",
                                         link: URL(string: "https://www.openstreetmap.org/copyright")!)]
        guard request == MapRoutingDemo.request else {
            return try MapRouteResponse(route: nil, attributions: credits)
        }
        guard let url = Bundle.module.url(forResource: "road-trace", withExtension: "json", subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let path = try JSONDecoder().decode(MapPolyline.self, from: Data(contentsOf: url))
        try Task.checkCancellation()
        return try MapRouteResponse(route: MapRouteResponse.Route(path: path), attributions: credits)
    }
}
