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
                eventRow
                HStack(spacing: 1) {
                    VStack { Text("+60"); Spacer(); Text("0 ┤"); Spacer(); Text("−60") }
                        .foregroundStyle(style.colors.mutedText).frame(width: 4)
                    StudyWaveform(samples: night.flow, indices: window.indices, mode: .bipolar(limit: 60))
                }
            }
        }
    }

    private var pressure: some View {
        GroupBox("Pressure · cmH₂O") {
            HStack(spacing: 1) {
                VStack { Text("14"); Spacer(); Text("4") }
                    .foregroundStyle(style.colors.mutedText).frame(width: 4)
                StudyWaveform(samples: night.pressure, indices: window.indices, mode: .magnitude(lower: 4, upper: 14))
            }
        }
    }

    private func color(_ kind: WaveformStudyNight.Event.Kind) -> Color {
        switch kind {
        case .obstructive, .central: style.colors.error
        case .hypopnea: style.colors.warning
        case .limitation: style.colors.mutedText
        }
    }

    private var eventRow: some View {
        HStack(spacing: 1) {
            Text("evt").frame(width: 4).foregroundStyle(style.colors.mutedText)
            GeometryReader { geometry in
                let labels = eventLabels(width: geometry.size.width)
                HStack(spacing: 0) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { entry in
                        Text(entry.element.text).foregroundStyle(entry.element.color)
                    }
                }
            }
        }.frame(height: 1)
    }

    // Place labels in terminal columns. At overview density, earlier labels win
    // collisions; events remain in the fixture and reappear on zoom.
    private func eventLabels(width: Int) -> [(text: String, color: Color)] {
        var result: [(text: String, color: Color)] = []
        var cursor = 0
        var labels = night.events.filter { $0.seconds.overlaps(window.start..<window.end) }.map {
            (second: max(window.start, $0.seconds.lowerBound), text: $0.label, color: color($0.kind))
        }
        if night.gap.overlaps(window.start..<window.end) {
            labels.append((max(window.start, night.gap.lowerBound), "mask off", style.colors.mutedText))
        }
        for label in labels.sorted(by: { $0.second < $1.second }) {
            let column = (label.second - window.start) * max(0, width) / window.length.seconds
            guard column >= cursor, column + label.text.count <= width else { continue }
            result.append((String(repeating: " ", count: column - cursor), style.colors.mutedText))
            result.append((label.text, label.color))
            cursor = column + label.text.count
        }
        return result
    }

    private var overview: some View {
        GeometryReader { geometry in
            Text(overviewText(width: geometry.size.width)).foregroundStyle(style.colors.secondaryText)
        }.frame(height: 1)
    }

    private func overviewText(width: Int) -> String {
        guard width > 1 else { return "" }
        let last = width - 1
        let left = window.start * last / WaveformStudyNight.seconds
        let right = max(left + 1, window.end * last / WaveformStudyNight.seconds)
        return String((0..<width).map { column -> Character in
            if column == left { return "[" }
            if column == min(last, right) { return "]" }
            let second = column * WaveformStudyNight.seconds / width
            if night.gap.contains(second) { return " " }
            if column > left, column < right { return "━" }
            return "─"
        })
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
            case .character("q"): _ = requestTermination()
            default: return .ignored
            }
            return .handled
        }
    }
}
