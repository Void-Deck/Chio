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
    @FocusState private var focus: Focus?

    enum Focus: Hashable { case map, field, results }
    private let fixtures: MapFixtures
    private let streetSource: MapFixtures.StreetSource
    private let acquisition: MapExampleAcquisition
    private let searchLabel: String
    private let lookupLabel: String

    init(fixtures: MapFixtures, scene: MapFixtures.Scene, appearance: MapExampleCommand.Appearance,
         detail: MapDetail = .minimal,
         streetSource: MapFixtures.StreetSource = .overpass, acquisition: MapExampleAcquisition = .offline,
         geocoder: any MapGeocodingProvider = MapFixtureGeocoder(),
         searchLabel: String = "Synthetic fixtures",
         reverseGeocoder: any MapReverseGeocodingProvider = MapFixtureGeocoder(),
         lookupLabel: String = "Synthetic fixtures") {
        self.fixtures = fixtures
        self.streetSource = streetSource
        self.acquisition = acquisition
        self.searchLabel = searchLabel
        self.lookupLabel = lookupLabel
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
        guard let openedPlace else { return scene.overlays }
        return openedPlace.overlays
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
        if acquisition.usesTiles { return "\(acquisition.title) · \(detail.levelNumber)/\(MapDetail.allCases.count) \(detail.rawValue) · \(appearance.rawValue) · \(areaPresentation) · synthetic guide" }
        let sourceTitle = scene.sourceTitle(streetSource: streetSource)
        return "Offline · \(sourceTitle) · \(detail.levelNumber)/\(MapDetail.allCases.count) \(detail.rawValue) · \(appearance.rawValue) · \(areaPresentation) · synthetic guide"
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
        case .character("q"): owner.close(); _ = requestTermination()
        case .space, .character(" "):
            owner.close()
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
        let submit: @MainActor @Sendable () -> Void = {
            submitSearch(text: draftStorage.wrappedValue, owner: owner, phase: phaseStorage, selection: selectionStorage)
        }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1) {
                Text("chio").bold().foregroundStyle(theme.colors.accent)
                Text("/ maps · \(scene.title)")
            }.frame(height: 1, alignment: .leading)
            if !isSearching || terminalSize.height >= 24 {
                Text(context).foregroundStyle(theme.colors.mutedText)
                    .frame(height: 1, alignment: .leading)
            }
            HStack(alignment: .top, spacing: isSearching && terminalSize.width < 100 ? 0 : 1) {
                mapContent
                    .focused(focusStorage, equals: .map)
                    .onKeyPress { press in
                        guard isSearching else { return .ignored }
                        return mapSearchKey(press, draft: draftStorage, owner: owner, submit: submit)
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
            Text(String(format: "Center %.3f, %.3f · span %.4f°", camera.center.latitude,
                        camera.center.longitude, camera.longitudeSpan))
                .foregroundStyle(theme.colors.secondaryText)
                .frame(height: 1, alignment: .leading)
            Text("Selected: \(selectedTitle) · \(activation)")
                .foregroundStyle(theme.colors.secondaryText)
                .frame(height: 1, alignment: .leading)
            if let openedPlace, !isSearching || terminalSize.width >= 100 {
                ForEach(Array(openedPlace.attributions.indices), id: \.self) { index in
                    Link("Place: \(openedPlace.attributions[index].text)", destination: LinkDestination(openedPlace.attributions[index].link.absoluteString))
                        .foregroundStyle(theme.colors.mutedText).frame(height: 1, alignment: .leading).clipped()
                }
            }
            if !isSearching {
                Text(terminalSize.width >= 80
                     ? "↑↓←→ pan  +/- zoom  n/p place  Return open  / search  space map  q quit"
                     : "/ search  q quit  space map  n/p place")
                    .foregroundStyle(theme.colors.accent)
                    .frame(height: 1, alignment: .leading)
                Text(terminalSize.width >= 80
                     ? "c look up centre  [] detail  t theme  f outline/fill  l labels  r reset"
                     : "c look up centre  [] detail  t theme")
                    .foregroundStyle(theme.colors.mutedText)
                    .frame(height: 1, alignment: .leading)
            }
        }
        .padding(1)
        .frame(width: terminalSize.width, height: terminalSize.height, alignment: .topLeading)
        .onKeyPress { handle($0, owner: owner) }
        .onAppear { focusStorage.wrappedValue = .map }
        .onDisappear { owner.close() }
        .task { await owner.observeLifetime() }
        .chioTheme(theme)
    }

    @ViewBuilder
    private var mapContent: some View {
            if acquisition.usesTiles {
                TiledMapContent(camera: $camera,
                    selection: $selection, overlays: overlays, detail: detail, fillsAreas: fillsAreas,
                    showsLabels: showsLabels, retry: retry, sourceLabel: acquisition.title, activate: { activation = "Opened \($0.title)" },
                    makeLoader: { try await acquisition.makeLoader() })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MapView(source: source, camera: $camera, selection: $selection,
                        overlays: overlays, detail: detail)
                    .mapFills(fillsAreas)
                    .mapLabels(showsLabels)
                    .onActivate { marker in activation = "Opened \(marker.title)" }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    }
}
