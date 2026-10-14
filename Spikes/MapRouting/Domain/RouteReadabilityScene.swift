import Chio
import SwiftTUI

enum RouteReadabilityScene: String {
    case street, hairpin, crossing

    var camera: MapCamera {
        // Fixed fixtures stay inside the retained Singapore extract.
        try! MapCamera(center: MapCoordinate(latitude: 1.2875, longitude: 103.86), longitudeSpan: 0.025)
    }

    func path(street: MapPolyline) throws -> MapPolyline {
        switch self {
        case .street: return street
        case .hairpin:
            return try path([
                (103.854, 1.292), (103.864, 1.292), (103.864, 1.2917),
                (103.855, 1.2917), (103.855, 1.2914), (103.864, 1.2914),
                (103.865, 1.290), (103.865, 1.284), (103.856, 1.283),
            ])
        case .crossing:
            return try path([
                (103.855, 1.292), (103.865, 1.283), (103.855, 1.283),
                (103.865, 1.292), (103.867, 1.288),
            ])
        }
    }

    private func path(_ points: [(Double, Double)]) throws -> MapPolyline {
        try MapPolyline(coordinates: points.map {
            try MapCoordinate(latitude: $0.1, longitude: $0.0)
        })
    }
}

extension RouteReadabilityScene: CaseIterable {}
extension RouteReadabilityScene: ExpressibleByArgument {}
extension RouteReadabilityScene: Sendable {}
