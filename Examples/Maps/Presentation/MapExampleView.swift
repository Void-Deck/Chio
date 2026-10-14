import Chio
import Foundation
import SwiftTUI

/// The application owns its map choice, annotations and bound interaction state.
@MainActor
struct MapExampleView {
    @Environment(\.terminalSize) private var terminalSize
    @Environment(\.requestTermination) private var requestTermination
    @State private var scene: MapFixtures.Scene
    @State private var camera: MapCamera
    @State private var selection: String?
    @State private var appearance: MapExampleCommand.Appearance
    @State private var fillsAreas = true
    @State private var showsLabels = true
    @State private var detail: MapDetail
    @State private var activation = "Return opens the selected place"
    @State private var retry = 0
    @State private var isSearching = false
    @State private var searchDraft = ""
    @State private var searchPhase = MapPlaceSearch.Phase.idle
    @State private var resultSelection: Int?
    @State private var searchOwner: MapPlaceSearch
    @State private var openedPlace: MapOpenedPlace?
    @State private var routePhase = MapExampleRouting.Phase.idle
    @State private var routeOwner: MapExampleRouting
    @FocusState private var focus: Focus?

    enum Focus: Hashable { case map, field, results }
    private let fixtures: MapFixtures
    private let streetSource: MapFixtures.StreetSource
    private let acquisition: MapExampleAcquisition
    private let searchLabel: String
    private let lookupLabel: String
    private let routerLabel: String
    private let routeDemo: Bool

    init(fixtures: MapFixtures, scene: MapFixtures.Scene, appearance: MapExampleCommand.Appearance,
         detail: MapDetail = .minimal,
         streetSource: MapFixtures.StreetSource = .overpass, acquisition: MapExampleAcquisition = .offline,
         geocoder: any MapGeocodingProvider = MapFixtureGeocoder(),
         searchLabel: String = "Synthetic fixtures",
         reverseGeocoder: any MapReverseGeocodingProvider = MapFixtureGeocoder(),
         lookupLabel: String = "Synthetic fixtures",
         router: any MapRoutingProvider = MapFixtureRouter(),
         routerLabel: String = "Synthetic road trace", routeDemo: Bool = false) {
        self.fixtures = fixtures
        self.streetSource = streetSource
        self.acquisition = acquisition
        self.searchLabel = searchLabel
        self.lookupLabel = lookupLabel
        self.routerLabel = routerLabel
        self.routeDemo = routeDemo
        _routeOwner = State(wrappedValue: MapExampleRouting(provider: router))
        _searchOwner = State(wrappedValue: MapPlaceSearch(provider: geocoder, reverseProvider: reverseGeocoder))
        _scene = State(wrappedValue: scene)
        _camera = State(wrappedValue: scene.camera)
        _selection = State(wrappedValue: nil)
        _appearance = State(wrappedValue: appearance)
        _detail = State(wrappedValue: detail)
    }

    private var theme: ChioTheme { appearance.theme }
    private var source: MapSource { fixtures.source(for: scene, streetSource: streetSource) }
    private var overlays: MapOverlays {
        let base = openedPlace?.overlays ?? scene.overlays
        switch routePhase {
        case .idle: return base
        case .ready(_, _, _, let route):
            // Remove the authored synthetic guide while a routed path is visible.
            return try! MapOverlays(markers: base.markers + route.markers, routes: route.routes)
        case .start(let origin): return requestedStart(origin, base: base)
        case .loading(let request), .noRoute(let request, _), .failed(let request, _):
            return requestedStart(request.origin, base: base)
        }
    }

    private func requestedStart(_ origin: MapCoordinate, base: MapOverlays) -> MapOverlays {
        let marker = try! MapMarker(id: "requested-route-start", coordinate: origin, title: "Requested start")
        return try! MapOverlays(markers: base.markers + [marker], routes: [])
    }

    private var mapStyle: ChioStyle {
        guard case .ready = routePhase else { return theme }
        let surface = theme.colors.surface
        let surfaceBrightness = (surface.red + surface.green + surface.blue) / 3
        let route = surfaceBrightness > 0.5 ? Color(hexRGB: 0x00606B) : Color(hexRGB: 0x7DFFF3)
        let roads = Self.faded(theme.colors.mutedText, toward: surface, keeping: 0.55)
        return theme.replacing(
            colors: theme.colors.replacing(
                accent: route, foreground: roads, secondaryText: roads,
                selectedSurface: Self.faded(theme.colors.selectedSurface, toward: surface, keeping: 0.45),
                border: Self.faded(theme.colors.border, toward: surface, keeping: 0.55)),
            map: theme.map.replacing(
                water: Self.faded(theme.map.water, toward: surface, keeping: 0.45),
                park: Self.faded(theme.map.park, toward: surface, keeping: 0.45)))
    }

    private static func faded(_ color: Color, toward surface: Color, keeping fraction: Double) -> Color {
        Color(red: surface.red + (color.red - surface.red) * fraction,
              green: surface.green + (color.green - surface.green) * fraction,
              blue: surface.blue + (color.blue - surface.blue) * fraction)
    }

    private var hasRouting: Bool {
        if case .idle = routePhase { return false }
        return true
    }

    private var usesCompactRouting: Bool { hasRouting && !isSearching && terminalSize.width < 80 }

    private var routeAttributions: [MapAttribution] {
        switch routePhase {
        case .idle, .start, .loading, .failed: []
        case .ready(_, _, let attributions, _), .noRoute(_, let attributions): attributions
        }
    }

    private var routeStatus: String? {
        switch routePhase {
        case .idle: return nil
        case .start: return "Requested start set · pan, then 2 to route · x clear"
        case .loading: return "Routing… · \(routerLabel) · x cancel"
        case .noRoute: return "No route for these locations · \(routerLabel) · g demo · x clear"
        case .failed(_, let message): return message
        case .ready(_, let route, _, _):
            let distance = route.distanceMeters.map { String(format: "%.0f m", $0) } ?? "distance unknown"
            let duration = route.durationSeconds.map { String(format: "%.0f s", $0) } ?? "duration unknown"
            return "Route ready · \(routerLabel) · \(distance) · \(duration)"
        }
    }

    private var routeCaption: String? {
        switch routePhase {
        case .idle, .start: return nil
        case .loading(let request), .noRoute(let request, _), .failed(let request, _):
            return requestedCaption(request)
        case .ready(let request, _, _, _):
            return "Requested " + requestedCaption(request) + " · path endpoints may snap"
        }
    }

    private func requestedCaption(_ request: MapRouteRequest) -> String {
        String(format: "%.4f, %.4f → %.4f, %.4f", request.origin.latitude, request.origin.longitude,
               request.destination.latitude, request.destination.longitude)
    }

    private func routeKey(_ press: KeyPress, owner: MapExampleRouting,
                          phase: Binding<MapExampleRouting.Phase>, selection: Binding<String?>) -> KeyPressResult {
        guard press.modifiers.isEmpty else { return .ignored }
        switch press.key {
        case .character("g"):
            openedPlace = nil
            scene = .street
            camera = MapRoutingDemo.camera
            showsLabels = false
            submitRoute(MapRoutingDemo.request, owner: owner, phase: phase, selection: selection)
        case .character("1"):
            owner.cancel()
            phase.wrappedValue = .start(camera.center)
            selection.wrappedValue = nil
        case .character("2"):
            guard let origin = phase.wrappedValue.origin else { return .handled }
            let request = MapRouteRequest(origin: origin, destination: camera.center)
            submitRoute(request, owner: owner, phase: phase, selection: selection)
        case .character("x"):
            owner.cancel()
            phase.wrappedValue = .idle
            selection.wrappedValue = nil
        default: return .ignored
        }
        return .handled
    }

    private func submitRoute(_ request: MapRouteRequest, owner: MapExampleRouting,
                             phase: Binding<MapExampleRouting.Phase>, selection: Binding<String?>) {
        owner.submit(request) { update in
            phase.wrappedValue = update
            switch update {
            case .ready: selection.wrappedValue = "routed-start"
            case .idle, .start, .loading, .noRoute, .failed: selection.wrappedValue = nil
            }
        }
    }

    private func submitSearch(text: String, owner: MapPlaceSearch,
                              phase: Binding<MapPlaceSearch.Phase>, selection: Binding<Int?>) {
        owner.submit(text: text) { update in
            phase.wrappedValue = update
            switch update {
            case .matches(_, let matches, _): selection.wrappedValue = matches.places.isEmpty ? nil : 0
            case .idle, .loading, .failed: selection.wrappedValue = nil
            }
        }
    }

    private func dismissSearch(owner: MapPlaceSearch) {
        owner.close()
        isSearching = false
        focus = .map
        searchPhase = .idle
        resultSelection = nil
    }

    private func lookupCentre(owner: MapPlaceSearch) {
        owner.open()
        isSearching = true
        let phaseStorage = $searchPhase
        let selectionStorage = $resultSelection
        // Snapshot the submitted centre; later camera movement never retargets it.
        owner.lookup(coordinate: camera.center) { update in
            phaseStorage.wrappedValue = update
            switch update {
            case .matches(_, let matches, _): selectionStorage.wrappedValue = matches.places.isEmpty ? nil : 0
            case .idle, .loading, .failed: selectionStorage.wrappedValue = nil
            }
        }
    }

    private func openPlace(_ place: MapPlace, attributions: [MapPlaceMatches.Attribution], owner: MapPlaceSearch) {
        do {
            let replacementCamera = try MapCamera(center: place.coordinate, longitudeSpan: camera.longitudeSpan)
            let replacementPlace = try MapOpenedPlace(place: place, attributions: attributions, overlays: scene.overlays)
            camera = replacementCamera
            openedPlace = replacementPlace
            selection = replacementPlace.marker.id
            activation = "Opened \(place.name)"
            dismissSearch(owner: owner)
        } catch {
            activation = "\(place.name): outside Mercator projection; camera unchanged"
        }
    }

    private func mapSearchKey(_ press: KeyPress, draft: Binding<String>, owner: MapPlaceSearch, submit: @MainActor () -> Void) -> KeyPressResult {
        guard press.modifiers.subtracting(.shift).isEmpty else { return .ignored }
        // This handler belongs only to the map's native focus path. During the
        // transition, preserve type-ahead until input reaches the field itself.
        switch press.key {
        case .escape: dismissSearch(owner: owner)
        case .character(let character):
            draft.wrappedValue.append(character)
        case .space: draft.wrappedValue.append(" ")
        case .backspace:
            if !draft.wrappedValue.isEmpty { draft.wrappedValue.removeLast() }
        case .return: submit()
        default: return .ignored
        }
        return .handled
    }
    private var selectedTitle: String {
        overlays.markers.first(where: { $0.id == selection })?.title ?? "None"
    }
    private var context: String {
        let areaPresentation = fillsAreas ? "filled" : "outlines"
        let overlayPresentation = hasRouting ? "routing" : "synthetic guide"
        if acquisition.usesTiles { return "\(acquisition.title) · \(detail.levelNumber)/\(MapDetail.allCases.count) \(detail.rawValue) · \(appearance.rawValue) · \(areaPresentation) · \(overlayPresentation)" }
        let sourceTitle = scene.sourceTitle(streetSource: streetSource)
        return "Offline · \(sourceTitle) · \(detail.levelNumber)/\(MapDetail.allCases.count) \(detail.rawValue) · \(appearance.rawValue) · \(areaPresentation) · \(overlayPresentation)"
    }

    /// MapView handles pan, zoom, marker traversal and activation through native focus.
    private func handle(_ press: KeyPress, owner: MapPlaceSearch) -> KeyPressResult {
        if press.key == .character("l"), press.modifiers == .ctrl {
            lookupCentre(owner: owner)
            return .handled
        }
        guard press.modifiers.isEmpty else { return .ignored }
        if isSearching {
            if press.key == .escape { dismissSearch(owner: owner); return .handled }
            return .ignored
        }
        switch press.key {
        case .character("/"):
            owner.open()
            isSearching = true
            // Keep the existing map focus until the field has a native registration.
            // Clearing it here drops subsequent events in the opening input batch.
        case .character("c"): lookupCentre(owner: owner)
        case .character("q"): owner.close(); routeOwner.close(); _ = requestTermination()
        case .space, .character(" "):
            owner.close()
            routeOwner.cancel()
            routePhase = .idle
            openedPlace = nil
            scene = scene.next
            camera = scene.camera
            selection = nil
            activation = "Return opens the selected place"
        case .character("t"): appearance = appearance.next
        case .character("["): detail = detail.less
        case .character("]"): detail = detail.more
        case .character("d"): detail = detail.next
        case .character("f"): fillsAreas.toggle()
        case .character("l"): showsLabels.toggle()
        case .character("r"): camera = scene.camera
        case .character("e") where acquisition.usesTiles: retry &+= 1
        default: return .ignored
        }
        return .handled
    }
}

extension MapExampleView: View {
    var body: some View {
        // Retain search slots before the pane mounts so input and completion
        // closures keep the parent-owned storage through focus transitions.
        let draftStorage = $searchDraft
        let phaseStorage = $searchPhase
        let selectionStorage = $resultSelection
        let focusStorage = $focus
        let owner = searchOwner
        let routingOwner = routeOwner
        let routingStorage = $routePhase
        let routeSelectionStorage = $selection
        let submit: @MainActor @Sendable () -> Void = {
            submitSearch(text: draftStorage.wrappedValue, owner: owner, phase: phaseStorage, selection: selectionStorage)
        }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1) {
                Text("chio").bold().foregroundStyle(theme.colors.accent)
                Text("/ maps · \(scene.title)")
            }.frame(height: 1, alignment: .leading)
            if (!isSearching || terminalSize.height >= 24) && !usesCompactRouting {
                Text(context).foregroundStyle(theme.colors.mutedText)
                    .frame(height: 1, alignment: .leading)
            }
            HStack(alignment: .top, spacing: isSearching && terminalSize.width < 100 ? 0 : 1) {
                mapContent
                    .focused(focusStorage, equals: .map)
                    .onKeyPress { press in
                        if isSearching {
                            return mapSearchKey(press, draft: draftStorage, owner: owner, submit: submit)
                        }
                        return routeKey(press, owner: routingOwner, phase: routingStorage, selection: routeSelectionStorage)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(width: isSearching && terminalSize.width < 100 ? 0 : nil)
                    .clipped()
                    .disabled(isSearching && terminalSize.width < 100)
                if isSearching {
                    MapPlaceSearchPane(label: searchLabel, lookupLabel: lookupLabel, draft: draftStorage, phase: phaseStorage.wrappedValue, currentPhase: phaseStorage, isPresented: $isSearching, selection: selectionStorage,
                                       focus: focusStorage, submit: submit, open: { openPlace($0, attributions: $1, owner: owner) })
                        .frame(width: terminalSize.width >= 100 ? 38 : nil)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            if !usesCompactRouting {
                Text(String(format: "Center %.3f, %.3f · span %.4f°", camera.center.latitude,
                            camera.center.longitude, camera.longitudeSpan))
                    .foregroundStyle(theme.colors.secondaryText)
                    .frame(height: 1, alignment: .leading)
                Text("Selected: \(selectedTitle) · \(activation)")
                    .foregroundStyle(theme.colors.secondaryText)
                    .frame(height: 1, alignment: .leading)
            }
            if !isSearching || terminalSize.width >= 100 {
                if let routeStatus {
                    Text(routeStatus).foregroundStyle(theme.colors.secondaryText)
                        .frame(height: 1, alignment: .leading).clipped()
                }
                if let routeCaption, terminalSize.width >= 80 {
                    Text(routeCaption).foregroundStyle(theme.colors.mutedText)
                        .frame(height: 1, alignment: .leading).clipped()
                }
                ForEach(Array(routeAttributions.indices), id: \.self) { index in
                    Link("Route: \(routeAttributions[index].text)", destination: LinkDestination(routeAttributions[index].link.absoluteString))
                        .foregroundStyle(theme.colors.mutedText).frame(height: 1, alignment: .leading).clipped()
                }
            }
            if let openedPlace, !isSearching || terminalSize.width >= 100 {
                ForEach(Array(openedPlace.attributions.indices), id: \.self) { index in
                    Link("Place: \(openedPlace.attributions[index].text)", destination: LinkDestination(openedPlace.attributions[index].link.absoluteString))
                        .foregroundStyle(theme.colors.mutedText).frame(height: 1, alignment: .leading).clipped()
                }
            }
            if usesCompactRouting {
                Text("g demo  1 start  2 route  x clear  q")
                    .foregroundStyle(theme.colors.accent).frame(height: 1, alignment: .leading).clipped()
            } else if !isSearching {
                Text(terminalSize.width >= 80
                     ? "↑↓←→ pan  +/- zoom  n/p place  Return open  / search  space map  q quit"
                     : "/ search  q quit  space map  n/p place")
                    .foregroundStyle(theme.colors.accent)
                    .frame(height: 1, alignment: .leading)
                Text(terminalSize.width >= 80
                     ? "g route demo  1 start  2 route to centre  x clear  c lookup  [] detail  t theme"
                     : "g demo  1 start  2 route  x clear")
                    .foregroundStyle(theme.colors.mutedText)
                    .frame(height: 1, alignment: .leading)
            }
        }
        .padding(1)
        .frame(width: terminalSize.width, height: terminalSize.height, alignment: .topLeading)
        .onKeyPress { handle($0, owner: owner) }
        .onAppear {
            focusStorage.wrappedValue = .map
            if routeDemo {
                scene = .street
                camera = MapRoutingDemo.camera
                showsLabels = false
                submitRoute(MapRoutingDemo.request, owner: routingOwner, phase: routingStorage, selection: routeSelectionStorage)
            }
        }
        .onDisappear { owner.close(); routingOwner.close() }
        .task { await owner.observeLifetime() }
        .task { await routingOwner.observeLifetime() }
        .chioTheme(theme)
    }

    @ViewBuilder
    private var mapContent: some View {
            if acquisition.usesTiles {
                TiledMapContent(camera: $camera,
                    selection: $selection, overlays: overlays, detail: detail, fillsAreas: fillsAreas,
                    showsLabels: showsLabels, retry: retry, sourceLabel: acquisition.title, activate: { activation = "Opened \($0.title)" },
                    makeLoader: { try await acquisition.makeLoader() })
                    .style(mapStyle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MapView(source: source, camera: $camera, selection: $selection,
                        overlays: overlays, detail: detail)
                    .mapFills(fillsAreas)
                    .mapLabels(showsLabels)
                    .onActivate { marker in activation = "Opened \(marker.title)" }
                    .style(mapStyle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    }
}
