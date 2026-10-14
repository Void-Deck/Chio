import Chio
import SwiftTUI

struct MapExampleApplication {
    private let launch: Launch

    /// Native App requires a default initializer; it has no loaded source to display.
    nonisolated init() { launch = .unconfigured }

    nonisolated init(fixtures: MapFixtures, scene: MapFixtures.Scene, appearance: MapExampleCommand.Appearance,
                     cellAspect: Double? = nil, detail: MapDetail = .minimal,
                     streetSource: MapFixtures.StreetSource = .overpass,
                     acquisition: MapExampleAcquisition = .offline,
                     geocoder: any MapGeocodingProvider = MapFixtureGeocoder(),
                     searchLabel: String = "Synthetic fixtures",
                     reverseGeocoder: any MapReverseGeocodingProvider = MapFixtureGeocoder(),
                     lookupLabel: String = "Synthetic fixtures",
                     router: any MapRoutingProvider = MapFixtureRouter(),
                     routerLabel: String = "Synthetic road trace", routeDemo: Bool = false) {
        launch = .map(fixtures: fixtures, scene: scene, appearance: appearance,
                      cellAspect: cellAspect, detail: detail, streetSource: streetSource, acquisition: acquisition, geocoder: geocoder, searchLabel: searchLabel, reverseGeocoder: reverseGeocoder, lookupLabel: lookupLabel, router: router, routerLabel: routerLabel, routeDemo: routeDemo)
    }

    private enum Launch {
        case unconfigured
        case map(fixtures: MapFixtures, scene: MapFixtures.Scene, appearance: MapExampleCommand.Appearance,
                 cellAspect: Double?, detail: MapDetail, streetSource: MapFixtures.StreetSource,
                 acquisition: MapExampleAcquisition, geocoder: any MapGeocodingProvider, searchLabel: String, reverseGeocoder: any MapReverseGeocodingProvider, lookupLabel: String, router: any MapRoutingProvider, routerLabel: String, routeDemo: Bool)
    }
}

extension MapExampleApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Chio maps") {
            switch launch {
            case .unconfigured:
                Text("Run chio-maps to load the offline examples.")
            case .map(let fixtures, let scene, let appearance, let cellAspect, let detail, let streetSource, let acquisition, let geocoder, let searchLabel, let reverseGeocoder, let lookupLabel, let router, let routerLabel, let routeDemo):
                if let cellAspect {
                    MapExampleView(fixtures: fixtures, scene: scene, appearance: appearance,
                                   detail: detail, streetSource: streetSource, acquisition: acquisition, geocoder: geocoder, searchLabel: searchLabel, reverseGeocoder: reverseGeocoder, lookupLabel: lookupLabel, router: router, routerLabel: routerLabel, routeDemo: routeDemo)
                        .environment(\.cellPixelMetrics, CellPixelMetrics(width: 100, height: Int(cellAspect * 100), source: .reported))
                } else {
                    MapExampleView(fixtures: fixtures, scene: scene, appearance: appearance,
                                   detail: detail, streetSource: streetSource, acquisition: acquisition, geocoder: geocoder, searchLabel: searchLabel, reverseGeocoder: reverseGeocoder, lookupLabel: lookupLabel, router: router, routerLabel: routerLabel, routeDemo: routeDemo)
                }
            }
        }
    }
}
