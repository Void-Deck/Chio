import Chio
import SwiftTUIRuntime
import Testing

/// Spec tests for event visibility and anchoring at large window offsets, from
/// `Docs/Decisions/Waveform.md` (Layout and drawing; Accessibility).
@MainActor
struct WaveformRangeSpecTests {
    private static let theme = ChioStyle.default.replacing(colors: ChioStyle.default.colors.replacing(
        accent: Color(hexRGB: 0x112233), mutedText: Color(hexRGB: 0x445566),
        warning: Color(hexRGB: 0x778899), error: Color(hexRGB: 0xAABBCC)))

    private static let windowStart = Duration.seconds(10_000_000_000)
    private static let windowEnd = Duration.seconds(10_000_000_000) + .nanoseconds(1)

    private func render(events: [WaveformEvent], width: Int = 10, height: Int = 3) throws -> RenderSnapshot {
        let samples = try WaveformSamples(start: .zero, rate: 1, values: [1])
        let window = try HistoryInterval(start: Self.windowStart, end: Self.windowEnd)
        let scale = try WaveformScale.fixed(lower: 0, upper: 2)
        return DefaultRenderer().render(
            Waveform(samples, window: window, scale: scale, mode: .magnitude, events: events)
                .frame(width: width, height: height).style(Self.theme),
            proposal: ProposedSize(width: width, height: height))
    }

    private func line(_ surface: RasterSurface, _ row: Int) -> String {
        var text = surface.lines[row]
        while text.last == " " { text.removeLast() }
        return text
    }

    private func labels(_ frame: RenderSnapshot) -> [String] {
        frame.semanticSnapshot.accessibilityNodes.compactMap(\.label)
    }

    @Test("A long event that started far before a nanosecond window is visible at cell zero")
    func longEventBeforeNarrowWindow() throws {
        let event = try WaveformEvent(start: .zero, duration: .seconds(20_000_000_000), label: "X", tone: .error)
        let frame = try render(events: [event])
        let surface = frame.rasterSurface
        #expect(line(surface, 0) == "X")
        #expect(surface.cells[0][0].style?.foregroundColor == Self.theme.colors.error)
        #expect(labels(frame).contains { $0.hasPrefix("Waveform: ") && $0.hasSuffix(" Events: 1 (X).") })
        #expect(!labels(frame).contains { $0.hasPrefix("Waveform unavailable") })
    }

    @Test("An event starting far after a nanosecond window is not visible")
    func eventFarAfterNarrowWindow() throws {
        let event = try WaveformEvent(start: .seconds(30_000_000_000), duration: .seconds(1), label: "X", tone: .error)
        let frame = try render(events: [event])
        // The event row remains because the event list is not empty, but it is blank.
        #expect(line(frame.rasterSurface, 0).isEmpty)
        #expect(labels(frame).contains { $0.hasPrefix("Waveform: ") && $0.hasSuffix(" Events: 0.") })
        #expect(!labels(frame).contains { $0.hasPrefix("Waveform unavailable") })
    }
}
