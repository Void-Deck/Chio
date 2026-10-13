import Chio
import Foundation

/// Synthetic, deterministic examples; this provider never accesses the network.
struct MapFixtureGeocoder {
    private func places() throws -> [MapPlace] {
        try [
            MapPlace(coordinate: MapCoordinate(latitude: 1.2868, longitude: 103.8545),
                     name: "Merlion", detail: "Synthetic place · Singapore"),
            MapPlace(coordinate: MapCoordinate(latitude: 1.2893, longitude: 103.8631),
                     name: "Singapore Flyer", detail: "Synthetic place · Singapore"),
            MapPlace(coordinate: MapCoordinate(latitude: 48.8584, longitude: 2.2945),
                     name: "Eiffel Tower", detail: "Synthetic place · Paris · outside the street fixture"),
            MapPlace(coordinate: MapCoordinate(latitude: 90, longitude: 0),
                     name: "North Pole", detail: "Synthetic place · outside the Mercator projection")
        ]
    }

    private func matches(_ places: [MapPlace]) throws -> MapPlaceMatches {
        try MapPlaceMatches(places: places, attributions: [
            MapPlaceMatches.Attribution(text: "Chio synthetic place fixtures", link: URL(string: "https://github.com/echoz/Chio")!)
        ])
    }
}

extension MapFixtureGeocoder: MapGeocodingProvider {
    func search(_ query: MapPlaceQuery) async throws -> MapPlaceMatches {
        try Task.checkCancellation()
        let matching = try places().filter { "\($0.name) \($0.detail)".localizedCaseInsensitiveContains(query.text) }
        return try matches(Array(matching.prefix(query.limit)))
    }
}

extension MapFixtureGeocoder: MapReverseGeocodingProvider {
    private func angularDistance(_ coordinate: MapCoordinate, from origin: MapCoordinate) -> Double {
        let latitude = coordinate.latitude - origin.latitude
        let longitudeDelta = abs(coordinate.longitude - origin.longitude)
        let longitude = min(longitudeDelta, 360 - longitudeDelta)
        return latitude * latitude + longitude * longitude
    }

    func reverse(_ query: MapPlaceLookup) async throws -> MapPlaceMatches {
        try Task.checkCancellation()
        // The fixture only answers near its authored landmarks. This bounded
        // angular window is demo policy, not a distance promise from Photon.
        let nearby = try places().filter {
            let isNearLatitude = abs($0.coordinate.latitude - query.coordinate.latitude) <= 0.05
            let longitudeDelta = abs($0.coordinate.longitude - query.coordinate.longitude)
            let isNearLongitude = min(longitudeDelta, 360 - longitudeDelta) <= 0.05
            return isNearLatitude && isNearLongitude
        }
        let ordered = nearby.sorted {
            angularDistance($0.coordinate, from: query.coordinate) < angularDistance($1.coordinate, from: query.coordinate)
        }
        return try matches(Array(ordered.prefix(query.limit)))
    }
}
