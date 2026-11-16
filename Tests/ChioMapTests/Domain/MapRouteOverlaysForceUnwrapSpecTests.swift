// Spec-derived from the force-unwrap removal contract (C1–C3); separate author.
@testable import ChioMaps
@testable import Chio
import Testing

struct MapRouteOverlaysForceUnwrapSpecTests {
    @Test("C3: routed markers follow base order and supplied routes replace base routes",
          arguments: [false, true])
    func routedComposition(hasRoutes: Bool) throws {
        let first = try marker(id: "base-z", latitude: 1)
        let second = try marker(id: "base-a", latitude: 2)
        let origin = try marker(id: "route-z", latitude: 3)
        let destination = try marker(id: "route-a", latitude: 4)
        let guide = try route(id: "base-guide")
        let base = try MapOverlays(markers: [first, second], routes: [guide])
        let routes = hasRoutes ? try [route(id: "route-z"), route(id: "route-a")] : []

        let composed = try MapRouteOverlays.routed(base: base, markers: [origin, destination], routes: routes)

        #expect(composed.markers == [first, second, origin, destination])
        #expect(composed.routes == routes)
        #expect(!composed.routes.contains(guide))
        #expect(base.markers == [first, second])
        #expect(base.routes == [guide])
    }

    @Test("C3: routed rejects a marker beyond the combined marker budget")
    func routedMarkerBudget() throws {
        let markers = try markersAtLimit()
        let base = try MapOverlays(markers: markers)
        let extra = try marker(id: "route-extra", latitude: 5)

        #expect(throws: MapValidationError.budgetExceeded) {
            try MapRouteOverlays.routed(base: base, markers: [extra], routes: [])
        }
        #expect(base.markers == markers)
    }

    @Test("C3: routed rejects an added marker that repeats a base marker identity")
    func routedDuplicateMarkerIdentity() throws {
        let original = try marker(id: "shared", latitude: 1)
        let duplicate = try marker(id: "shared", latitude: 2)
        let base = try MapOverlays(markers: [original])

        #expect(throws: MapValidationError.duplicateIdentity) {
            try MapRouteOverlays.routed(base: base, markers: [duplicate], routes: [])
        }
        #expect(base.markers == [original])
    }

    @Test("C3: requested start appends its exact marker and drops all base routes")
    func requestedStartComposition() throws {
        let first = try marker(id: "base-z", latitude: 1)
        let second = try marker(id: "base-a", latitude: 2)
        let guide = try route(id: "base-guide")
        let base = try MapOverlays(markers: [first, second], routes: [guide])
        let coordinate = try MapCoordinate(latitude: -12.5, longitude: 104.25)
        let expected = try MapMarker(id: "requested-route-start", coordinate: coordinate, title: "Requested start")

        let composed = try MapRouteOverlays.requestedStart(at: coordinate, base: base)

        #expect(composed.markers == [first, second, expected])
        #expect(composed.routes.isEmpty)
        #expect(base.markers == [first, second])
        #expect(base.routes == [guide])
    }

    @Test("C3: requested start rejects an existing requested-route-start identity")
    func requestedStartDuplicateIdentity() throws {
        let existing = try marker(id: "requested-route-start", latitude: 1)
        let base = try MapOverlays(markers: [existing])
        let coordinate = try MapCoordinate(latitude: 2, longitude: 104)

        #expect(throws: MapValidationError.duplicateIdentity) {
            try MapRouteOverlays.requestedStart(at: coordinate, base: base)
        }
        #expect(base.markers == [existing])
    }

    @Test("C3: requested start rejects a base already at the marker budget")
    func requestedStartMarkerBudget() throws {
        let markers = try markersAtLimit()
        let base = try MapOverlays(markers: markers)
        let coordinate = try MapCoordinate(latitude: 2, longitude: 104)

        #expect(throws: MapValidationError.budgetExceeded) {
            try MapRouteOverlays.requestedStart(at: coordinate, base: base)
        }
        #expect(base.markers == markers)
    }

    @Test("C3: budget rejection has the exact route status")
    func budgetRejectionStatus() {
        #expect(MapRouteOverlays.rejectionStatus(for: MapValidationError.budgetExceeded)
                == "Route not shown: overlay limit reached · x clear")
    }

    @Test("C3: duplicate identity rejection has the exact route status")
    func duplicateRejectionStatus() {
        #expect(MapRouteOverlays.rejectionStatus(for: MapValidationError.duplicateIdentity)
                == "Route not shown: duplicate overlay identity · x clear")
    }

    @Test("C3: another error uses default interpolation in the generic route status")
    func genericRejectionStatus() {
        let error = MapValidationError.invalidCoordinate
        #expect(MapRouteOverlays.rejectionStatus(for: error) == "Route not shown: \(error) · x clear")
    }

    private func marker(id: String, latitude: Double) throws -> MapMarker {
        try MapMarker(id: id, coordinate: MapCoordinate(latitude: latitude, longitude: 103), title: id)
    }

    private func route(id: String) throws -> MapRoute {
        try MapRoute(id: id, title: id, path: MapPolyline(coordinates: [
            MapCoordinate(latitude: 1, longitude: 103),
            MapCoordinate(latitude: 2, longitude: 104),
        ]))
    }

    private func markersAtLimit() throws -> [MapMarker] {
        try (0..<MapLimits.markers).map { try marker(id: "base-\($0)", latitude: 1) }
    }
}
