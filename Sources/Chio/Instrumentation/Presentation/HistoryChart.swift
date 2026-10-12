import SwiftTUIViews

/// Passive, time-proportional history in an explicit application-owned window.
///
/// Connections are linear only within a supplied segment and between adjacent
/// known readings. Equal timestamps can connect vertically. Missing readings
/// and segment boundaries prohibit connections; neither implies outage duration.
/// Window and fixed-scale clipping intersect real lines, without extrapolation.
/// Automatic scale includes visible connections and centers constant geometry.
///
/// Dense runs retain first/last/minimum/maximum per braille drawing column in
/// source order. Subcolumn interruptions may not be visually distinguishable.
/// Canvas allocation is limited to 512 columns by 64 rows; native line work is
/// limited to 262,144 grid samples per drawing. Exceeding either bound replaces
/// the entire chart with an unavailable message. Sampling, retention, navigation,
/// captions, units and interpretation remain application responsibilities.
@MainActor
public struct HistoryChart {
    @Environment(\.chioStyle) private var theme
    private let series: HistorySeries
    private let window: HistoryInterval
    private let scale: Sparkline.Scale

    public init(_ series: HistorySeries, window: HistoryInterval, scale: Sparkline.Scale = .automatic) {
        switch scale {
        case .automatic: break
        case .fixed(let range):
            let hasFiniteLowerBound = range.lowerBound.isFinite
            let hasFiniteUpperBound = range.upperBound.isFinite
            let hasIncreasingBounds = range.lowerBound < range.upperBound
            precondition(hasFiniteLowerBound && hasFiniteUpperBound && hasIncreasingBounds,
                         "HistoryChart fixed bounds must be finite and strictly increasing.")
        }
        self.series = series
        self.window = window
        self.scale = scale
    }

    private var summary: String {
        let observations = series.segments.flatMap { $0 }.filter { window.range.contains($0.offset) }
        let readings = observations.compactMap(\.value)
        let counts = "History in window: \(readings.count) readings, \(observations.count - readings.count) missing observations."
        guard let minimum = readings.min(), let maximum = readings.max() else { return counts }
        return "\(counts) Minimum: \(minimum). Maximum: \(maximum)."
    }
}

extension HistoryChart: View {
    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let isWithinColumnLimit = size.width <= HistoryPlot.maximumColumns
            let isWithinRowLimit = size.height <= HistoryPlot.maximumRows
            if isWithinColumnLimit && isWithinRowLimit {
                let plot = HistoryPlot(series: series, window: window, scale: scale, size: size)
                switch plot.content {
                case .drawing(let strokes):
                    Canvas(HistoryDrawing(strokes: strokes), grid: .braille2x4)
                        .frame(width: size.width, height: size.height)
                        .accessibilityLabel(summary)
                case .unavailable:
                    Text("History unavailable: drawing limit exceeded.")
                        .accessibilityLabel("History unavailable: drawing limit exceeded.")
                }
            } else {
                Text("History unavailable: allocation limit exceeded.")
                    .accessibilityLabel("History unavailable: allocation limit exceeded.")
            }
        }
        .foregroundStyle(theme.colors.accent)
    }
}

/// Pure setup finishes admission before any native painting occurs.
private struct HistoryPlot {
    static let maximumColumns = 512
    static let maximumRows = 64
    static let maximumDrawingWork = 262_144

    enum Content {
        case drawing([HistoryDrawing.Stroke])
        case unavailable
    }

    let content: Content

    private struct Vertex {
        let x: Double
        let value: Double
    }

    private struct Observation {
        let offset: Duration
        let value: Double
    }

    private struct Reading {
        let index: Int
        let vertex: Vertex
    }

    private struct Bucket {
        let column: Int
        let first: Reading
        let minimum: Reading
        let maximum: Reading
        let last: Reading

        init(column: Int, reading: Reading) {
            self.column = column
            first = reading
            minimum = reading
            maximum = reading
            last = reading
        }

        private init(column: Int, first: Reading, minimum: Reading, maximum: Reading, last: Reading) {
            self.column = column
            self.first = first
            self.minimum = minimum
            self.maximum = maximum
            self.last = last
        }

        func including(_ reading: Reading) -> Self {
            let minimum = reading.vertex.value < minimum.vertex.value ? reading : minimum
            let maximum = reading.vertex.value > maximum.vertex.value ? reading : maximum
            return Bucket(column: column, first: first, minimum: minimum, maximum: maximum, last: reading)
        }

        var readings: [Reading] {
            [first, minimum, maximum, last].sorted { $0.index < $1.index }
        }
    }

    init(series: HistorySeries, window: HistoryInterval, scale: Sparkline.Scale, size: CellSize) {
        guard size.width > 0, size.height > 0 else {
            content = .drawing([])
            return
        }
        let runs = Self.visibleRuns(series: series, window: window)
        let bounds: ClosedRange<Double>
        switch scale {
        case .fixed(let fixed): bounds = fixed
        case .automatic:
            let values = runs.flatMap { $0 }.map(\.value)
            guard let minimum = values.min(), let maximum = values.max() else {
                content = .drawing([])
                return
            }
            bounds = minimum...maximum
        }
        let lastColumn = size.width * 2 - 1
        let lastRow = size.height * 4 - 1
        var strokes: [HistoryDrawing.Stroke] = []
        var work = 0
        for run in runs {
            let reduced = Self.reduced(run, lastColumn: lastColumn)
            if reduced.count == 1, let vertex = reduced.first, bounds.contains(vertex.value) {
                let point = Self.point(vertex, bounds: bounds, lastColumn: lastColumn, lastRow: lastRow)
                guard work < Self.maximumDrawingWork else {
                    content = .unavailable
                    return
                }
                strokes.append(HistoryDrawing.Stroke(start: point, end: point))
                work += 1
            }
            for index in reduced.indices.dropFirst() {
                guard let clipped = Self.clip(reduced[index - 1], reduced[index], bounds: bounds) else { continue }
                let start = Self.point(clipped.0, bounds: bounds, lastColumn: lastColumn, lastRow: lastRow)
                let end = Self.point(clipped.1, bounds: bounds, lastColumn: lastColumn, lastRow: lastRow)
                // Native Bresenham visits exactly max(dx, dy) + 1 samples.
                let cost = max(abs(end.x - start.x), abs(end.y - start.y)) + 1
                guard cost <= Self.maximumDrawingWork - work else {
                    content = .unavailable
                    return
                }
                strokes.append(HistoryDrawing.Stroke(start: start, end: end))
                work += cost
            }
        }
        content = .drawing(strokes)
    }

    private static func visibleRuns(series: HistorySeries, window: HistoryInterval) -> [[Vertex]] {
        var visible: [[Vertex]] = []
        for segment in series.segments {
            var run: [Observation] = []
            for sample in segment {
                if let value = sample.value {
                    run.append(Observation(offset: sample.offset, value: value))
                } else {
                    let clipped = clipInTime(run, window: window)
                    if !clipped.isEmpty { visible.append(clipped) }
                    run.removeAll(keepingCapacity: true)
                }
            }
            let clipped = clipInTime(run, window: window)
            if !clipped.isEmpty { visible.append(clipped) }
        }
        return visible
    }

    private static func clipInTime(_ run: [Observation], window: HistoryInterval) -> [Vertex] {
        let start = window.range.lowerBound
        let end = window.range.upperBound
        guard let first = run.firstIndex(where: { $0.offset >= start }) else { return [] }
        let duration = seconds(end - start)
        var vertices: [Vertex] = []
        if first > 0, run[first].offset > start {
            let left = run[first - 1]
            let right = run[first]
            let fraction = seconds(start - left.offset) / seconds(right.offset - left.offset)
            vertices.append(Vertex(x: 0, value: interpolate(left.value, right.value, fraction: fraction)))
        }
        var index = first
        while index < run.count, run[index].offset <= end {
            let sample = run[index]
            vertices.append(Vertex(x: seconds(sample.offset - start) / duration, value: sample.value))
            index += 1
        }
        if index > 0, index < run.count, run[index - 1].offset < end {
            let left = run[index - 1]
            let right = run[index]
            let fraction = seconds(end - left.offset) / seconds(right.offset - left.offset)
            vertices.append(Vertex(x: 1, value: interpolate(left.value, right.value, fraction: fraction)))
        }
        return vertices
    }

    private static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    private static func interpolate(_ start: Double, _ end: Double, fraction: Double) -> Double {
        if fraction <= 0 { return start }
        if fraction >= 1 { return end }
        if start == end { return start }
        // Subtraction can overflow opposite extremes; adding a rounded same-sign
        // difference can also overflow near the greatest finite endpoint. Blend
        // normalized endpoints, bounding arithmetic roundoff before restoring
        // magnitude so every intermediate and the final reading remain finite.
        let magnitude = max(abs(start), abs(end))
        let normalizedStart = start / magnitude
        let normalizedEnd = end / magnitude
        let blended = normalizedStart * (1 - fraction) + normalizedEnd * fraction
        let normalizedLower = min(normalizedStart, normalizedEnd)
        let normalizedUpper = max(normalizedStart, normalizedEnd)
        let bounded = min(normalizedUpper, max(normalizedLower, blended))
        let restored = bounded * magnitude
        return min(max(start, end), max(min(start, end), restored))
    }

    private static func reduced(_ run: [Vertex], lastColumn: Int) -> [Vertex] {
        var selected: [Reading] = []
        var bucket: Bucket?
        func flush(_ pending: Bucket) {
            for reading in pending.readings where selected.last?.index != reading.index {
                selected.append(reading)
            }
        }
        for (index, vertex) in run.enumerated() {
            let column = Int((vertex.x * Double(lastColumn)).rounded(.down))
            let reading = Reading(index: index, vertex: vertex)
            if let pending = bucket, pending.column == column {
                bucket = pending.including(reading)
            } else {
                if let pending = bucket { flush(pending) }
                bucket = Bucket(column: column, reading: reading)
            }
        }
        if let pending = bucket { flush(pending) }
        return selected.map(\.vertex)
    }

    private static func fraction(_ value: Double, lower: Double, upper: Double) -> Double {
        guard lower < upper else { return 0.5 }
        if value <= lower { return 0 }
        if value >= upper { return 1 }
        let span = upper - lower
        if span.isFinite { return (value - lower) / span }
        let magnitude = max(abs(lower), abs(upper))
        return (value / magnitude - lower / magnitude) / (upper / magnitude - lower / magnitude)
    }

    private static func intersection(_ value: Double, start: Vertex, end: Vertex) -> Vertex {
        let amount: Double
        if start.value < end.value {
            amount = fraction(value, lower: start.value, upper: end.value)
        } else {
            amount = 1 - fraction(value, lower: end.value, upper: start.value)
        }
        return Vertex(x: start.x + (end.x - start.x) * amount, value: value)
    }

    private static func clip(_ start: Vertex, _ end: Vertex,
                             bounds: ClosedRange<Double>) -> (Vertex, Vertex)? {
        let lower = bounds.lowerBound
        let upper = bounds.upperBound
        let isEntirelyBelow = start.value < lower && end.value < lower
        let isEntirelyAbove = start.value > upper && end.value > upper
        guard !isEntirelyBelow && !isEntirelyAbove else { return nil }
        let clippedStart: Vertex
        if start.value < lower { clippedStart = intersection(lower, start: start, end: end) }
        else if start.value > upper { clippedStart = intersection(upper, start: start, end: end) }
        else { clippedStart = start }
        let clippedEnd: Vertex
        if end.value < lower { clippedEnd = intersection(lower, start: start, end: end) }
        else if end.value > upper { clippedEnd = intersection(upper, start: start, end: end) }
        else { clippedEnd = end }
        return (clippedStart, clippedEnd)
    }

    private static func point(_ vertex: Vertex, bounds: ClosedRange<Double>,
                              lastColumn: Int, lastRow: Int) -> CellPoint {
        let height = fraction(vertex.value, lower: bounds.lowerBound, upper: bounds.upperBound)
        // Only numerical boundary roundoff is bounded here; actual geometric
        // clipping has already happened in time and measurement coordinates.
        let x = min(lastColumn, max(0, Int((vertex.x * Double(lastColumn)).rounded())))
        let y = min(lastRow, max(0, Int(((1 - height) * Double(lastRow)).rounded())))
        return CellPoint(x: x, y: y)
    }
}

private struct HistoryDrawing {
    struct Stroke: Equatable, Sendable {
        let start: CellPoint
        let end: CellPoint
    }

    let strokes: [Stroke]
}

extension HistoryDrawing: CanvasDrawing {
    func draw(into context: inout CanvasContext) {
        for stroke in strokes {
            let start = Point(x: Double(stroke.start.x) / 2, y: Double(stroke.start.y) / 4)
            let end = Point(x: Double(stroke.end.x) / 2, y: Double(stroke.end.y) / 4)
            context.line(from: start, to: end)
        }
    }
}
