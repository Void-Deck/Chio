import Chio
import Foundation
import SwiftTUIRuntime
import Testing

/// Spec tests for `Docs/Decisions/Waveform.md`, written from its public interface,
/// validation, layout and drawing, unavailable states and accessibility sections.
///
/// Dot coordinates are surface braille dots: x = cell column · 2 + dot column,
/// y = cell row · 4 + dot row. Fixtures choose integer row positions away from
/// rounding ties so expectations follow the row formula exactly.
@MainActor
struct WaveformSpecTests {
    private static let theme = ChioStyle.default.replacing(colors: ChioStyle.default.colors.replacing(
        accent: Color(hexRGB: 0x112233), mutedText: Color(hexRGB: 0x445566),
        warning: Color(hexRGB: 0x778899), error: Color(hexRGB: 0xAABBCC)))

    private func samples(_ values: [Double?], rate: Double = 1, start: Duration = .zero) throws -> WaveformSamples {
        try WaveformSamples(start: start, rate: rate, values: values)
    }

    private func event(_ start: Duration, _ label: String, _ tone: WaveformEvent.Tone = .muted,
                       duration: Duration = .seconds(1)) throws -> WaveformEvent {
        try WaveformEvent(start: start, duration: duration, label: label, tone: tone)
    }

    private func render(_ samples: WaveformSamples, start: Duration = .zero, end: Duration,
                        scale: WaveformScale, mode: WaveformMode, events: [WaveformEvent] = [],
                        width: Int, height: Int, theme: ChioStyle = WaveformSpecTests.theme) throws -> RenderSnapshot {
        let window = try HistoryInterval(start: start, end: end)
        return DefaultRenderer().render(
            Waveform(samples, window: window, scale: scale, mode: mode, events: events)
                .frame(width: width, height: height).style(theme),
            proposal: ProposedSize(width: width, height: height))
    }

    /// Braille dots in the surface, optionally only from cells painted in `color`.
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

    private func color(_ surface: RasterSurface, x: Int, y: Int) -> Color? {
        surface.cells[y][x].style?.foregroundColor
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

    // MARK: - Reduction

    @Test("Each dot column spans the minimum and maximum of its known samples; all-nil columns are gaps")
    func columnReduction() throws {
        // fixed(-11, 0) over 12 dot rows maps v to row -v; the zero axis is row 0.
        let values: [Double?] = [-5, -9, -6, -7, -4, -4, -4, -4, -11, -6, -4, -8, nil, nil, nil, nil]
        let frame = try render(samples(values, rate: 4), end: .seconds(4),
                               scale: .fixed(lower: -11, upper: 0), mode: .bipolar, width: 2, height: 3)
        let trace = column(0, 5...9).union(column(1, 4...4)).union(column(2, 4...11))
        #expect(pixels(frame.rasterSurface) == trace.union(row(0, 0..<4)))
        #expect(pixels(frame.rasterSurface, color: Self.theme.colors.accent) == trace)
    }

    @Test("Wide columns keep a single-sample spike and trough")
    func denseReduction() throws {
        var values = [Double?](repeating: -6, count: 1_000)
        values[300] = -11
        values[301] = -4
        let frame = try render(samples(values, rate: 100), end: .seconds(10),
                               scale: .fixed(lower: -11, upper: 0), mode: .bipolar, width: 1, height: 3)
        #expect(pixels(frame.rasterSurface) == column(0, 4...11).union(column(1, 6...6)).union(row(0, 0..<2)))
    }

    @Test("The last dot column includes the window end")
    func lastColumnIncludesEnd() throws {
        let frame = try render(samples([-4, -5, -6, -7, -8]), end: .seconds(4),
                               scale: .fixed(lower: -11, upper: 0), mode: .bipolar, width: 2, height: 3)
        let trace = column(0, 4...4).union(column(1, 5...5)).union(column(2, 6...6)).union(column(3, 7...8))
        #expect(pixels(frame.rasterSurface) == trace.union(row(0, 0..<4)))
    }

    @Test("Samples outside the window do not contribute to any column")
    func windowOnly() throws {
        let frame = try render(samples([-11, -5, -6, -7, -11]), start: .seconds(1), end: .seconds(3),
                               scale: .fixed(lower: -11, upper: 0), mode: .bipolar, width: 1, height: 3)
        #expect(pixels(frame.rasterSurface) == column(0, 5...5).union(column(1, 6...7)).union(row(0, 0..<2)))
    }

    @Test("Empty columns between adjacent known samples span the interpolated values at their start and end")
    func interpolation() throws {
        // Samples -4 at 0 s and -8 at 1 s; four columns of 0.25 s each.
        let frame = try render(samples([-4, -8]), end: .seconds(1),
                               scale: .fixed(lower: -11, upper: 0), mode: .bipolar, width: 2, height: 3)
        let trace = column(0, 4...4).union(column(1, 5...6)).union(column(2, 6...7)).union(column(3, 8...8))
        #expect(pixels(frame.rasterSurface) == trace.union(row(0, 0..<4)))
    }

    @Test("Interpolation never joins across a nil sample")
    func noJoinAcrossGap() throws {
        let frame = try render(samples([-4, nil, -8], rate: 2), end: .seconds(1),
                               scale: .fixed(lower: -11, upper: 0), mode: .bipolar, width: 2, height: 3)
        let trace = column(0, 4...4).union(column(3, 8...8))
        #expect(pixels(frame.rasterSurface) == trace.union(row(0, 0..<4)))
        #expect(pixels(frame.rasterSurface, color: Self.theme.colors.accent) == trace)
    }

    // MARK: - Scale

    @Test("Automatic bounds floor and ceil the padded window extremes")
    func automaticMagnitude() throws {
        // min 2.3, max 5.6, padding 0.5: bounds 1...7 over 8 rows.
        let frame = try render(samples([2.3, 5.6]), end: .seconds(2),
                               scale: .automatic(padding: 0.5), mode: .magnitude, width: 1, height: 2)
        #expect(pixels(frame.rasterSurface) == column(0, 5...7).union(column(1, 2...7)))
    }

    @Test("Automatic bounds use only known samples inside the window")
    func automaticWindowOnly() throws {
        let frame = try render(samples([100, 2.3, nil, 5.6, -100], rate: 2), start: .milliseconds(500),
                               end: .milliseconds(1_500), scale: .automatic(padding: 0.5), mode: .magnitude,
                               width: 1, height: 2)
        #expect(pixels(frame.rasterSurface) == column(0, 5...7).union(column(1, 2...7)))
    }

    @Test("Bipolar automatic bounds extend to include zero from either side")
    func automaticBipolar() throws {
        // Positive: bounds 1...7 extend to 0...7 over 12 rows; zero is row 11.
        let positive = try render(samples([2.3, 5.6]), end: .seconds(2),
                                  scale: .automatic(padding: 0.5), mode: .bipolar, width: 1, height: 3)
        #expect(pixels(positive.rasterSurface)
                == Set([CellPoint(x: 0, y: 7), CellPoint(x: 1, y: 2)]).union(row(11, 0..<2)))
        // Negative: bounds -7...-1 extend to -7...0; zero is row 0.
        let negative = try render(samples([-5.6, -2.3]), end: .seconds(2),
                                  scale: .automatic(padding: 0.5), mode: .bipolar, width: 1, height: 3)
        #expect(pixels(negative.rasterSurface)
                == Set([CellPoint(x: 0, y: 9), CellPoint(x: 1, y: 4)]).union(row(0, 0..<2)))
    }

    @Test("A constant window is centred within one unit either side")
    func automaticConstant() throws {
        let constant = try samples([3, 3, 3])
        let automatic = try render(constant, end: .seconds(2), scale: .automatic(padding: 0), mode: .magnitude,
                                   width: 2, height: 2)
        let fixed = try render(constant, end: .seconds(2), scale: .fixed(lower: 2, upper: 4), mode: .magnitude,
                               width: 2, height: 2)
        #expect(!pixels(automatic.rasterSurface).isEmpty)
        #expect(pixels(automatic.rasterSurface) == pixels(fixed.rasterSurface))
        let zeros = try samples([0, 0, 0])
        let bipolar = try render(zeros, end: .seconds(2), scale: .automatic(padding: 0), mode: .bipolar,
                                 width: 2, height: 2)
        let unit = try render(zeros, end: .seconds(2), scale: .fixed(lower: -1, upper: 1), mode: .bipolar,
                              width: 2, height: 2)
        #expect(!pixels(bipolar.rasterSurface).isEmpty)
        #expect(pixels(bipolar.rasterSurface) == pixels(unit.rasterSurface))
    }

    @Test("A window with no known sample draws no trace; bipolar draws only the axis")
    func automaticWithoutKnownSamples() throws {
        let gaps = try samples([nil, nil, nil])
        let bipolar = try render(gaps, end: .seconds(2), scale: .automatic(padding: 1), mode: .bipolar,
                                 width: 3, height: 2).rasterSurface
        let axis = pixels(bipolar)
        #expect(pixels(bipolar, color: Self.theme.colors.mutedText) == axis)
        #expect(Set(axis.map(\.y)).count == 1)
        #expect(Set(axis.map(\.x)) == Set(0..<6))
        let magnitude = try render(gaps, end: .seconds(2), scale: .automatic(padding: 1), mode: .magnitude,
                                   width: 3, height: 2).rasterSurface
        #expect(pixels(magnitude, color: Self.theme.colors.accent).isEmpty)
    }

    @Test("Fixed-scale values outside the bounds draw on the edge rows")
    func fixedClamping() throws {
        // fixed(0, 7) over 8 rows maps v to row 7 - v.
        let magnitude = try render(samples([100, -100]), end: .seconds(2), scale: .fixed(lower: 0, upper: 7),
                                   mode: .magnitude, width: 1, height: 2)
        #expect(pixels(magnitude.rasterSurface) == column(0, 0...7).union(column(1, 7...7)))
        // fixed(-1, 10) over 12 rows maps v to row 10 - v; zero is row 10.
        let bipolar = try render(samples([50, 5, 4]), end: .seconds(2), scale: .fixed(lower: -1, upper: 10),
                                 mode: .bipolar, width: 1, height: 3)
        #expect(pixels(bipolar.rasterSurface)
                == Set([CellPoint(x: 0, y: 0), CellPoint(x: 1, y: 5), CellPoint(x: 1, y: 6)]).union(row(10, 0..<2)))
        let low = try render(samples([-50, 9]), end: .seconds(2), scale: .fixed(lower: -1, upper: 10),
                             mode: .bipolar, width: 1, height: 3)
        #expect(pixels(low.rasterSurface).contains(CellPoint(x: 0, y: 11)))
        #expect(pixels(low.rasterSurface).allSatisfy { (0..<12).contains($0.y) })
    }

    // MARK: - Modes and colors

    @Test("The bipolar zero axis is muted, crosses gaps, and loses shared cells to trace dots")
    func bipolarAxis() throws {
        // fixed(-3, 4) over 8 rows maps v to row 4 - v; zero is row 4.
        let surface = try render(samples([3, nil, nil, nil, nil, -3]), end: .seconds(6),
                                 scale: .fixed(lower: -3, upper: 4), mode: .bipolar, width: 3, height: 2).rasterSurface
        let dots = pixels(surface)
        let axis = row(4, 0..<6)
        #expect(dots.isSubset(of: axis.union([CellPoint(x: 0, y: 1), CellPoint(x: 5, y: 7)])))
        #expect(dots.contains(CellPoint(x: 0, y: 1)))
        #expect(dots.contains(CellPoint(x: 5, y: 7)))
        // The axis crosses the gap columns 1...4, in muted text where no trace shares the cell.
        #expect(pixels(surface, color: Self.theme.colors.mutedText) == row(4, 0..<4))
        #expect(color(surface, x: 0, y: 1) == Self.theme.colors.mutedText)
        #expect(color(surface, x: 1, y: 1) == Self.theme.colors.mutedText)
        // The trace uses the accent and wins the cell it shares with the axis.
        #expect(color(surface, x: 0, y: 0) == Self.theme.colors.accent)
        #expect(color(surface, x: 2, y: 1) == Self.theme.colors.accent)
        #expect(pixels(surface, color: Self.theme.colors.accent).contains(CellPoint(x: 5, y: 7)))
    }

    @Test("Magnitude fills each column from the bottom row to its maximum, in the accent, with no axis")
    func magnitudeFill() throws {
        // fixed(0, 7) over 8 rows maps v to row 7 - v.
        let values: [Double?] = [2, 5, 0, 0, 3, 7, nil, nil]
        let surface = try render(samples(values, rate: 2), end: .seconds(4), scale: .fixed(lower: 0, upper: 7),
                                 mode: .magnitude, width: 2, height: 2).rasterSurface
        let expected = column(0, 2...7).union(column(1, 7...7)).union(column(2, 0...7))
        #expect(pixels(surface) == expected)
        #expect(pixels(surface, color: Self.theme.colors.accent) == expected)
    }

    @Test("The trace follows the inherited style's accent")
    func inheritedAccent() throws {
        for theme in [ChioStyle.default, .light, .btop, Self.theme] {
            let surface = try render(samples([1, 2, 3]), end: .seconds(2), scale: .fixed(lower: 0, upper: 3),
                                     mode: .magnitude, width: 2, height: 2, theme: theme).rasterSurface
            let painted = pixels(surface)
            #expect(!painted.isEmpty)
            #expect(pixels(surface, color: theme.colors.accent) == painted)
        }
    }

    // MARK: - Events

    private func eventSurface(_ events: [WaveformEvent], start: Duration = .zero,
                              end: Duration = .seconds(10)) throws -> RasterSurface {
        try render(samples([nil]), start: start, end: end, scale: .fixed(lower: 0, upper: 1), mode: .magnitude,
                   events: events, width: 10, height: 3).rasterSurface
    }

    @Test("The event row takes the top row only when events are supplied")
    func eventRowPresence() throws {
        let flat = try samples(Array(repeating: 7, count: 11))
        let without = try render(flat, end: .seconds(10), scale: .fixed(lower: 0, upper: 7), mode: .magnitude,
                                 width: 10, height: 3).rasterSurface
        let plotAll = Set((0..<20).flatMap { x in (0..<12).map { CellPoint(x: x, y: $0) } })
        #expect(pixels(without) == plotAll)
        let with = try render(flat, end: .seconds(10), scale: .fixed(lower: 0, upper: 7), mode: .magnitude,
                              events: [event(.seconds(2), "OA")], width: 10, height: 3).rasterSurface
        let plotBelow = Set((0..<20).flatMap { x in (4..<12).map { CellPoint(x: x, y: $0) } })
        #expect(pixels(with) == plotBelow)
        #expect(line(with, 0) == "  OA")
        // A non-empty list keeps the event row even when no event is visible.
        let hidden = try render(flat, start: .seconds(5), end: .seconds(10), scale: .fixed(lower: 0, upper: 7),
                                mode: .magnitude, events: [event(.zero, "OA")], width: 10, height: 3).rasterSurface
        #expect(pixels(hidden) == plotBelow)
        #expect(line(hidden, 0).isEmpty)
    }

    @Test("Labels draw at their anchor cell when they fit; anchors floor the start fraction")
    func labelPlacement() throws {
        #expect(line(try eventSurface([event(.zero, "OA"), event(.seconds(5), "CA")]), 0) == "OA   CA")
        #expect(line(try eventSurface([event(.milliseconds(2_900), "OA")]), 0) == "  OA")
        // Processing follows start time, then input order.
        #expect(line(try eventSurface([event(.seconds(5), "CA"), event(.zero, "OA")]), 0) == "OA   CA")
    }

    @Test("A label needs one blank cell before the next anchor")
    func labelNextAnchor() throws {
        #expect(line(try eventSurface([event(.zero, "ABC"), event(.seconds(4), "D")]), 0) == "ABC D")
        #expect(line(try eventSurface([event(.zero, "ABC"), event(.seconds(3), "D")]), 0) == "▾  D")
        #expect(line(try eventSurface([event(.zero, "HYPOPNEA"), event(.seconds(5), "OA")]), 0) == "▾    OA")
    }

    @Test("A label must start at least two cells after the previous occupied cell")
    func labelPreviousCell() throws {
        #expect(line(try eventSurface([event(.zero, "A"), event(.seconds(2), "B")]), 0) == "A B")
        #expect(line(try eventSurface([event(.zero, "AB"), event(.seconds(2), "C")]), 0) == "▾ C")
        #expect(line(try eventSurface([event(.zero, "A"), event(.seconds(1), "B")]), 0) == "▾▾")
    }

    @Test("A label must end at or before the row's end")
    func labelRowEnd() throws {
        #expect(line(try eventSurface([event(.seconds(6), "ABCD")]), 0) == "      ABCD")
        #expect(line(try eventSurface([event(.seconds(6), "ABCDE")]), 0) == "      ▾")
    }

    @Test("Labels and markers use the tone's style color")
    func toneColors() throws {
        let colors = Self.theme.colors
        let expected: [(WaveformEvent.Tone, Color)] = [(.muted, colors.mutedText), (.warning, colors.warning),
                                                       (.error, colors.error)]
        for (tone, toneColor) in expected {
            let labelled = try eventSurface([event(.seconds(1), "OA", tone)])
            #expect(color(labelled, x: 1, y: 0) == toneColor)
            #expect(color(labelled, x: 2, y: 0) == toneColor)
            let marked = try eventSurface([event(.seconds(6), "TOOLONG", tone)])
            #expect(line(marked, 0) == "      ▾")
            #expect(color(marked, x: 6, y: 0) == toneColor)
        }
    }

    @Test("Markers in one cell merge to the most severe tone")
    func markerSeverity() throws {
        let colors = Self.theme.colors
        let warning = try eventSurface([event(.seconds(3), "X", .warning), event(.seconds(3), "Y", .muted)])
        #expect(line(warning, 0) == "   ▾")
        #expect(color(warning, x: 3, y: 0) == colors.warning)
        let error = try eventSurface([event(.seconds(3), "X", .muted), event(.seconds(3), "Y", .error),
                                      event(.seconds(3), "Z", .warning)])
        #expect(line(error, 0) == "   ▾")
        #expect(color(error, x: 3, y: 0) == colors.error)
        let muted = try eventSurface([event(.seconds(3), "X", .muted), event(.seconds(3), "Y", .muted)])
        #expect(color(muted, x: 3, y: 0) == colors.mutedText)
    }

    @Test("An event that started before the window is visible at cell zero; one that ended at its start is not")
    func eventBeforeWindow() throws {
        let window = (start: Duration.seconds(2), end: Duration.seconds(12))
        let overlapping = try eventSurface([event(.zero, "OA", duration: .seconds(5))],
                                           start: window.start, end: window.end)
        #expect(line(overlapping, 0) == "OA")
        let barely = try eventSurface([event(.zero, "OA", duration: .seconds(2) + Duration(secondsComponent: 0, attosecondsComponent: 1))],
                                      start: window.start, end: window.end)
        #expect(line(barely, 0) == "OA")
        let ended = try eventSurface([event(.zero, "OA", duration: .seconds(2))], start: window.start, end: window.end)
        #expect(line(ended, 0).isEmpty)
        let after = try eventSurface([event(.seconds(13), "OA")], start: window.start, end: window.end)
        #expect(line(after, 0).isEmpty)
    }

    // MARK: - Unavailable states

    private func expectUnavailable(_ frame: RenderSnapshot, _ message: String) {
        let surface = frame.rasterSurface
        // Placement within the allocation is unspecified, so surrounding blanks are ignored.
        let written = surface.lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        #expect(written == [message])
        #expect(pixels(surface).isEmpty)
        #expect(labels(frame).contains(message))
    }

    private func expectAvailable(_ frame: RenderSnapshot) {
        #expect(!frame.rasterSurface.lines.contains { $0.contains("unavailable") })
        #expect(!labels(frame).contains { $0.hasPrefix("Waveform unavailable") })
    }

    @Test("Sizes above 512 columns or 64 rows replace the view with the allocation message")
    func allocationLimit() throws {
        let values = try samples([1, 2])
        let message = "Waveform unavailable: allocation limit exceeded."
        for (width, height) in [(513, 64), (512, 65)] {
            expectUnavailable(try render(values, end: .seconds(1), scale: .fixed(lower: 0, upper: 2),
                                         mode: .magnitude, width: width, height: height), message)
        }
        let admitted = try render(values, end: .seconds(1), scale: .fixed(lower: 0, upper: 2), mode: .magnitude,
                                  width: 512, height: 64)
        expectAvailable(admitted)
        #expect(!pixels(admitted.rasterSurface).isEmpty)
    }

    @Test("More than maximumEvents events replace the view with the event message")
    func eventLimit() throws {
        #expect(Waveform.maximumEvents == 4_096)
        let values = try samples([1, 2])
        let one = try event(.zero, "OA")
        expectUnavailable(try render(values, end: .seconds(1), scale: .fixed(lower: 0, upper: 2), mode: .magnitude,
                                     events: Array(repeating: one, count: 4_097), width: 60, height: 4),
                          "Waveform unavailable: event limit exceeded.")
        expectAvailable(try render(values, end: .seconds(1), scale: .fixed(lower: 0, upper: 2), mode: .magnitude,
                                   events: Array(repeating: one, count: 4_096), width: 60, height: 4))
    }

    @Test("Bipolar mode with a fixed scale that excludes zero shows the zero message")
    func zeroOutsideFixedScale() throws {
        let values = try samples([1, 2])
        let message = "Waveform unavailable: zero is outside the fixed scale."
        for (lower, upper) in [(1.0, 2.0), (-2.0, -1.0)] {
            expectUnavailable(try render(values, end: .seconds(1), scale: .fixed(lower: lower, upper: upper),
                                         mode: .bipolar, width: 60, height: 4), message)
            expectAvailable(try render(values, end: .seconds(1), scale: .fixed(lower: lower, upper: upper),
                                       mode: .magnitude, width: 60, height: 4))
        }
        for (lower, upper) in [(0.0, 2.0), (-2.0, 0.0), (-1.0, 1.0)] {
            expectAvailable(try render(values, end: .seconds(1), scale: .fixed(lower: lower, upper: upper),
                                       mode: .bipolar, width: 60, height: 4))
        }
    }

    // MARK: - Accessibility

    private func summary(_ values: [Double?], start: Duration = .zero, end: Duration,
                         events: [WaveformEvent] = []) throws -> [String] {
        labels(try render(samples(values), start: start, end: end, scale: .automatic(padding: 0), mode: .bipolar,
                          events: events, width: 10, height: 3))
    }

    @Test("The label counts known samples and gap runs in the window, then the visible range")
    func accessibilityCounts() throws {
        let values: [Double?] = [1.5, nil, nil, -2, nil, 3]
        #expect(try summary(values, end: .seconds(5)).contains(
            "Waveform: 3 known samples, 2 gaps in window. Minimum: -2.0. Maximum: 3.0. Events: 0."))
        // A run counts when at least one of its offsets is in the window.
        #expect(try summary(values, start: .seconds(2), end: .seconds(4)).contains(
            "Waveform: 1 known samples, 2 gaps in window. Minimum: -2.0. Maximum: -2.0. Events: 0."))
        #expect(try summary(values, start: .seconds(2), end: .milliseconds(2_500)).contains(
            "Waveform: 0 known samples, 1 gaps in window. Events: 0."))
        #expect(try summary(values, start: .seconds(10), end: .seconds(20)).contains(
            "Waveform: 0 known samples, 0 gaps in window. Events: 0."))
    }

    @Test("The label lists visible event labels in drawing order")
    func accessibilityEvents() throws {
        let events = try [event(.seconds(5), "CA", .error), event(.zero, "OA", .warning),
                          event(.seconds(30), "Late")]
        #expect(try summary([1, 2], end: .seconds(10), events: events).contains(
            "Waveform: 2 known samples, 0 gaps in window. Minimum: 1.0. Maximum: 2.0. Events: 2 (OA, CA)."))
        // Labels that draw as markers still appear in the summary.
        let crowded = try [event(.seconds(3), "X"), event(.seconds(3), "Y")]
        #expect(try summary([1, 2], end: .seconds(10), events: crowded).contains(
            "Waveform: 2 known samples, 0 gaps in window. Minimum: 1.0. Maximum: 2.0. Events: 2 (X, Y)."))
    }
}
