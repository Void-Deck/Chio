import Chio
import Foundation

/// Synthetic, deterministic examples; this provider never accesses the network.
struct MapFixtureGeocoder {}

extension MapFixtureGeocoder: MapGeocodingProvider {
    func search(_ query: MapPlaceQuery) async throws -> MapPlaceMatches {
        try Task.checkCancellation()
        let places = try [
            MapPlace(coordinate: MapCoordinate(latitude: 1.2868, longitude: 103.8545),
                     name: "Merlion", detail: "Synthetic place · Singapore"),
            MapPlace(coordinate: MapCoordinate(latitude: 1.2893, longitude: 103.8631),
                     name: "Singapore Flyer", detail: "Synthetic place · Singapore"),
            MapPlace(coordinate: MapCoordinate(latitude: 48.8584, longitude: 2.2945),
                     name: "Eiffel Tower", detail: "Synthetic place · Paris · outside the street fixture"),
            MapPlace(coordinate: MapCoordinate(latitude: 90, longitude: 0),
                     name: "North Pole", detail: "Synthetic place · outside the Mercator projection")
        ]
        let matching = places.filter { "\($0.name) \($0.detail)".localizedCaseInsensitiveContains(query.text) }
        return try MapPlaceMatches(places: Array(matching.prefix(query.limit)), attributions: [
            MapPlaceMatches.Attribution(text: "Chio synthetic place fixtures", link: URL(string: "https://github.com/echoz/Chio")!)
        ])
    }
}
