import Chio

/// Pure composition of application-owned base and route annotations.
enum MapRouteOverlays {
    static func routed(base: MapOverlays, markers: [MapMarker], routes: [MapRoute]) throws -> MapOverlays {
        try MapOverlays(markers: base.markers + markers, routes: routes)
    }

    static func requestedStart(at origin: MapCoordinate, base: MapOverlays) throws -> MapOverlays {
        let marker = try MapMarker(id: "requested-route-start", coordinate: origin, title: "Requested start")
        return try MapOverlays(markers: base.markers + [marker], routes: [])
    }

    static func rejectionStatus(for error: any Error) -> String {
        switch error {
        case MapValidationError.budgetExceeded:
            return "Route not shown: overlay limit reached · x clear"
        case MapValidationError.duplicateIdentity:
            return "Route not shown: duplicate overlay identity · x clear"
        default:
            return "Route not shown: \(error) · x clear"
        }
    }
}
