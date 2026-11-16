import Chio
import SwiftTUI

@MainActor
struct WaveformStudyView {
    let night: WaveformStudyNight
    @State private var window: WaveformStudyWindow
    @State private var appearance: WaveformStudyCommand.Appearance
    @State private var isComparing: Bool
    @FocusState private var isFocused: Bool
    @Environment(\.requestTermination) private var requestTermination

    init(night: WaveformStudyNight, window: WaveformStudyWindow,
         appearance: WaveformStudyCommand.Appearance, compare: Bool) {
        self.night = night
        _window = State(wrappedValue: window)
        _appearance = State(wrappedValue: appearance)
        _isComparing = State(wrappedValue: compare)
    }

    private var style: ChioStyle { appearance.style }

    private var flow: some View {
        GroupBox("Flow · L/min") {
            VStack(spacing: 0) {
                Text(eventTitle).foregroundStyle(style.colors.heading).lineLimit(1)
                eventRow
                HStack(spacing: 1) {
                    VStack { Text("+40"); Spacer(); Text("0 ┤"); Spacer(); Text("−40") }
                        .foregroundStyle(style.colors.mutedText).frame(width: 4)
                    StudyWaveform(samples: night.flow, indices: window.indices, mode: .bipolar(limit: 40))
                }
            }
        }
    }

    private var pressure: some View {
        let bounds = night.pressureBounds(in: window.indices)
        return GroupBox("Pressure · cmH₂O · automatic") {
            if let bounds {
                HStack(spacing: 1) {
                    VStack { Text(String(Int(bounds.upperBound))); Spacer(); Text(String(Int(bounds.lowerBound))) }
                        .foregroundStyle(style.colors.mutedText).frame(width: 4)
                    StudyWaveform(samples: night.pressure, indices: window.indices,
                                  mode: .magnitude(lower: bounds.lowerBound, upper: bounds.upperBound))
                }
            } else {
                Text("Mask off · no known pressure samples").foregroundStyle(style.colors.mutedText)
            }
        }
    }

    private var eventTitle: String {
        let visible = night.events.filter { $0.seconds.overlaps(window.start..<window.end) }
        let kinds: [WaveformStudyNight.Event.Kind] = [.obstructive, .central, .hypopnea, .limitation]
        let counts = "Events" + kinds.map { kind in
            " · \(kind.rawValue) \(visible.filter { $0.kind == kind }.count)"
        }.joined()
        return night.gap.overlaps(window.start..<window.end) ? counts + " · mask off" : counts
    }

    private func color(_ tone: WaveformStudyEventRow.Tone) -> Color {
        switch tone {
        case .error: style.colors.error
        case .warning: style.colors.warning
        case .muted: style.colors.mutedText
        }
    }

    private func eventCells(window: WaveformStudyWindow, width: Int, markersOnly: Bool = false) -> some View {
        let row = WaveformStudyEventRow(events: night.events, window: window, width: width, markersOnly: markersOnly)
        return HStack(spacing: 0) {
            ForEach(Array(row.cells.enumerated()), id: \.offset) { entry in
                Text(String(entry.element.character)).foregroundStyle(color(entry.element.tone))
            }
        }
    }

    private var eventRow: some View {
        HStack(spacing: 1) {
            Text("evt").frame(width: 4).foregroundStyle(style.colors.mutedText)
            GeometryReader { geometry in
                eventCells(window: window, width: geometry.size.width)
            }
        }.frame(height: 1)
    }

    private var overview: some View {
        VStack(spacing: 0) {
            StudyWaveform(samples: night.flow, indices: night.flow.indices, mode: .magnitude(lower: 0, upper: 40),
                          usesAbsoluteValues: true)
                .overlay {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let left = min(max(0, width - 1), window.start * width / WaveformStudyNight.seconds)
                        let right = min(max(0, width - 1), max(left, (window.end * width - 1) / WaveformStudyNight.seconds))
                        ZStack(alignment: .topLeading) {
                            if left == right {
                                Text("│").offset(x: left)
                            } else {
                                Text("[").offset(x: left)
                                Text("]").offset(x: right)
                            }
                        }
                        .foregroundStyle(style.colors.warning)
                    }
                }
                .frame(height: 1)
            GeometryReader { geometry in
                eventCells(window: WaveformStudyWindow(start: 0, length: .night),
                           width: geometry.size.width, markersOnly: true)
            }.frame(height: 1)
        }.frame(height: 2)
    }


}

extension WaveformStudyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("pneuma study · night of 15 Nov · synthetic").foregroundStyle(style.colors.accent)
            Text("\(window.clockRange) · \(window.length.rawValue) · \(appearance.rawValue)")
                .foregroundStyle(style.colors.secondaryText)
            HStack(spacing: 1) {
                flow
                if isComparing { WaveformStudyComparison(night: night, window: window) }
            }.frame(maxHeight: .infinity)
            pressure.frame(height: 7)
            overview
            Text("22:31                       whole night                       06:31")
                .foregroundStyle(style.colors.mutedText).lineLimit(1)
            StatusBar {
                KeyHints {
                    KeyHint("←→", "Pan")
                    KeyHint("+/−", "Zoom")
                    KeyHint("t", "Theme")
                    KeyHint("c", "Compare")
                    KeyHint("e", "Events")
                    KeyHint("q", "Quit")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(style.colors.surface)
        .style(style)
        .focusable()
        .focused($isFocused)
        .defaultFocus($isFocused, true)
        .focusEffectDisabled()
        .onKeyPress { press in
            guard press.modifiers.isEmpty else { return .ignored }
            switch press.key {
            case .arrowLeft: window = window.panned(-1)
            case .arrowRight: window = window.panned(1)
            case .character("+"): window = window.zoomed(1)
            case .character("-"): window = window.zoomed(-1)
            case .character("t"): appearance = appearance.next
            case .character("c"): isComparing.toggle()
            case .character("e"): window = night.nextEventStudyWindow(after: window)
            case .character("q"): _ = requestTermination()
            default: return .ignored
            }
            return .handled
        }
    }
}
