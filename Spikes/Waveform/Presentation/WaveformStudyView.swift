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
                HStack(spacing: 1) {
                    // The first row lines up with the view's event row, so axis labels match plot rows.
                    VStack(spacing: 0) { Text("evt"); Text("+40"); Spacer(); Text("0 ┤"); Spacer(); Text("−40") }
                        .foregroundStyle(style.colors.mutedText).frame(width: 4)
                    publicPlot(samples: night.waveformFlow, mode: .bipolar, lower: -40, upper: 40, events: night.waveformEvents)
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
                    publicPlot(samples: night.waveformPressure, mode: .magnitude, lower: bounds.lowerBound, upper: bounds.upperBound)
                }
            } else {
                Text("Mask off · no known pressure samples").foregroundStyle(style.colors.mutedText)
            }
        }
    }

    private var eventTitle: String {
        let visible = night.events.filter { $0.seconds.overlaps(window.start..<window.end) }
        let kinds: [WaveformStudyNight.Event.Kind] = [.obstructive, .central, .hypopnea, .limitation]
        let counts = visible.isEmpty ? "no events" : "Events" + kinds.map { kind in
            " · \(kind.rawValue) \(visible.filter { $0.kind == kind }.count)"
        }.joined()
        return night.gap.overlaps(window.start..<window.end) ? counts + " · mask off" : counts
    }

    @ViewBuilder
    private func publicPlot(samples: Result<WaveformSamples, any Error>, mode: WaveformMode,
                            lower: Double, upper: Double, events: Result<[WaveformEvent], any Error> = .success([]),
                            wholeNight: Bool = false) -> some View {
        switch samples {
        case .success(let samples):
            switch Result(catching: {
                let interval = try HistoryInterval(start: .seconds(wholeNight ? 0 : window.start),
                                                   end: .seconds(wholeNight ? WaveformStudyNight.seconds : window.end))
                let scale = try WaveformScale.fixed(lower: lower, upper: upper)
                return (interval, scale, try events.get())
            }) {
            case .success(let (interval, scale, events)):
                Waveform(samples, window: interval, scale: scale, mode: mode, events: events)
            case .failure(let error): Text("Waveform study unavailable: \(error)")
            }
        case .failure(let error): Text("Waveform study unavailable: \(error)")
        }
    }

    private var overview: some View {
        VStack(spacing: 0) {
            publicPlot(samples: night.waveformMagnitude, mode: .magnitude, lower: 0, upper: 40,
                       events: night.waveformEvents, wholeNight: true)
                .overlay {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let left = min(max(0, width - 1), window.start * width / WaveformStudyNight.seconds)
                        let right = min(max(0, width - 1), max(left, (window.end * width - 1) / WaveformStudyNight.seconds))
                        ZStack(alignment: .topLeading) {
                            if left == right {
                                Text("│").offset(x: left, y: 1)
                            } else {
                                Text("[").offset(x: left, y: 1)
                                Text("]").offset(x: right, y: 1)
                            }
                        }
                        .foregroundStyle(style.colors.warning)
                    }
                }
                .frame(height: 2)
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
