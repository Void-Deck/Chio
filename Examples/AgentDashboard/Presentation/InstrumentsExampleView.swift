import Chio
import SwiftTUI

/// The application owns observation selection, allocation policy and playback.
@MainActor
struct InstrumentsExampleView {
    @Environment(\.terminalSize) private var terminalSize
    @Environment(\.requestTermination) private var requestTermination
    @State private var themeChoice: ExampleTheme
    @State private var selectedIndex = 0
    @State private var step = 1
    @State private var isPlaying = false
    @State private var isReadingMissing = false
    @State private var hasTarget = true
    @State private var hasHistory = true
    private let fixture = InstrumentFixture.example

    init(theme: ExampleTheme = .default) {
        _themeChoice = State(wrappedValue: theme)
    }

    private var theme: ChioStyle { themeChoice.theme }
    private var isExpanded: Bool { terminalSize.width >= 70 && terminalSize.height >= 30 }
    private var reading: String {
        if isReadingMissing { return "Unavailable" }
        return "\(fixture.temperatures[selectedIndex]) °C"
    }
    private var position: Double? {
        if isReadingMissing { return nil }
        return fixture.temperatures[selectedIndex] / 40
    }
    private var gaugeHeight: Int {
        (hasTarget ? 2 : 1) + (isExpanded ? 3 : 0)
    }

    private func nextSample() {
        selectedIndex = (selectedIndex + step) % fixture.temperatures.count
    }

    private var hints: some View {
        KeyHints {
            KeyHint("m", "missing")
            KeyHint("b", "band")
            KeyHint("g", "history")
            KeyHint("^T", "theme")
            KeyHint("^Q", "quit")
        }
    }

    private var temperature: some View {
        LabeledContent("Temperature", value: reading)
            .labeledContentStyle(.instrument)
    }

    private var reservoir: some View {
        LabeledContent("Reservoir", value: "58%")
            .labeledContentStyle(.instrument)
    }

    private var readings: some View {
        HStack(alignment: .top, spacing: 2) {
            temperature.frame(maxWidth: .infinity, alignment: .leading)
            reservoir.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var expandedMeasurements: some View {
        HStack(alignment: .top, spacing: 2) {
            VStack(alignment: .leading, spacing: 1) {
                temperature
                gauge
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                reservoir
                Label("Falling by 2%") { Text("↓").accessibilityHidden(true) }
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .frame(width: 24, alignment: .leading)
        }
    }

    private var gauge: some View {
        VStack(alignment: .leading, spacing: 0) {
            MeasurementGauge(position: position,
                             referenceMarks: isExpanded ? fixture.references : fixture.noReferences,
                             targetBand: hasTarget ? fixture.target : nil)
                .frame(height: gaugeHeight)
                .accessibilityLabel("Temperature: \(reading). Scale: zero to forty degrees Celsius."
                    + (hasTarget ? " Desired range: eighteen to twenty-four degrees." : " No desired range.")
                    + (isExpanded ? " Reference 1: Mean 20.8 degrees. Reference 2: Maximum 24.8 degrees." : ""))
            Text(hasTarget ? "Scale 0–40 °C · target 18–24 °C" : "Scale 0–40 °C · no target")
                .foregroundStyle(theme.colors.secondaryText)
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(hasHistory ? "Response time · milliseconds" : "Response time · empty")
                .foregroundStyle(theme.colors.heading)
            HistoryChart(hasHistory ? fixture.history : fixture.emptyHistory,
                         window: fixture.window, scale: .fixed(0...500))
                .frame(height: isExpanded ? 4 : 2)
            HStack {
                Text("0s")
                Spacer(minLength: 1)
                Text("90s · 0–500 ms")
            }
            .foregroundStyle(theme.colors.mutedText)
        }
    }
}

extension InstrumentsExampleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 1) {
                Text("chio").bold().foregroundStyle(theme.colors.accent)
                Text("/ instruments · local").foregroundStyle(theme.colors.secondaryText)
            }
            if isExpanded {
                Text("Pure styles, supplied observations, native controls.")
                    .foregroundStyle(theme.colors.mutedText)
                GroupBox("Measurements") { expandedMeasurements }
                GroupBox("Time-aware history") { history }
            } else {
                readings
                gauge
                history
            }
            HStack(spacing: 1) {
                Button(isPlaying ? "Pause" : "Play") { isPlaying.toggle() }
                Button("Next", action: nextSample)
                Text("Sample \(selectedIndex + 1)/\(fixture.temperatures.count)")
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Slider("Sample", value: $selectedIndex, in: 0...(fixture.temperatures.count - 1))
            Stepper("Step", value: $step, in: 1...3)
            Spacer(minLength: 0)
            hints
        }
        .padding(isExpanded ? 1 : 0)
        .frame(maxWidth: 100, maxHeight: .infinity, alignment: .topLeading)
        .frame(width: terminalSize.width, height: terminalSize.height, alignment: .top)
        .task(id: isPlaying) {
            // Example-owned playback; neither the styles nor the chart advances time.
            while isPlaying && !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                guard !Task.isCancelled else { return }
                nextSample()
            }
        }
        .onKeyPress { press in
            if press.modifiers == .ctrl {
                switch press.key {
                case .character("t"): themeChoice = themeChoice.next
                case .character("q"): _ = requestTermination()
                default: return .ignored
                }
            } else if press.modifiers.isEmpty {
                switch press.key {
                case .character("m"): isReadingMissing.toggle()
                case .character("b"): hasTarget.toggle()
                case .character("g"): hasHistory.toggle()
                case .character("n"): nextSample()
                default: return .ignored
                }
            } else { return .ignored }
            return .handled
        }
        .groupBoxStyle(ChioGroupBoxStyle(theme: theme, titlePlacement: .border))
        .style(theme)
    }
}
