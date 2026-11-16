// Spec-derived from the force-unwrap removal contract (C1–C3); separate author.
@testable import Chio
import Foundation
import SwiftTUIRuntime
import Testing

@MainActor
@Suite(.serialized)
struct MapViewForceUnwrapSpecTests {
    @Test("C1: enabled unmodified map keys update the camera and leave unlisted input unchanged",
          arguments: ["left", "right", "up", "down", "+", "=", "-", "q"])
    func keyboardCamera(_ name: String) async throws {
        let key: KeyPress
        let longitude: Double
        let latitude: Double
        let span: Double
        switch name {
        case "left": key = KeyPress(.arrowLeft); longitude = -12; latitude = 0; span = 100
        case "right": key = KeyPress(.arrowRight); longitude = 12; latitude = 0; span = 100
        case "up":
            key = KeyPress(.arrowUp); longitude = 0
            latitude = atan(sinh(12 * .pi / 180)) * 180 / .pi; span = 100
        case "down":
            key = KeyPress(.arrowDown); longitude = 0
            latitude = -atan(sinh(12 * .pi / 180)) * 180 / .pi; span = 100
        case "+": key = KeyPress(.character("+")); longitude = 0; latitude = 0; span = 70
        case "=": key = KeyPress(.character("=")); longitude = 0; latitude = 0; span = 70
        case "-": key = KeyPress(.character("-")); longitude = 0; latitude = 0; span = 100 / 0.7
        default: key = KeyPress(.character("q")); longitude = 0; latitude = 0; span = 100
        }
        try await withScene { session, recorder in
            let initial = try await recorder.wait(description: "unloaded map has its viewport and native focus",
                                                  matching: mapIsReady)
            session.send([.key(key.key), .key(.character("b"), modifiers: .ctrl)])
            let frame = try await recorder.wait(after: initial.sequence, description: "input barrier") {
                $0.raster.lines.contains { $0.contains("Barrier=1") }
            }
            let text = frame.raster.lines.joined(separator: "\n")
            #expect(text.contains(cameraText(longitude: longitude, latitude: latitude, span: span)))
            #expect(text.contains(name == "q" ? "Writes=0 Observed=1" : "Writes=1 Observed=1"))
            #expect(frame.focusedIdentity == initial.focusedIdentity)
        }
    }

    @Test("C1: accepted marker traversal clamps latitude and preserves span; rejected writes do not pan",
          arguments: ["n", "p"], [false, true])
    func markerCentering(_ key: String, rejectsSelection: Bool) async throws {
        try await withScene(rejectsSelection: rejectsSelection) { session, recorder in
            let initial = try await recorder.wait(description: "unloaded map has its viewport and native focus",
                                                  matching: mapIsReady)
            let character: Character = key == "n" ? "n" : "p"
            session.send([.key(.character(character)), .key(.character("b"), modifiers: .ctrl)])
            let frame = try await recorder.wait(after: initial.sequence, description: "selection input barrier") {
                $0.raster.lines.contains { $0.contains("Barrier=1") }
            }
            let text = frame.raster.lines.joined(separator: "\n")
            let latitude = key == "n" ? MapLimits.mercatorLatitude : -MapLimits.mercatorLatitude
            let longitude: Double = key == "n" ? 30 : -40
            #expect(text.contains(cameraText(longitude: rejectsSelection ? 0 : longitude,
                                            latitude: rejectsSelection ? 0 : latitude, span: 100)))
            #expect(text.contains("SelectionAttempts=1"))
            #expect(text.contains(rejectsSelection ? "Selected=nil" : "Selected=\(key == "n" ? "north" : "south")"))
            #expect(text.contains(rejectsSelection ? "Writes=0 Observed=1" : "Writes=1 Observed=1"))
            #expect(frame.focusedIdentity == initial.focusedIdentity)
        }
    }

    private func mapIsReady(_ frame: SemanticHostFrame) -> Bool {
        guard let focused = frame.focusedIdentity,
              frame.semantics.focusRegions.count == 2 else { return false }
        let adjacentIsFocused = frame.semantics.accessibilityNodes.contains {
            $0.role == .button && $0.label == "Adjacent" && $0.identity == focused
        }
        let text = frame.raster.lines.joined(separator: "\n")
        return !adjacentIsFocused && text.contains("No map source loaded")
            && text.contains("Viewport=60x18") && text.contains("Writes=0 Observed=0")
            && text.contains("Barrier=0")
    }

    private func withScene(rejectsSelection: Bool = false,
                           perform: @MainActor (HostedSceneSession, HostedFrameRecorder) async throws -> Void) async throws {
        let recorder = HostedFrameRecorder()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 100, height: 32), appearance: .fallback,
                                          onFrame: { recorder.receive($0) })
        let camera = try MapCamera(center: MapCoordinate(latitude: 0, longitude: 0), longitudeSpan: 100)
        let overlays = try MapOverlays(markers: [
            MapMarker(id: "north", coordinate: MapCoordinate(latitude: 90, longitude: 30)),
            MapMarker(id: "south", coordinate: MapCoordinate(latitude: -90, longitude: -40)),
        ])
        let session = try HostedSceneSession(for: ForceUnwrapMapApp(camera: camera, overlays: overlays,
            rejectsSelection: rejectsSelection), sceneID: "force-unwrap-map-spec", surface: surface)
        let run = Task { try await session.start() }
        do {
            try await perform(session, recorder)
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }
}

private func cameraText(longitude: Double, latitude: Double, span: Double) -> String {
    String(format: "Lon=%.6f Lat=%.6f Span=%.6f", longitude, latitude, span)
}

private struct ForceUnwrapMapApp {
    let camera: MapCamera?
    let overlays: MapOverlays
    let rejectsSelection: Bool

    nonisolated init() { camera = nil; overlays = .empty; rejectsSelection = false }
    nonisolated init(camera: MapCamera, overlays: MapOverlays, rejectsSelection: Bool) {
        self.camera = camera; self.overlays = overlays; self.rejectsSelection = rejectsSelection
    }
}

extension ForceUnwrapMapApp: App {
    var body: some Scene {
        WindowGroup(id: "force-unwrap-map-spec") {
            if let camera {
                ForceUnwrapMapView(camera: camera, overlays: overlays, rejectsSelection: rejectsSelection)
            }
        }.exitOnKeys([])
    }
}

@MainActor
private struct ForceUnwrapMapView {
    let overlays: MapOverlays
    let rejectsSelection: Bool
    @State private var camera: MapCamera
    @State private var selection: String?
    @State private var writes = 0
    @State private var selectionAttempts = 0
    @State private var observed = 0
    @State private var barrier = 0
    @State private var viewport: MapViewport?

    init(camera: MapCamera, overlays: MapOverlays, rejectsSelection: Bool) {
        _camera = State(wrappedValue: camera)
        _selection = State(wrappedValue: nil)
        self.overlays = overlays
        self.rejectsSelection = rejectsSelection
    }

    private var cameraBinding: Binding<MapCamera> {
        let storage = $camera
        let count = $writes
        return Binding(get: { storage.wrappedValue }, set: {
            count.wrappedValue += 1
            storage.wrappedValue = $0
        })
    }

    private var selectionBinding: Binding<String?> {
        let storage = $selection
        let count = $selectionAttempts
        return Binding(get: { storage.wrappedValue }, set: {
            count.wrappedValue += 1
            if !rejectsSelection { storage.wrappedValue = $0 }
        })
    }
}

extension ForceUnwrapMapView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MapView(source: Optional<MapSource>.none, camera: cameraBinding,
                    selection: selectionBinding, overlays: overlays)
                .onViewportChange { viewport = $0 }
                .frame(width: 60, height: 20, alignment: .topLeading)
            Button("Adjacent") {}
            Text(cameraText(longitude: camera.center.longitude, latitude: camera.center.latitude, span: camera.longitudeSpan))
            Text("Writes=\(writes) Observed=\(observed)")
            Text("Selected=\(selection ?? "nil") SelectionAttempts=\(selectionAttempts)")
            Text("Barrier=\(barrier)")
            Text(viewport.map { "Viewport=\($0.columns)x\($0.rows)" } ?? "Viewport=nil")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onKeyPress { press in
            if press.modifiers == .ctrl, press.key == .character("b") {
                barrier += 1
                return .handled
            }
            if press.modifiers.isEmpty {
                // This ancestor observes input before MapView. Returning handled
                // here would consume the very key the test intends to deliver.
                observed += 1
            }
            return .ignored
        }
    }
}
