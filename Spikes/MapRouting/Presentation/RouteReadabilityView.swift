import Chio
import SwiftTUI

@MainActor
struct RouteReadabilityView {
    let source: MapSource
    let overlays: MapOverlays
    let scene: RouteReadabilityScene
    let style: ChioStyle
    let mapStyle: ChioStyle
    let detail: MapDetail
    @State private var camera: MapCamera
    @State private var selection: String?
    @State private var showsFills: Bool
    @State private var showsLabels: Bool
    @Environment(\.requestTermination) private var requestTermination

    init(source: MapSource, overlays: MapOverlays, scene: RouteReadabilityScene,
         style: ChioStyle, detail: MapDetail, fills: Bool, labels: Bool, mutedRoads: Bool, selection: String?) {
        self.source = source
        self.overlays = overlays
        self.scene = scene
        self.style = style
        if mutedRoads {
            let surface = style.colors.surface
            let surfaceBrightness = (surface.red + surface.green + surface.blue) / 3
            let route = surfaceBrightness > 0.5 ? Color(hexRGB: 0x00606B) : Color(hexRGB: 0x7DFFF3)
            let roads = Self.faded(style.colors.mutedText, toward: surface, keeping: 0.55)
            mapStyle = style.replacing(
                colors: style.colors.replacing(
                    accent: route, foreground: roads, secondaryText: roads,
                    selectedSurface: Self.faded(style.colors.selectedSurface, toward: surface, keeping: 0.45),
                    border: Self.faded(style.colors.border, toward: surface, keeping: 0.55)),
                map: style.map.replacing(
                    water: Self.faded(style.map.water, toward: surface, keeping: 0.45),
                    park: Self.faded(style.map.park, toward: surface, keeping: 0.45)))
        } else {
            mapStyle = style
        }
        self.detail = detail
        _camera = State(wrappedValue: scene.camera)
        _selection = State(wrappedValue: selection)
        _showsFills = State(wrappedValue: fills)
        _showsLabels = State(wrappedValue: labels)
    }

    private static func faded(_ color: Color, toward surface: Color, keeping fraction: Double) -> Color {
        Color(red: surface.red + (color.red - surface.red) * fraction,
              green: surface.green + (color.green - surface.green) * fraction,
              blue: surface.blue + (color.blue - surface.blue) * fraction)
    }
}

extension RouteReadabilityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("chio / route readability · \(scene.rawValue)")
                .foregroundStyle(style.colors.accent)
            Text("Geometry experiment · not navigation")
                .foregroundStyle(style.colors.mutedText)
            MapView(source: source, camera: $camera, selection: $selection,
                    overlays: overlays, detail: detail)
                .mapFills(showsFills)
                .mapLabels(showsLabels)
                .style(mapStyle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("↑↓←→ pan  +/- zoom  n/p endpoints  o fills  l labels  r reset  q quit")
                .foregroundStyle(style.colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(style.colors.surface)
        .style(style)
        .environment(\.cellPixelMetrics, CellPixelMetrics(width: 12, height: 24, source: .reported))
        .onKeyPress { press in
            guard press.modifiers.isEmpty else { return .ignored }
            switch press.key {
            case .character("o"): showsFills.toggle()
            case .character("l"): showsLabels.toggle()
            case .character("r"): camera = scene.camera; selection = nil
            case .character("q"): _ = requestTermination()
            default: return .ignored
            }
            return .handled
        }
    }
}
