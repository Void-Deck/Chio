import Chio
import SwiftTUIRuntime
import Testing

@MainActor
struct HistoryChartTests {
    private func series(_ readings: [(Duration, Double?)]) throws -> HistorySeries {
        try HistorySeries(samples: readings.map { try HistorySeries.Sample(offset: $0.0, value: $0.1) })
    }

    private func render(_ series: HistorySeries, start: Duration = .zero, end: Duration = .seconds(10),
                        scale: Sparkline.Scale = .automatic, width: Int = 5, height: Int = 2,
                        theme: ChioTheme = .default) throws -> RenderSnapshot {
        let window = try HistoryInterval(start: start, end: end)
        return DefaultRenderer().render(
            HistoryChart(series, window: window, scale: scale).frame(width: width, height: height).chioTheme(theme),
            proposal: ProposedSize(width: width, height: height))
    }

    // Interpret the public braille output independently of clipping/reduction.
    private func pixels(_ surface: RasterSurface) -> Set<CellPoint> {
        let dots = [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (0, 3), (1, 3)]
        var points: Set<CellPoint> = []
        for (y, row) in surface.lines.enumerated() {
            for (x, character) in row.enumerated() {
                guard let scalar = character.unicodeScalars.first,
                      (0x2800...0x28FF).contains(scalar.value) else { continue }
                let mask = scalar.value - 0x2800
                for (bit, dot) in dots.enumerated() where mask & (1 << bit) != 0 {
                    points.insert(CellPoint(x: x * 2 + dot.0, y: y * 4 + dot.1))
                }
            }
        }
        return points
    }

    @Test("Empty, missing, exterior and zero-allocation histories remain blank")
    func blank() throws {
        let histories = try [series([]), series([(.zero, nil), (.seconds(10), nil)]),
                             series([(.seconds(20), 1), (.seconds(30), 2)])]
        for history in histories {
            for size in [0, 1, 5] {
                #expect(try pixels(render(history, width: size, height: size).rasterSurface).isEmpty)
            }
        }
        let before = try series([(.zero, 1), (.seconds(2), 2)])
        #expect(try pixels(render(before, start: .seconds(3)).rasterSurface).isEmpty)
    }

    @Test("Singleton placement follows time; constant geometry is centered")
    func placement() throws {
        let single = try series([(.seconds(2), 42)])
        #expect(try pixels(render(single).rasterSurface) == [CellPoint(x: 2, y: 4)])
        let constant = try series([(.zero, 3), (.seconds(10), 3)])
        let points = try pixels(render(constant).rasterSurface)
        #expect(points.count == 10)
        #expect(points.allSatisfy { $0.y == 4 })
        let irregular = try series([(.zero, 0), (.seconds(2), 1), (.seconds(10), 0)])
        let irregularPoints = try pixels(render(irregular, scale: .fixed(0...1)).rasterSurface)
        #expect(irregularPoints.contains(CellPoint(x: 2, y: 0)))
        #expect(irregularPoints.contains(CellPoint(x: 9, y: 7)))
    }

    @Test("Equal timestamps draw a vertical connection while breaks never create one")
    func equalTimesAndBreaks() throws {
        let sameTime = try series([(.seconds(5), 0), (.seconds(5), 1)])
        #expect(try pixels(render(sameTime, scale: .fixed(0...1)).rasterSurface)
                == Set((0..<8).map { CellPoint(x: 5, y: $0) }))
        let gap = try series([(.zero, 0), (.milliseconds(100), nil), (.milliseconds(200), 1)])
        #expect(try pixels(render(gap, scale: .fixed(0...1), width: 1).rasterSurface)
                == [CellPoint(x: 0, y: 7), CellPoint(x: 0, y: 0)])
        let low = try HistorySeries.Sample(offset: .milliseconds(200), value: 0)
        let high = try HistorySeries.Sample(offset: .zero, value: 1)
        let disconnected = try HistorySeries(segments: [[low], [high]])
        #expect(try pixels(render(disconnected, scale: .fixed(0...1), width: 1).rasterSurface)
                == [CellPoint(x: 0, y: 7), CellPoint(x: 0, y: 0)])
        // Large spacing alone remains an eligible connection.
        let continuous = try series([(.zero, 0), (.seconds(10), 1)])
        #expect(try pixels(render(continuous, scale: .fixed(0...1)).rasterSurface).count == 10)
    }

    @Test("Time clipping uses exterior neighbors without extrapolation or exterior extrema")
    func timeClipping() throws {
        let crossing = try series([(.zero, 0), (.seconds(20), 20)])
        let fixed = try pixels(render(crossing, start: .seconds(5), end: .seconds(15),
                                      scale: .fixed(0...20)).rasterSurface)
        // At t=5 and t=15, the actual line has readings 5 and 15.
        #expect(fixed.contains(CellPoint(x: 0, y: 5)))
        #expect(fixed.contains(CellPoint(x: 9, y: 2)))
        let automatic = try pixels(render(crossing, start: .seconds(5), end: .seconds(15)).rasterSurface)
        #expect(automatic.contains(CellPoint(x: 0, y: 7)))
        #expect(automatic.contains(CellPoint(x: 9, y: 0)))
        let outsideSpike = try series([(.zero, 10_000), (.seconds(10), 5), (.seconds(20), 6)])
        let visible = try pixels(render(outsideSpike, start: .seconds(10), end: .seconds(20)).rasterSurface)
        #expect(visible.contains(CellPoint(x: 0, y: 7)))
        #expect(visible.contains(CellPoint(x: 9, y: 0)))
        let stopped = try series([(.zero, 0), (.seconds(4), nil), (.seconds(20), 20)])
        #expect(try pixels(render(stopped, start: .seconds(5), end: .seconds(15)).rasterSurface).isEmpty)
        let singletonOutside = try series([(.zero, 1)])
        #expect(try pixels(render(singletonOutside, start: .seconds(5)).rasterSurface).isEmpty)
    }

    @Test("Fixed Y clipping intersects the line rather than clamping exterior endpoints")
    func measurementClipping() throws {
        let rising = try series([(.zero, -10), (.seconds(10), 30)])
        let points = try pixels(render(rising, scale: .fixed(0...10)).rasterSurface)
        // -10 + 4t reaches 0 at t=2.5 and 10 at t=5.
        #expect(points.contains(CellPoint(x: 2, y: 7)))
        #expect(points.contains(CellPoint(x: 5, y: 0)))
        #expect(points.allSatisfy { (2...5).contains($0.x) })
        let falling = try series([(.zero, 30), (.seconds(10), -10)])
        let descending = try pixels(render(falling, scale: .fixed(0...10)).rasterSurface)
        #expect(descending.contains(CellPoint(x: 5, y: 0)))
        #expect(descending.contains(CellPoint(x: 7, y: 7)))
        let exterior = try series([(.zero, 11), (.seconds(10), 20)])
        #expect(try pixels(render(exterior, scale: .fixed(0...10)).rasterSurface).isEmpty)
    }

    @Test("Nearby observations at a large origin preserve tiny time differences")
    func largeOrigins() throws {
        let origin = Duration.seconds(Int64.max - 1)
        let delta = Duration(secondsComponent: 0, attosecondsComponent: 1)
        let history = try series([(origin, 0), (origin + delta * 2, 1), (origin + delta * 10, 0)])
        let points = try pixels(render(history, start: origin, end: origin + delta * 10,
                                       scale: .fixed(0...1)).rasterSurface)
        #expect(points.contains(CellPoint(x: 0, y: 7)))
        #expect(points.contains(CellPoint(x: 2, y: 0)))
        #expect(points.contains(CellPoint(x: 9, y: 7)))
    }

    @Test("Extreme finite interpolation, fixed intersections and subnormal scales stay finite")
    func numericLimits() throws {
        let greatest = Double.greatestFiniteMagnitude
        let extreme = try series([(.zero, -greatest), (.seconds(20), greatest)])
        let cropped = try pixels(render(extreme, start: .seconds(5), end: .seconds(15)).rasterSurface)
        #expect(cropped.contains(CellPoint(x: 0, y: 7)))
        #expect(cropped.contains(CellPoint(x: 9, y: 0)))
        let narrowY = try pixels(render(extreme, end: .seconds(20), scale: .fixed(0...100)).rasterSurface)
        #expect(narrowY == Set((0..<8).map { CellPoint(x: 5, y: $0) }))
        let tiny = Double.leastNonzeroMagnitude
        let tinySeries = try series([(.zero, 0), (.seconds(5), tiny), (.seconds(10), tiny * 2)])
        let ordinary = try series([(.zero, 0), (.seconds(5), 1), (.seconds(10), 2)])
        #expect(try pixels(render(tinySeries).rasterSurface) == pixels(render(ordinary).rasterSurface))
        #expect(cropped.allSatisfy { (0..<10).contains($0.x) && (0..<8).contains($0.y) })
    }

    @Test("Rounded time fractions at admitted extreme endpoints never create a nonfinite reading")
    func roundedExtremeEndpoint() throws {
        let start = 0x1.0000000000003p+1022
        let end = Double.greatestFiniteMagnitude
        let positive = try series([(.zero, start), (.seconds(Int64.max), end), (.seconds(Int64.max), 0)])
        let top = Set((0..<10).map { CellPoint(x: $0, y: 0) })
        let right = Set((0..<8).map { CellPoint(x: 9, y: $0) })
        // Converting these neighboring large durations produces a fraction of
        // exactly one. The clipped endpoint must remain the supplied finite end.
        #expect(try pixels(render(positive, start: .seconds(Int64.max - 1), end: .seconds(Int64.max)).rasterSurface)
                == top.union(right))
        let negative = try series([(.zero, -start), (.seconds(Int64.max), -end), (.seconds(Int64.max), 0)])
        let bottom = Set((0..<10).map { CellPoint(x: $0, y: 7) })
        #expect(try pixels(render(negative, start: .seconds(Int64.max - 1), end: .seconds(Int64.max)).rasterSurface)
                == bottom.union(right))
    }

    @Test("Narrow reduction retains a short spike and trough in source order")
    func reduction() throws {
        let dense = try series((0..<100).map { index in
            let value: Double
            if index == 30 { value = 100 }
            else if index == 31 { value = 0 }
            else { value = 50 }
            return (.seconds(index), value)
        })
        for width in [1, 2, 8] {
            let points = try pixels(render(dense, end: .seconds(99), scale: .fixed(0...100), width: width).rasterSurface)
            #expect(points.contains { $0.y == 0 })
            #expect(points.contains { $0.y == 7 })
            #expect(points.allSatisfy { (0..<(width * 2)).contains($0.x) && (0..<8).contains($0.y) })
        }
    }

    @Test("Exact drawing and allocation limits render; excess rejects the complete chart")
    func drawingLimits() throws {
        let low = try HistorySeries.Sample(offset: .seconds(5), value: 0)
        let high = try HistorySeries.Sample(offset: .seconds(5), value: 1)
        let exact = try HistorySeries(segments: Array(repeating: [low, high], count: 1_024))
        let admitted = try render(exact, scale: .fixed(0...1), width: 1, height: 64)
        // 1,024 separately declared vertical lines each visit exactly 256 samples.
        #expect(pixels(admitted.rasterSurface) == Set((0..<256).map { CellPoint(x: 1, y: $0) }))
        #expect(!admitted.rasterSurface.lines.contains { $0.contains("unavailable") })
        let excess = try HistorySeries(segments: Array(repeating: [low, high], count: 1_025))
        let rejected = try render(excess, scale: .fixed(0...1), width: 40, height: 64)
        #expect(pixels(rejected.rasterSurface).isEmpty)
        #expect(rejected.semanticSnapshot.accessibilityNodes.contains {
            $0.label == "History unavailable: drawing limit exceeded."
        })
        let single = try series([(.seconds(5), 1)])
        #expect(try pixels(render(single, width: 512, height: 64).rasterSurface).count == 1)
        for size in [CellSize(width: 513, height: 64), CellSize(width: 512, height: 65)] {
            let frame = try render(single, width: size.width, height: size.height)
            #expect(pixels(frame.rasterSurface).isEmpty)
            #expect(frame.semanticSnapshot.accessibilityNodes.contains {
                $0.label == "History unavailable: allocation limit exceeded."
            })
        }
    }

    @Test("One accent series and window-only observed facts preserve passive semantics")
    func semanticsAndThemes() throws {
        let history = try series([(.zero, 100), (.seconds(5), 0), (.seconds(7), nil), (.seconds(10), 3)])
        let custom = ChioTheme.default.replacing(
            colors: ChioTheme.default.colors.replacing(accent: Color(hexRGB: 0x123456)))
        for theme in [ChioTheme.default, .light, .btop, custom] {
            let frame = try render(history, start: .seconds(5), theme: theme)
            #expect(frame.semanticSnapshot.focusRegions.isEmpty)
            #expect(frame.semanticSnapshot.accessibilityNodes.contains {
                $0.label == "History in window: 2 readings, 1 missing observations. Minimum: 0.0. Maximum: 3.0."
            })
            let painted = frame.rasterSurface.cells.flatMap { $0 }.filter { $0.character != " " }
            #expect(!painted.isEmpty)
            #expect(painted.allSatisfy { $0.style?.foregroundColor == theme.colors.accent })
        }
        let window = try HistoryInterval(start: .zero, end: .seconds(10))
        let labeled = DefaultRenderer().render(
            HistoryChart(history, window: window).accessibilityLabel("Service latency in milliseconds"),
            proposal: ProposedSize(width: 5, height: 2))
        #expect(labeled.semanticSnapshot.accessibilityNodes.contains { $0.label == "Service latency in milliseconds" })
        let crossing = try series([(.zero, 0), (.seconds(20), 20)])
        #expect(try render(crossing, start: .seconds(5), end: .seconds(15)).semanticSnapshot.accessibilityNodes.contains {
            $0.label == "History in window: 0 readings, 0 missing observations."
        })
    }

    @Test("Legacy scale configuration remains checked when consumed")
    func invalidScale() async {
        await #expect(processExitsWith: .failure) {
            try await MainActor.run {
                let empty = try HistorySeries(samples: [])
                let window = try HistoryInterval(start: .zero, end: .seconds(1))
                _ = HistoryChart(empty, window: window, scale: .fixed(1...1))
            }
        }
        await #expect(processExitsWith: .failure) {
            try await MainActor.run {
                let empty = try HistorySeries(samples: [])
                let window = try HistoryInterval(start: .zero, end: .seconds(1))
                _ = HistoryChart(empty, window: window, scale: .fixed(0...Double.infinity))
            }
        }
    }

    @Test("Retained input replacement, explicit reconnection, clearing, themes and resize preserve surrounding focus")
    func retained() async throws {
        let low = try HistorySeries.Sample(offset: .zero, value: 0)
        let high = try HistorySeries.Sample(offset: .seconds(10), value: 10)
        let window = try HistoryInterval(start: .zero, end: .seconds(10))
        let narrower = try HistoryInterval(start: .seconds(2), end: .seconds(8))
        let snapshots = try [
            HistoryChartSnapshot(series: HistorySeries(segments: [[low], [high]]), window: window,
                                 scale: .fixed(0...10), theme: .default),
            HistoryChartSnapshot(series: HistorySeries(samples: [low, high]), window: window,
                                 scale: .fixed(0...10), theme: .default),
            HistoryChartSnapshot(series: HistorySeries(samples: [low, high]), window: narrower,
                                 scale: .automatic, theme: .btop),
            HistoryChartSnapshot(series: HistorySeries(samples: []), window: narrower,
                                 scale: .fixed(-1...1), theme: .light),
        ]
        let recorder = HostedFrameRecorder()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 16, height: 6), appearance: .fallback,
                                          onFrame: { recorder.receive($0) })
        let session = try HostedSceneSession(for: HistoryChartTestApp(snapshots: snapshots),
                                            sceneID: "history-chart", surface: surface)
        let task = Task { try await session.start() }
        do {
            let initial = try await recorder.wait(description: "two disconnected observations and native button focus") {
                $0.focusedIdentity != nil && $0.raster.lines.contains { $0.contains("Phase=0") }
            }
            #expect(pixels(initial.raster).count == 2)
            session.send(.key(.return))
            let connected = try await recorder.wait(after: initial.sequence, description: "explicit replacement connects the history") {
                $0.raster.lines.contains { $0.contains("Phase=1") }
            }
            #expect(pixels(connected.raster).count > 2)
            #expect(connected.focusedIdentity == initial.focusedIdentity)
            session.send(.key(.return))
            let cropped = try await recorder.wait(after: connected.sequence, description: "new window, automatic scale and theme are visible") {
                $0.raster.lines.contains { $0.contains("Phase=2") }
            }
            #expect(pixels(cropped.raster).count > 2)
            #expect(cropped.focusedIdentity == initial.focusedIdentity)
            let painted = cropped.raster.cells.flatMap { $0 }.filter {
                $0.character.unicodeScalars.contains { (0x2801...0x28FF).contains($0.value) }
            }
            #expect(painted.allSatisfy { $0.style?.foregroundColor == ChioTheme.btop.colors.accent })
            surface.updateSurfaceSize(CellSize(width: 8, height: 5))
            session.requestSurfaceRefresh()
            let resized = try await recorder.wait(after: cropped.sequence, description: "the chart recovers at a smaller allocation") {
                $0.raster.size == CellSize(width: 8, height: 5)
            }
            #expect(!pixels(resized.raster).isEmpty)
            #expect(pixels(resized.raster) != pixels(cropped.raster))
            #expect(resized.focusedIdentity == initial.focusedIdentity)
            session.send(.key(.return))
            let cleared = try await recorder.wait(after: resized.sequence, description: "empty replacement clears every retained chart pixel") {
                $0.raster.lines.contains { $0.contains("Phase=3") }
            }
            #expect(pixels(cleared.raster).isEmpty)
            #expect(cleared.focusedIdentity == initial.focusedIdentity)
            session.stop()
            #expect(try await task.value == .inputEnded)
        } catch {
            session.stop()
            _ = await task.result
            throw error
        }
    }
}

private struct HistoryChartSnapshot: Sendable {
    let series: HistorySeries
    let window: HistoryInterval
    let scale: Sparkline.Scale
    let theme: ChioTheme
}

private struct HistoryChartTestApp {
    let snapshots: [HistoryChartSnapshot]

    nonisolated init(snapshots: [HistoryChartSnapshot]) { self.snapshots = snapshots }
}

extension HistoryChartTestApp: App {
    nonisolated init() { self.init(snapshots: []) }

    var body: some Scene {
        WindowGroup(id: "history-chart") {
            if snapshots.isEmpty { Text("No history fixtures supplied.") }
            else { HistoryChartTestView(snapshots: snapshots) }
        }
        .exitOnKeys([])
    }
}

@MainActor
private struct HistoryChartTestView {
    @State private var phase = 0
    let snapshots: [HistoryChartSnapshot]
}

extension HistoryChartTestView: View {
    var body: some View {
        let snapshot = snapshots[phase]
        VStack(alignment: .leading, spacing: 0) {
            Button("Next") { phase = min(snapshots.count - 1, phase + 1) }
            Text("Phase=\(phase)")
            HistoryChart(snapshot.series, window: snapshot.window, scale: snapshot.scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .chioTheme(snapshot.theme)
    }
}
