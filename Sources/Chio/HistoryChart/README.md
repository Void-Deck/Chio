# HistoryChart

`HistoryChart` presents one history proportionally within an explicit time window.
It draws supplied observations and connections, including irregular sampling and
explicit breaks. It is a passive public view in the `Chio` library.

## Use

With `Chio` and `SwiftTUIViews` imported, construct checked values in a throwing
application scope and compose the chart in a SwiftTUI view:

```swift
let series = try HistorySeries(samples: [
    HistorySeries.Sample(offset: .seconds(0), value: 72),
    HistorySeries.Sample(offset: .seconds(7), value: 94),
    HistorySeries.Sample(offset: .seconds(19), value: nil),
    HistorySeries.Sample(offset: .seconds(26), value: 81)
])
let window = try HistoryInterval(start: .zero, end: .seconds(30))
HistoryChart(series, window: window, scale: .fixed(0...150))
    .frame(width: 40, height: 6)
    .accessibilityLabel("Response time in milliseconds over thirty seconds.")
    .style(.btop)
```

`init(_:window:scale:)` defaults to `.automatic` and shares `Sparkline.Scale`.
Compose axis, unit and time captions outside the chart. The environment supplies
its accent color. [Sparkline](../Sparkline/README.md) instead uses equally spaced slots.

## Behavior and ownership

Checked `HistorySeries.Sample`, `HistorySeries` and `HistoryInterval` initializers
throw typed validation errors. Offsets and window bounds use nonnegative `Duration`
values through `Duration.seconds(Int64.max)`; the window must strictly increase.
Known readings must be finite. Fixed scale bounds fail a view-construction
precondition unless finite and strictly increasing.

Within each nonempty segment, offsets are nondecreasing; equal offsets can connect
vertically. `nil` breaks both adjacent connections. Separate segments may restart
or overlap in time and never connect. Empty history is valid; empty supplied
segments are rejected. Admission allows 16,384 samples and 4,096 segments.

Time and fixed-scale clipping intersect real connections without extrapolation.
Automatic scaling uses visible clipped geometry and centers constants. Dense runs
retain extrema and endpoints per drawing column; subcolumn gaps may be invisible.
Allocation above 512 columns or 64 rows, or work above 262,144 native grid samples,
replaces the whole plot with an explicit unavailable message.

Applications own time origins, clocks, sampling, retention, navigation and captions.
The window never advances itself. Supply checked replacements to update data.
The default accessibility summary covers supplied observations inside the window;
it does not turn interpolated boundary points into observations.

## Source and verification

[HistoryChart.swift](Presentation/HistoryChart.swift),
[HistorySeries.swift](Domain/HistorySeries.swift) and
[HistoryInterval.swift](Domain/HistoryInterval.swift) own the implementation.
[Presentation tests](../../../Tests/ChioTests/HistoryChart/Presentation/HistoryChartTests.swift)
cover clipping, budgets and retained updates; [domain tests](../../../Tests/ChioTests/HistoryChart/Domain/HistorySeriesTests.swift)
and [interval tests](../../../Tests/ChioTests/HistoryChart/Domain/HistoryIntervalTests.swift)
cover checked admission. See the [owning decision](../../../Docs/Decisions/Instrumentation.md),
[Usage](../../../Docs/Usage.md) and [Verification](../../../Docs/Verification.md).
