import Chio
import Foundation
import SwiftTUIRuntime
import Testing

/// Spec tests for the clarified points in `Docs/Decisions/Waveform.md`: in-window
/// interpolation neighbours, the empty-window bipolar scale, half-away rounding,
/// shared trace/axis cells, end-anchored events, unavailable precedence and gaps.
@MainActor
struct WaveformClarificationSpecTests {
    private static let theme = ChioStyle.default.replacing(colors: ChioStyle.default.colors.replacing(
        accent: Color(hexRGB: 0x112233), mutedText: Color(hexRGB: 0x445566),
        warning: Color(hexRGB: 0x778899), error: Color(hexRGB: 0xAABBCC)))

    private func samples(_ values: [Double?], rate: Double = 1) throws -> WaveformSamples {
        try WaveformSamples(start: .zero, rate: rate, values: values)
    }

    private func render(_ samples: WaveformSamples, start: Duration = .zero, end: Duration,
                        scale: WaveformScale, mode: WaveformMode, events: [WaveformEvent] = [],
                        width: Int, height: Int) throws -> RenderSnapshot {
        let window = try HistoryInterval(start: start, end: end)
        return DefaultRenderer().render(
            Waveform(samples, window: window, scale: scale, mode: mode, events: events)
                .frame(width: width, height: height).style(Self.theme),
            proposal: ProposedSize(width: width, height: height))
    }

    private func pixels(_ surface: RasterSurface, color: Color? = nil) -> Set<CellPoint> {
        let dots = [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (0, 3), (1, 3)]
        var points: Set<CellPoint> = []
        for (y, row) in surface.cells.enumerated() {
            for (x, cell) in row.enumerated() {
                guard let scalar = cell.character.unicodeScalars.first,
                      (0x2800...0x28FF).contains(scalar.value) else { continue }
                if let color, cell.style?.foregroundColor != color { continue }
                let mask = scalar.value - 0x2800
                for (bit, dot) in dots.enumerated() where mask & (1 << bit) != 0 {
                    points.insert(CellPoint(x: x * 2 + dot.0, y: y * 4 + dot.1))
                }
            }
        }
        return points
    }

    /// Characters other than spaces and the empty braille pattern.
    private func visibleCharacters(_ surface: RasterSurface) -> [Character] {
        surface.cells.flatMap { $0 }.map(\.character).filter { $0 != " " && $0 != "\u{2800}" }
    }

    private func line(_ surface: RasterSurface, _ row: Int) -> String {
        var text = surface.lines[row]
        while text.last == " " { text.removeLast() }
        return text
    }

    private func labels(_ frame: RenderSnapshot) -> [String] {
        frame.semanticSnapshot.accessibilityNodes.compactMap(\.label)
    }

    private func column(_ x: Int, _ rows: ClosedRange<Int>) -> Set<CellPoint> {
        Set(rows.map { CellPoint(x: x, y: $0) })
    }

    private func row(_ y: Int, _ columns: Range<Int>) -> Set<CellPoint> {
        Set(columns.map { CellPoint(x: $0, y: y) })
    }

    @Test("An empty edge column whose interpolation neighbour lies outside the window is a gap")
    func interpolationNeighboursInsideWindow() throws {
        // Samples -4 at 0 s and -8 at 1 s; fixed(-11, 0) over 12 rows maps v to row -v.
        let values = try samples([-4, -8])
        // Window 0.5...1: column 0 covers [0.5, 0.75) with its left neighbour at 0 s, outside.
        let leading = try render(values, start: .milliseconds(500), end: .seconds(1),
                                 scale: .fixed(lower: -11, upper: 0), mode: .bipolar, width: 1, height: 3)
        #expect(pixels(leading.rasterSurface) == column(1, 8...8).union(row(0, 0..<2)))
        // Window 0...0.5: column 1 covers [0.25, 0.5] with its right neighbour at 1 s, outside.
        let trailing = try render(values, end: .milliseconds(500),
                                  scale: .fixed(lower: -11, upper: 0), mode: .bipolar, width: 1, height: 3)
        #expect(pixels(trailing.rasterSurface) == column(0, 4...4).union(row(0, 0..<2)))
        // A window between the two samples holds no sample, so it draws only the axis.
        let between = try render(values, start: .milliseconds(250), end: .milliseconds(750),
                                 scale: .fixed(lower: -11, upper: 0), mode: .bipolar, width: 1, height: 3)
        #expect(pixels(between.rasterSurface) == row(0, 0..<2))
    }

    @Test("With no known sample, bipolar uses -1...1 for the axis and magnitude draws nothing")
    func noKnownSampleScale() throws {
        let gaps = try samples([nil, nil, nil])
        for scale in [try WaveformScale.automatic(padding: 0), try .automatic(padding: 3)] {
            // Zero maps to round(1 / 2 · 7) = round(3.5) = 4 over 8 rows.
            let bipolar = try render(gaps, end: .seconds(2), scale: scale, mode: .bipolar, width: 3, height: 2)
            #expect(pixels(bipolar.rasterSurface) == row(4, 0..<6))
            #expect(pixels(bipolar.rasterSurface, color: Self.theme.colors.mutedText) == row(4, 0..<6))
            // Zero maps to round(1 / 2 · 11) = round(5.5) = 6 over 12 rows.
            let taller = try render(gaps, end: .seconds(2), scale: scale, mode: .bipolar, width: 3, height: 3)
            #expect(pixels(taller.rasterSurface) == row(6, 0..<6))
            let magnitude = try render(gaps, end: .seconds(2), scale: scale, mode: .magnitude, width: 3, height: 2)
            #expect(pixels(magnitude.rasterSurface).isEmpty)
            #expect(visibleCharacters(magnitude.rasterSurface).isEmpty)
        }
        // Known samples outside the window do not count.
        let outside = try render(samples([5, nil, nil, nil, 5]), start: .seconds(1), end: .seconds(3),
                                 scale: .automatic(padding: 0), mode: .bipolar, width: 3, height: 2)
        #expect(pixels(outside.rasterSurface) == row(4, 0..<6))
    }

    @Test("Rows round halves away from zero")
    func halfAwayRounding() throws {
        // fixed(0, 7) over 8 rows: 4.5 maps to row 2.5 -> 3 and 2.5 maps to row 4.5 -> 5.
        // Half-to-even would give rows 2 and 4; truncation would also give 2 and 4.
        let frame = try render(samples([4.5, 2.5]), end: .seconds(2), scale: .fixed(lower: 0, upper: 7),
                               mode: .magnitude, width: 1, height: 2)
        #expect(pixels(frame.rasterSurface) == column(0, 3...7).union(column(1, 5...7)))
    }

    @Test("A cell holding trace and axis dots keeps both and takes the accent")
    func sharedCell() throws {
        // fixed(-3, 4) over 8 rows maps v to row 4 - v; zero is row 4.
        let surface = try render(samples([3, nil, nil, nil, nil, -3]), end: .seconds(6),
                                 scale: .fixed(lower: -3, upper: 4), mode: .bipolar, width: 3, height: 2).rasterSurface
        let trace: Set<CellPoint> = [CellPoint(x: 0, y: 1), CellPoint(x: 5, y: 7)]
        #expect(pixels(surface) == row(4, 0..<6).union(trace))
        // Cell (2, 1) holds axis dots x 4...5 and trace dot (5, 7).
        #expect(pixels(surface, color: Self.theme.colors.accent) == row(4, 4..<6).union(trace))
        #expect(pixels(surface, color: Self.theme.colors.mutedText) == row(4, 0..<4))
        #expect(surface.cells[1][2].style?.foregroundColor == Self.theme.colors.accent)
    }

    @Test("An event starting at the window end anchors at the last cell and is summarised")
    func eventAtWindowEnd() throws {
        let values = try samples([1, 2])
        let marker = try render(values, end: .seconds(10), scale: .fixed(lower: 0, upper: 2), mode: .bipolar,
                                events: [WaveformEvent(start: .seconds(10), duration: .seconds(1), label: "OA",
                                                       tone: .error)],
                                width: 10, height: 3)
        // "OA" from cell 9 would end past the row, so it draws a marker there.
        #expect(line(marker.rasterSurface, 0) == "         ▾")
        #expect(marker.rasterSurface.cells[0][9].style?.foregroundColor == Self.theme.colors.error)
        #expect(labels(marker).contains {
            $0.hasPrefix("Waveform: ") && $0.hasSuffix(" Events: 1 (OA).")
        })
        let fits = try render(values, end: .seconds(10), scale: .fixed(lower: 0, upper: 2), mode: .bipolar,
                              events: [WaveformEvent(start: .seconds(10), duration: .seconds(1), label: "X",
                                                     tone: .warning)],
                              width: 10, height: 3)
        #expect(line(fits.rasterSurface, 0) == "         X")
        #expect(labels(fits).contains { $0.hasSuffix(" Events: 1 (X).") })
    }

    @Test("When several unavailable conditions hold, allocation precedes events, which precede zero")
    func unavailablePrecedence() throws {
        let values = try samples([1, 2])
        let excess = Array(repeating: try WaveformEvent(start: .zero, duration: .seconds(1), label: "OA",
                                                        tone: .muted), count: Waveform.maximumEvents + 1)
        let outsideZero = try WaveformScale.fixed(lower: 1, upper: 2)
        let all = try render(values, end: .seconds(1), scale: outsideZero, mode: .bipolar, events: excess,
                             width: 513, height: 4)
        #expect(labels(all).contains("Waveform unavailable: allocation limit exceeded."))
        #expect(!labels(all).contains("Waveform unavailable: event limit exceeded."))
        let allocationAndZero = try render(values, end: .seconds(1), scale: outsideZero, mode: .bipolar,
                                           width: 60, height: 65)
        #expect(labels(allocationAndZero).contains("Waveform unavailable: allocation limit exceeded."))
        let eventsAndZero = try render(values, end: .seconds(1), scale: outsideZero, mode: .bipolar,
                                       events: excess, width: 60, height: 4)
        #expect(labels(eventsAndZero).contains("Waveform unavailable: event limit exceeded."))
        #expect(!labels(eventsAndZero).contains("Waveform unavailable: zero is outside the fixed scale."))
        for frame in [all, allocationAndZero, eventsAndZero] {
            let written = frame.rasterSurface.lines.map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            #expect(written.count == 1)
            #expect(pixels(frame.rasterSurface).isEmpty)
        }
    }

    @Test("A fixed bound equal to zero includes zero for bipolar mode")
    func zeroBoundIncluded() throws {
        let values = try samples([1, 2])
        for (lower, upper) in [(0.0, 2.0), (-2.0, 0.0)] {
            let frame = try render(values, end: .seconds(1), scale: .fixed(lower: lower, upper: upper),
                                   mode: .bipolar, width: 10, height: 2)
            #expect(!labels(frame).contains { $0.hasPrefix("Waveform unavailable") })
            #expect(!pixels(frame.rasterSurface).isEmpty)
        }
    }

    @Test("Gaps draw nothing in either mode apart from the bipolar axis")
    func gapsDrawNothing() throws {
        // Columns 1...4 cover only nil samples.
        let values = try samples([5, nil, nil, nil, nil, 5])
        let magnitude = try render(values, end: .seconds(6), scale: .fixed(lower: 0, upper: 7), mode: .magnitude,
                                   width: 3, height: 2).rasterSurface
        // fixed(0, 7) over 8 rows maps 5 to row 2.
        #expect(pixels(magnitude) == column(0, 2...7).union(column(5, 2...7)))
        #expect(magnitude.cells.allSatisfy { $0[1].character == " " || $0[1].character == "\u{2800}" })
        // fixed(-3, 4): 5 clamps to row 0, zero is row 4.
        let bipolar = try render(values, end: .seconds(6), scale: .fixed(lower: -3, upper: 4), mode: .bipolar,
                                 width: 3, height: 2).rasterSurface
        #expect(pixels(bipolar) == column(0, 0...0).union(column(5, 0...0)).union(row(4, 0..<6)))
        #expect(pixels(bipolar, color: Self.theme.colors.mutedText) == row(4, 0..<6))
        #expect(visibleCharacters(bipolar).allSatisfy { $0.unicodeScalars.first.map { (0x2800...0x28FF).contains($0.value) } ?? false })
    }
}
