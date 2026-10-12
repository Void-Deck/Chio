import Chio

/// The opened marker retains the credits from its accepted response.
struct MapOpenedPlace {
    let place: MapPlace
    let attributions: [MapPlaceMatches.Attribution]
    let marker: MapMarker
    let overlays: MapOverlays

    init(place: MapPlace, attributions: [MapPlaceMatches.Attribution], overlays: MapOverlays) throws {
        self.place = place
        self.attributions = attributions
        let marker = try MapMarker(id: "opened-search-place", coordinate: place.coordinate, title: place.name)
        self.marker = marker
        self.overlays = try MapOverlays(markers: overlays.markers + [marker], routes: overlays.routes)
    }
}
