@testable import Chio
import SwiftTUIRuntime
import Testing

/// Supplementary implementer tests; independent contract tests are authored separately.
@MainActor
struct WaveformRenderingTests {
    @Test func arithmeticReductionPreservesExtremaAndGaps() throws {
        let samples = try WaveformSamples(start: .zero, rate: 1, values: [1, 9, nil, nil, -3, 2])
        let window = try HistoryInterval(start: .zero, end: .seconds(5))
        let reduced = WaveformColumns(samples: samples, window: window, count: 3)
        #expect(reduced.columns == [WaveformColumns.Span(minimum: 1, maximum: 9), nil, WaveformColumns.Span(minimum: -3, maximum: 2)])
        #expect(reduced.knownCount == 4)
        #expect(reduced.gapCount == 1)
    }

    @Test func interpolationDoesNotCrossGapsOrWindowEdges() throws {
        let samples = try WaveformSamples(start: .zero, rate: 1, values: [0, 8, nil, 4])
        let window = try HistoryInterval(start: .zero, end: .seconds(3))
        let reduced = WaveformColumns(samples: samples, window: window, count: 12)
        #expect(reduced.columns[1] == WaveformColumns.Span(minimum: 2, maximum: 4))
        #expect(reduced.columns[5] == nil)
        let cropped = try HistoryInterval(start: .milliseconds(250), end: .milliseconds(750))
        #expect(WaveformColumns(samples: samples, window: cropped, count: 2).columns.allSatisfy { $0 == nil })
    }

    @Test func eventMarkersMergeSeverity() throws {
        let events = try WaveformEvent.Tone.allCases.map {
            try WaveformEvent(start: .seconds(1), duration: .seconds(1), label: "long", tone: $0)
        }
        let window = try HistoryInterval(start: .zero, end: .seconds(10))
        let row = WaveformEventRow(events: events, window: window, width: 3)
        #expect(row.cells[0].character == "▾")
        #expect(row.cells[0].tone == .error)
    }

    @Test func rendersFullSyntheticNight() throws {
        let values: [Double?] = (0..<720_000).map { index in index == 360_000 ? 40 : Double(index % 20) - 10 }
        let samples = try WaveformSamples(start: .zero, rate: 25, values: values)
        let window = try HistoryInterval(start: .zero, end: .seconds(28_800))
        let scale = try WaveformScale.fixed(lower: -40, upper: 40)
        let snapshot = DefaultRenderer().render(
            Waveform(samples, window: window, scale: scale, mode: .bipolar).frame(width: 100, height: 10),
            proposal: ProposedSize(width: 100, height: 10))
        #expect(snapshot.rasterSurface.lines.contains { $0.unicodeScalars.contains { (0x2801...0x28FF).contains($0.value) } })
        #expect(snapshot.semanticSnapshot.accessibilityNodes.contains {
            $0.label == "Waveform: 720000 known samples, 0 gaps in window. Minimum: -10.0. Maximum: 40.0. Events: 0."
        })
    }

    @Test func extremeRateAndBoundsRemainDrawable() throws {
        let samples = try WaveformSamples(start: .zero, rate: Double.greatestFiniteMagnitude, values: [-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude])
        let window = try HistoryInterval(start: .zero, end: .seconds(1))
        let columns = WaveformColumns(samples: samples, window: window, count: 4)
        #expect(columns.columns[0] == WaveformColumns.Span(minimum: -Double.greatestFiniteMagnitude, maximum: Double.greatestFiniteMagnitude))
        let scale = try WaveformScale.fixed(lower: -Double.greatestFiniteMagnitude, upper: Double.greatestFiniteMagnitude)
        let bounds = WaveformBounds(scale: scale, mode: .bipolar, columns: columns)
        #expect(bounds.row(0, height: 8) == 4)
        #expect(bounds.row(Double.greatestFiniteMagnitude, height: 8) == 0)
        let positive = try WaveformSamples(start: .zero, rate: 1, values: [Double.greatestFiniteMagnitude])
        let constant = WaveformColumns(samples: positive, window: window, count: 4)
        let padded = try WaveformScale.automatic(padding: Double.greatestFiniteMagnitude)
        #expect(WaveformBounds(scale: padded, mode: .magnitude, columns: constant).row(Double.greatestFiniteMagnitude, height: 8) == 4)
        let outside = try HistoryInterval(start: .seconds(1), end: .seconds(2))
        #expect(WaveformColumns(samples: samples, window: outside, count: 4).columns.allSatisfy { $0 == nil })
    }

    @Test func maximumSeriesUsesBoundedColumnStorage() throws {
        let samples = try WaveformSamples(start: .zero, rate: 100, values: Array(repeating: 3, count: WaveformSamples.maximumCount))
        let window = try HistoryInterval(start: .zero, end: .seconds(28_800))
        let reduced = WaveformColumns(samples: samples, window: window, count: 1_024)
        #expect(reduced.columns.count == 1_024)
        #expect(reduced.knownCount == WaveformSamples.maximumCount)
        #expect(reduced.columns[0] == WaveformColumns.Span(minimum: 3, maximum: 3))
    }
}
