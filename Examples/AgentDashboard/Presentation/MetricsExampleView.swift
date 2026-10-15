import Chio
import SwiftTUI

/// A local composition: the application owns simulated collection and retention.
@MainActor
struct MetricsExampleView {
    @Environment(\.terminalSize) private var terminalSize
    @Environment(\.requestTermination) private var requestTermination
    @State private var themeChoice: ExampleTheme
    @State private var history: History = .populated
    @State private var sampleIndex = 0
    @State private var gaugeStyle: MeasurementGauge.Style

    private static let processorFixture: [Double] = [
        22, 28, 24, 36, 42, 34, 48, 57, 45, 38, 52, 67,
        74, 61, 49, 56, 78, 100, 83, 69, 55, 46, 58, 62,
    ]
    private static let memoryFixture: [Double] = [
        48, 48, 49, 50, 51, 51, 53, 55, 54, 56, 58, 60,
        61, 63, 64, 65, 65, 67, 68, 69, 68, 70, 71, 71,
    ]

    private static let targetBand: MeasurementGauge.TargetBand = {
        do {
            return try MeasurementGauge.TargetBand(lowerBound: 0.45, upperBound: 0.60)
        } catch {
            preconditionFailure("Invalid local metrics target: \(error)")
        }
    }()

    init(theme: ExampleTheme = .btop, gaugeStyle: MeasurementGauge.Style = .bar) {
        _themeChoice = State(wrappedValue: theme)
        _gaugeStyle = State(wrappedValue: gaugeStyle)
    }

    private enum History: String {
        case populated = "full", gaps, empty

        var next: Self {
            switch self {
            case .populated: .gaps
            case .gaps: .empty
            case .empty: .populated
            }
        }

        func displaying(_ samples: [Double?]) -> [Double?] {
            switch self {
            case .populated: samples
            case .gaps: samples.enumerated().map { $0.offset % 7 == 3 ? nil : $0.element }
            case .empty: []
            }
        }
    }

    private var theme: ChioStyle { themeChoice.theme }
    private var isWide: Bool { terminalSize.width >= 70 }
    private var isCompact: Bool { !isWide || terminalSize.height < 24 }
    // The complete expanded composition needs 28 rows with five-row dials,
    // compared with 24 rows for one-row bars. Retain the user's preference.
    private var canDisplayDials: Bool { isWide && terminalSize.height >= 28 }
    private var displayedGaugeStyle: MeasurementGauge.Style {
        if canDisplayDials { return gaugeStyle }
        return .bar
    }
    private var isDisplayingDials: Bool {
        switch displayedGaugeStyle {
        case .bar: false
        case .dial: true
        }
    }
    private var targetCaption: String {
        let lowerPercent = Int(Self.targetBand.range.lowerBound * 100)
        let upperPercent = Int(Self.targetBand.range.upperBound * 100)
        return "Target \(lowerPercent)–\(upperPercent)%"
    }
    private var targetSummary: String {
        let lowerPercent = Int(Self.targetBand.range.lowerBound * 100)
        let upperPercent = Int(Self.targetBand.range.upperBound * 100)
        return "target \(lowerPercent) to \(upperPercent) percent"
    }
    private var panelWidth: Int {
        if isWide {
            let panelSpacing = isCompact ? 2 : 4
            return (min(100, terminalSize.width) - panelSpacing) / 2
        } else {
            return terminalSize.width
        }
    }
    private var meterWidth: Int { max(1, panelWidth - 4) }
    private var gaugeLabel: String {
        switch gaugeStyle {
        case .bar: return "Bars"
        case .dial:
            if canDisplayDials { return "Dials" }
            return "Dials (compact bars)"
        }
    }

    private func toggleGauge() {
        switch gaugeStyle {
        case .bar: gaugeStyle = .dial
        case .dial: gaugeStyle = .bar
        }
    }

    private var processorSamples: [Double?] { samples(Self.processorFixture) }
    private var memorySamples: [Double?] { samples(Self.memoryFixture) }

    private func samples(_ fixture: [Double]) -> [Double?] {
        (Array(fixture.dropFirst(sampleIndex)) + Array(fixture.prefix(sampleIndex))).map { $0 }
    }

    private func nextSample() {
        // One manual step represents one simulated second. Retain only 24 samples;
        // the passive graph has no clock, retention policy or system sampler.
        sampleIndex = (sampleIndex + 1) % Self.processorFixture.count
    }

    private func historySummary(_ title: String, samples: [Double?]) -> String {
        let displayed = history.displaying(samples)
        let readings = displayed.compactMap { $0 }
        let prefix = "\(title) history, simulated, \(history.rawValue), 0 to 100 percent."
        guard let minimum = readings.min(), let maximum = readings.max() else {
            return "\(prefix) No readings."
        }
        let latest = displayed.last.flatMap { $0 }.map { "\(Int($0)) percent" } ?? "unavailable"
        return "\(prefix) \(readings.count) readings, \(displayed.count - readings.count) missing. Latest: \(latest). Minimum: \(Int(minimum)) percent. Maximum: \(Int(maximum)) percent."
    }

    private func panel(_ title: String, label: String, samples: [Double?]) -> some View {
        let current = samples.last.flatMap { $0 }
        let reading = current.map { "\(Int($0))" } ?? "Unavailable"
        let valueCaption = current.map { "\(Int($0))%" } ?? "Unavailable"
        let valueSummary = current.map { "\(label) utilization: \(Int($0)) percent" }
            ?? "\(label) utilization: unavailable"
        let gaugeSummary = isDisplayingDials
            ? "\(valueSummary), \(targetSummary), scale 0 to 100 percent"
            : "\(valueSummary), scale 0 to 100 percent"
        return GroupBox(title) {
            VStack(alignment: .leading, spacing: 0) {
                if !isCompact {
                    InstrumentReadout(reading)
                        .accessibilityHidden(true)
                }
                HStack(spacing: 1) {
                    Text(isDisplayingDials ? "\(label) current" : label)
                        .foregroundStyle(theme.colors.secondaryText)
                    Spacer(minLength: 1)
                    Text(valueCaption)
                        .foregroundStyle(theme.colors.accent)
                        .accessibilityLabel(valueSummary)
                }
                MeasurementGauge(position: current.map { $0 / 100 },
                                 targetBand: isDisplayingDials ? Self.targetBand : nil,
                                 style: displayedGaugeStyle)
                    .frame(width: meterWidth)
                    .accessibilityLabel(gaugeSummary)
                Sparkline(history.displaying(samples), scale: .fixed(0...100))
                    .frame(height: isWide ? 4 : 2)
                    .accessibilityLabel(historySummary(title, samples: samples))
                if !isCompact {
                    HStack {
                        if isDisplayingDials {
                            Text(targetCaption).foregroundStyle(theme.gauge.target)
                            Spacer(minLength: 1)
                            Text("Scale 0–100%")
                        } else {
                            Text("24 samples · 1s / step")
                            Spacer(minLength: 1)
                            Text("0–100%")
                        }
                    }
                    .foregroundStyle(theme.colors.mutedText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: isWide ? panelWidth : nil)
    }

    private var hints: some View {
        KeyHints {
            KeyHint("n", "next")
            KeyHint("g", "history")
            KeyHint("v", "gauge")
            KeyHint("^T", "theme")
            KeyHint("^Q", "quit")
        }
    }
}

extension MetricsExampleView: View {
    var body: some View {
        let layout = isWide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 2))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1) {
                Text("chio").bold().foregroundStyle(theme.colors.accent)
                Text("/ metrics · simulated").foregroundStyle(theme.colors.secondaryText)
            }
            if !isCompact {
                Text("Local samples, advanced by you. \(gaugeLabel) · v toggles.")
                    .foregroundStyle(theme.colors.mutedText)
                Spacer().frame(height: 1)
            }
            layout {
                panel("Processor", label: "CPU", samples: processorSamples)
                panel("Memory", label: "RAM", samples: memorySamples)
            }
            .groupBoxStyle(ChioGroupBoxStyle(theme: theme.replacing(
                spacing: theme.spacing.replacing(verticalInset: 0, sectionGap: 0)
            ), titlePlacement: .border))
            if !isCompact { Spacer().frame(height: 1) }
            HStack(spacing: 1) {
                Button("Next sample", action: nextSample)
                Button("History") { history = history.next }
                    .accessibilityLabel("Cycle history")
                Text(isCompact ? history.rawValue : "History: \(history.rawValue) · step \(sampleIndex)")
                    .foregroundStyle(theme.colors.mutedText)
            }
            Spacer(minLength: 0)
            if !isCompact {
                Text("Tab moves focus · Return activates · 100% is utilization")
                    .foregroundStyle(theme.colors.mutedText)
                StatusBar { hints }
            } else { hints }
        }
        .padding(isCompact ? 0 : 1)
        .frame(maxWidth: 100, maxHeight: .infinity, alignment: .topLeading)
        .frame(width: terminalSize.width, height: terminalSize.height, alignment: .top)
        .onKeyPress { press in
            if press.modifiers == .ctrl {
                switch press.key {
                case .character("t"): themeChoice = themeChoice.next
                case .character("q"): _ = requestTermination()
                default: return .ignored
                }
            } else if press.modifiers.isEmpty {
                switch press.key {
                case .character("n"): nextSample()
                case .character("g"): history = history.next
                case .character("v"): toggleGauge()
                default: return .ignored
                }
            } else { return .ignored }
            return .handled
        }
        .style(theme)
    }
}
