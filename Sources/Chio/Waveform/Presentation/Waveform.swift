import SwiftTUIViews

/// A passive min/max envelope of a checked fixed-rate signal.
@MainActor
public struct Waveform {
    public static let maximumEvents = 4_096
    @Environment(\.chioStyle) private var theme
    private let samples: WaveformSamples
    private let window: HistoryInterval
    private let scale: WaveformScale
    private let mode: WaveformMode
    private let events: [WaveformEvent]

    public init(_ samples: WaveformSamples, window: HistoryInterval, scale: WaveformScale,
                mode: WaveformMode, events: [WaveformEvent] = []) {
        self.samples = samples
        self.window = window
        self.scale = scale
        self.mode = mode
        self.events = events
    }

    private func unavailable(width: Int, height: Int) -> String? {
        if width > 512 || height > 64 { return "Waveform unavailable: allocation limit exceeded." }
        if events.count > Self.maximumEvents { return "Waveform unavailable: event limit exceeded." }
        if mode == .bipolar, case .fixed(let lower, let upper) = scale.bounds,
           lower > 0 || upper < 0 { return "Waveform unavailable: zero is outside the fixed scale." }
        return nil
    }

    private func summary(_ columns: WaveformColumns, events: [WaveformEvent]) -> String {
        var text = "Waveform: \(columns.knownCount) known samples, \(columns.gapCount) gaps in window."
        if let minimum = columns.minimum, let maximum = columns.maximum {
            text += " Minimum: \(minimum). Maximum: \(maximum)."
        }
        text += " Events: \(events.count)"
        if !events.isEmpty { text += " (" + events.map(\.label).joined(separator: ", ") + ")" }
        return text + "."
    }

    private func color(_ tone: WaveformEvent.Tone) -> Color {
        switch tone {
        case .muted: theme.colors.mutedText
        case .warning: theme.colors.warning
        case .error: theme.colors.error
        }
    }
}

extension Waveform: View {
    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            if let message = unavailable(width: size.width, height: size.height) {
                Text(message).lineLimit(1).accessibilityLabel(message)
            } else {
                let columns = WaveformColumns(samples: samples, window: window, count: max(0, size.width * 2))
                let row = WaveformEventRow(events: events, window: window, width: size.width)
                let bounds = WaveformBounds(scale: scale, mode: mode, columns: columns)
                let plotHeight = max(0, size.height - (events.isEmpty ? 0 : 1))
                VStack(spacing: 0) {
                    if !events.isEmpty, size.height > 0 {
                        HStack(spacing: 0) {
                            ForEach(Array(row.cells.enumerated()), id: \.offset) { entry in
                                Text(String(entry.element.character)).foregroundStyle(color(entry.element.tone))
                            }
                        }.frame(height: 1)
                    }
                    Canvas(WaveformDrawing(columns: columns.columns, bounds: bounds, mode: mode,
                                           accent: theme.colors.accent, muted: theme.colors.mutedText), grid: .braille2x4)
                        .frame(width: size.width, height: plotHeight)
                }
                .accessibilityLabel(summary(columns, events: row.visible))
            }
        }
    }
}

private struct WaveformDrawing {
    let columns: [WaveformColumns.Span?]
    let bounds: WaveformBounds
    let mode: WaveformMode
    let accent: Color
    let muted: Color
}

extension WaveformDrawing: CanvasDrawing {
    func draw(into context: inout CanvasContext) {
        let height = context.gridSize.height
        guard height > 0 else { return }
        let zero = bounds.row(0, height: height)
        // Paint all muted cells first so trace color wins even in adjacent dot columns.
        switch mode {
        case .bipolar:
            for column in columns.indices {
                context.setPixel(at: Point(x: Double(column) / 2, y: Double(zero) / 4), foreground: muted)
            }
        case .magnitude: break
        }
        for (column, span) in columns.enumerated() {
            guard let span else { continue }
            let top = bounds.row(span.maximum, height: height)
            let bottom: Int
            switch mode {
            case .bipolar: bottom = bounds.row(span.minimum, height: height)
            case .magnitude: bottom = height - 1
            }
            for row in top...max(top, bottom) {
                context.setPixel(at: Point(x: Double(column) / 2, y: Double(row) / 4), foreground: accent)
            }
        }
    }
}
