# Compact instrumentation and duration display

**Status:** Accepted presentation contracts. Compact styles, `Sparkline` and plain
`DurationText` shipped in 0.1.0; measurement gauges and segmented readouts extend
those contracts and have not yet been included in a tagged release.
The expansion below is an accepted implementation candidate on `codex/instrumentation`.
It is for PR review and has not been merged or released. The complete local
macOS gate, independent source reviews and release terminal captures pass; hosted
macOS/Linux checks and publication remain tracked in [Plan](../Plan.md).

Present supplied measurements and durations; applications retain sampling, timing and interpretation.

## Compact instrumentation

`ChioTheme.btop` uses near-black/cyan semantic roles and native strokes, without
a palette dependency or separate component family.

`ChioGroupBoxStyle(titlePlacement: .border)` overlays a passive, single-row title
on the top border. It truncates to allocation, preserves corners and omits title
paint below five columns. The authored label stays mounted across resizing; only
its focus/hit testing are disabled. Content remains native and enabled. `.content`
is the default; native sizing and ancestor clipping still apply.

`ChioProgressViewStyle(treatment: .measurement)` uses accent for every determinate
value, including 100%; default `.progress` uses success at completion. Native
fraction, labels and indeterminate behavior are shared. Accessibility remains a
normalized progress bar; applications own units, thresholds and meaning.

`Sparkline` draws one passive series with native Canvas/braille packing. Slots are
equally spaced, oldest to newest. `nil` is a missing reading that breaks the line,
distinct from zero or an omitted slot. Construction rejects nonfinite readings
and fixed bounds that are nonfinite or not strictly increasing. Serializable
`Scale` is input configuration, validated when consumed by the view.

Automatic scale uses finite extrema; constant series sit at the midpoint.
Empty/all-missing series draw nothing. A single-entry series sits on the right;
a lone reading among gaps retains its slot. Fixed scales clip outliers.
Overflow-safe normalization handles extreme finite bounds; drawing coordinates
are bounded before submission.

Narrow reduction retains first/last/minimum/maximum in chronological order per
drawing column within each contiguous run. Gaps disconnect runs even within one
column, although subcolumn gaps may not be visibly distinct. Every draw scans
input, so applications bound history retention. Native image semantics provide
a count/latest/extrema summary that applications can replace to include units.
Chio owns no sampler, clock, monitoring state or alert policy. Native overlapping
subcell writes share one cell's paint; independently colored overlaps are unclaimed.

## Measurement gauges and numeric readouts

`MeasurementGauge(position:style:)` presents an application-normalized position.
A known position must be finite and in `0...1`; construction traps otherwise.
`nil` means a missing reading, distinct from zero. Applications own scale
normalization, units, thresholds, out-of-range policy and surrounding labels.
The view owns no sampler, clock or monitoring state.

`.bar` is the default and uses one row; `.dial` uses up to five rows. Both use
native Canvas, prefer twenty columns and bound drawing to 512 columns. Missing
bars show dots and missing dials retain their arc without a needle. The current
theme's accent applies at every position, including one. Native image semantics
supply a normalized-position or missing-reading summary; applications should
replace it with their scale and units. The gauge is passive and adds no focus stop.

`InstrumentReadout(_:style:)` presents an application-formatted string in theme
accent, with the original string as its accessibility label. `.segmented` is the
default and paints three rows; `.plain` uses native text. Segmented lettering
supports digits, decimal points, colons and signs (`+`, `-`), at most 32 characters.
Empty, unsupported or longer values use native text. Native `ViewThatFits` also
chooses text when the complete lettering does not fit the allocation. Formatting,
units and interpretation remain application-owned; this is a passive readout.
Segmented artwork always measures all three rows, regardless of inherited text
line limits. The ordinary-text fallback retains the caller's native line limit.

## Instrumentation expansion assessment

**Status:** Accepted scope, implemented as a candidate for PR review.
This record describes the current source contracts. The earlier source assessment
led to native styles and composition;
`InstrumentTile`, domain widgets, compasses and multiple overlaid series remain deferred.

The candidate adds `.labeledContentStyle(.instrument)`, checked gauge target bands
and independent reference marks, `HistoryChart` with checked snapshots and windows,
and themed native slider/stepper styles. Supporting/paired readings, trends,
responsive collections and playback remain ordinary native view recipes.
All styles follow the [pure style contract](../Design.md#styles-and-view-contracts).
No new package, chart dependency, sampler, telemetry service or playback framework
is introduced. Applications own formatting, normalization, clocks, history
retention, interpretation and which supporting facts may be omitted.

## Native instrument API

<a id="proposed-instrument-api"></a>

`ChioInstrumentLabeledContentStyle()` conforms to native `LabeledContentStyle`;
`.instrument` is its shorthand:

```swift
LabeledContent("Temperature", value: "21.4 °C")
    .labeledContentStyle(.instrument)

LabeledContent("Temperature") {
    HStack(alignment: .bottom, spacing: 1) {
        InstrumentReadout("21.4")
        Text("°C")
    }
}
.labeledContentStyle(.instrument)
```

The style consumes the current `chioTheme`, arranging a muted label above an
accented reading with semantic spacing. It hosts each authored label/content slot
once. Content remains arbitrary native views: it never parses formatted text,
formats measurements or infers missing values. It adds no state, tasks, clock
reads, acquisition, border, fixed dimensions or focus stop. Caller content may
retain its own native state and effects; the style adds none.

The style is opt-in. `.chioTheme` does not install it on ordinary labelled facts.
The nearest native style scope wins. There is no universal instrument style
protocol, role flag or compact/prominent variant. An already-titled `GroupBox`
can compose `InstrumentReadout` or custom content directly; the pinned native
labelled-content API has no label-hiding modifier.

### Expanded, paired and missing readings

Compose groups and independent facts with native views:

```swift
GroupBox("Temperature") {
    VStack(alignment: .leading, spacing: 1) {
        LabeledContent("Current", value: "Unavailable")
            .labeledContentStyle(.instrument)
        MeasurementGauge(position: nil)
            .frame(height: 1)
        LabeledContent("Recorded mean", value: "20.8 °C")
        LabeledContent("Recorded maximum", value: "24.8 °C")
    }
}
.chioTheme(.btop)

HStack(alignment: .top, spacing: 2) {
    LabeledContent("Inlet", value: "18.2 °C")
    LabeledContent("Outlet", value: "21.4 °C")
}
.labeledContentStyle(.instrument)
```

Known recorded facts remain independent of a missing current reading. Empty text
is not a missing sentinel. Group chrome belongs to `GroupBoxStyle`; grouping,
order, priorities and layout alternatives belong to the application.

### Responsive layout and the deferred tile

<a id="proposed-responsive-instrument-tile"></a>

`InstrumentTile` remains deferred. Use native stacks or `AnyLayout` for one
authored child set, or passive `ViewThatFits` alternatives for application-owned
priority choices. Keep controls and resource owners outside repeated fit
alternatives. The pinned native implementation resolves every candidate and
chooses the last even if none fits; the parent must provide space or scrolling.
There is no public native grid at this dependency revision.

Compact composition may omit a complete optional support group. When admitting
a gauge or history plot, reserve its complete plot and caption height; silently
clipping reference captions is not an acceptable simplification. Regrouping views
can change identity, so focus and resize recovery need retained-session evidence.
A future container needs repeated shared fitting policy beyond these recipes.

## Target bands and independent gauge references

<a id="proposed-target-band-gauge"></a>

The existing initializer and position preconditions remain intact. The candidate
adds distinct overloads:

```swift
// Legacy initializer.
init(position: Double?, style: Style = .bar)

init(position: Double?, targetBand: TargetBand?, style: Style = .bar)

init(position: Double?, referenceMarks: ReferenceMarks,
     targetBand: TargetBand? = nil, style: Style = .bar)
```

Position, target and references are independent supplied facts. Missing position
may retain known annotations. A desired interval is not success/failure, and a
reference is not a threshold or an inferred statistic. Applications supply units,
normalization and complete explanatory captions.

`MeasurementGauge.TargetBand(lowerBound:upperBound:)` throws its nested
`ValidationError` unless both bounds are finite, in `0...1` and strictly increasing.
Its immutable `range` is inclusive. `nil` removes the target. Bars add a separate
track (`╞═╡`, or `╪` when endpoints share a cell); dials use an inner arc and endpoint
marks. Tiny geometry may merge marks, so author a target caption when useful.

`MeasurementGauge.ReferenceMark(id:label:position:)` throws its nested error for
nonfinite/out-of-range positions or an empty label. The label must be a complete
authored caption, including units when useful. `ReferenceMarks(_:)` checks at most
two marks with unique caller IDs; an empty collection removes them. Labels and
positions need not be sorted or unique. Even captions such as mean and maximum
impose no relative ordering of positions. The gauge computes no statistics.

Caller order determines ordinals `1` and `2`. A shared reference cell displays
`*`, while both numbered native text captions remain present below the plot.
Dials reserve the entire ordinal cell, clearing braille samples before placing
the glyph; reference text takes precedence over arc, target and needle paint.
This is an explicit monochrome collision policy, not independently colored overlap.

```swift
let target = try MeasurementGauge.TargetBand(lowerBound: 0.45, upperBound: 0.60)
let references = try MeasurementGauge.ReferenceMarks([
    MeasurementGauge.ReferenceMark(id: "mean", label: "Mean 20.8 °C", position: 0.52),
    MeasurementGauge.ReferenceMark(id: "maximum", label: "Maximum 24.8 °C", position: 0.62)
])
MeasurementGauge(position: nil, referenceMarks: references,
                 targetBand: target, style: .dial)
```

Bars reserve one reading row plus one target row when present and one reference
track when present. Dials reserve up to five plot rows. Reference captions add
native wrapping height beyond that plot. Applications must reserve the whole
layout; compact views may omit the complete optional reference group. Existing
no-band/no-reference geometry, paint and accessibility remain compatibility gates.
New checked annotation values are immutable, hashable and sendable, without a
Codable or persisted representation contract.

## Time-aware history

<a id="proposed-time-aware-history"></a>

`HistoryChart` places one supplied history proportionally in an explicit time
window. `Sparkline` keeps its existing equally spaced slots and singleton rules.
The accepted segmented contract below supersedes the earlier strict-increasing
sample and `missingIntervals` proposal; those are not current APIs.

```swift
let series = try HistorySeries(segments: [
    [HistorySeries.Sample(offset: .seconds(0), value: 72),
     HistorySeries.Sample(offset: .seconds(7), value: 94),
     HistorySeries.Sample(offset: .seconds(7), value: 118),
     HistorySeries.Sample(offset: .seconds(19), value: nil),
     HistorySeries.Sample(offset: .seconds(26), value: 81)],
    [HistorySeries.Sample(offset: .seconds(61), value: 310),
     HistorySeries.Sample(offset: .seconds(83), value: 88)]
])
let window = try HistoryInterval(start: .seconds(0), end: .seconds(90))
HistoryChart(series, window: window, scale: .fixed(0...500))
    .frame(width: 48, height: 8)
    .accessibilityLabel("Service response time in milliseconds in the selected ninety seconds.")
```

The outer `try` covers nested checked construction. Equal offsets preserve
separate observations and may connect vertically. The nil reading breaks both
adjacent connections. The segment boundary prohibits the connection from 26 to
61 seconds, without asserting an outage duration.

### Supplied values and admission

| Type | Read-only values | Checked construction |
| --- | --- | --- |
| `HistoryInterval` | `range: ClosedRange<Duration>` | `init(start:end:) throws(ValidationError)` |
| `HistorySeries.Sample` | `offset: Duration`, `value: Double?` | `init(offset:value:) throws(ValidationError)` |
| `HistorySeries` | `segments: [[Sample]]` | `init(samples:)` or `init(segments:) throws(ValidationError)` |

`HistoryInterval` is a display window only. Its bounds and sample offsets are
exact source `Duration` values in `0...Duration.seconds(Int64.max)`; window bounds
must strictly increase. Applications translate wall timestamps into that origin.
Chio reads no clock and invents no cadence. Known readings must be finite; zero
is valid and distinct from unavailable `nil`.

Offsets must be nondecreasing within each nonempty segment. Separate segments may
restart, backtrack or overlap in time; they express a connection break, without
inferred outage timing. `init(samples: [])` and `init(segments: [])` are valid blank
histories, but a supplied empty segment is rejected. Limits are 16,384 samples
total and 4,096 segments. Typed series errors identify the offending segment or
sample for relationship failures. Inputs are never sorted, averaged or repaired.
Rebuild a checked replacement to change data/window; the original stays unchanged.
These immutable values are hashable and sendable, with no new Codable contract.

### Window, scale and bounded drawing

`HistoryChart(_:window:scale:)` defaults to `.automatic`, reusing `Sparkline.Scale`.
Fixed bounds must be finite and strictly increasing. The window never advances
itself. A lone reading stays at its timestamp. Linear connections exist only
between adjacent known readings in the same segment; wide spacing alone does not
break a line. Missing readings and explicit boundaries prohibit connections.

Clip time before rasterization, using exterior neighbors only to compute real
window intersections. A connection may cross the entire window without an inside
sample; there is no extrapolation or clamping of all outside points to an edge.
Automatic scaling uses visible clipped geometry, including interpolated boundary
endpoints; exterior extrema do not flatten the plot. Constants are centered and
empty visible geometry draws nothing. Fixed scaling clips actual lines against
the display rectangle. Interpolated boundary values are not supplied observations.
Subtract exact `Duration` offsets before converting deltas to drawing coordinates.

Dense uninterrupted runs retain first/last/minimum/maximum per time-mapped braille
column in source order. Never connect across a break; subcolumn gaps can still be
visually indistinguishable. Allocation is bounded to 512 columns by 64 rows.
Native line work is bounded to 262,144 grid samples per drawing. Exceeding either
budget replaces the whole plot with an explicit unavailable message before native
painting; no partial history is presented as complete. These operation limits do
not establish hosted-frame or SSH latency.

Native image semantics summarize supplied readings and missing observations
inside the window. Applications can replace the label with domain language and
author axis/unit/time captions outside the drawing. Multiple series, smoothing,
step/hold plots, automatic scrolling and interactive inspection remain deferred.

## Native composition recipes

**Trend:** use an authored `Label` or `Text` with a decorative directional glyph:

```swift
Label("Response time falling by 12 ms over the last minute") {
    Text("↓").accessibilityHidden(true)
}
```

The app chooses comparison, deadband, freshness, magnitude and desirability.
Unavailable comparison is distinct from stable or zero. Chio infers no trend and
provides no trend enum, grouping DTO or domain-specific instrument model.

**Playback and adjustment:** compose native buttons, integer `Slider` for sequence
position and `Stepper` for discrete adjustments. `.chioTheme` now installs
`ChioSliderStyle()` and `ChioStepperStyle()` globally in its scope. Both are pure
presentation transformations using environment and native configuration. They
retain authored label/value slots, enabled/focus feedback, the native routed slider
track and native increment/decrement actions. SwiftTUI retains binding, keyboard,
pointer, focus and accessibility behavior; styles never invoke actions during
presentation evaluation. Local native style overrides remain available.

```swift
Slider("Sample", value: $selectedIndex, in: 0...119)
Stepper("Step", value: $step, in: 1...3)
```

The application owns play/pause, seeks, source replacement, changing bounds,
clocks and end behavior. Sequence position is not elapsed-time percentage.
`--instruments` demonstrates an application-owned task, without a public playback
controller, timer, transport protocol or framework.

## Expansion verification

Model, raster, retained-session, native input, macOS/Linux, release terminal and
showcase gates are required under [Verification](../Verification.md).
Review immutable construction and failure
boundaries, equal timestamps and overlapping segments, nil versus zero, true
clipping, large Duration origins, extreme finite readings, same-column breaks and
exact/over-budget drawing. Verify independent expected geometry rather than only
reusing rendering helpers.

Gauge checks must preserve legacy initializer references and no-annotation output,
exercise target/reference independence, endpoints, collision cells, all captions,
wrapped units, tiny allocations and retained clearing. Style/control checks must
cover authored slots once, custom content, theme overrides, enabled states,
keyboard/pointer routes, batched input, focus and resize recovery. Test complete
compositions and monochrome as well as isolated primitives.

The synthetic `--instruments` example targets compact 36 × 18 and expanded
70 × 30 layouts. Both allocations pass release raster checks in all three themes;
real terminal captures additionally exercise 76 × 30 and compact-to-wide recovery.
Monochrome captures retain marker ordinals and complete captions. These results
do not establish appearance in every emulator or live SSH responsiveness.
Showcase publication and platform qualification are tracked in [Plan](../Plan.md);
PR review does not constitute merge or release. Provider archive acquisition
remains paused.

## Duration presentation and example-owned timekeeping

`DurationText(elapsed:)` floors whole seconds; `DurationText(remaining:)` rounds
positive fractions up, showing zero only at expiry. Both use `m:ss` below an hour
and `h:mm:ss` thereafter without a 24-hour wrap, accent paint and spoken labels.
Plain text remains the default. `style: .segmented` delegates to
`InstrumentReadout` while retaining duration rounding and spoken labels; its
ordinary-text fallback also applies.
Inputs are nonnegative and at most `Duration.seconds(Int64.max)`, checked before
component extraction. Integer formatting preserves attosecond boundaries.

Applications own measurement, pause/resume, limits and expiry effects; SwiftTUI
owns scheduling/cancellation. The executable's internal immutable `ElapsedTime`
and native timeline demonstrate these contracts. Native schedules retain a stable
origin across renders and pause when idle; recreating a default current-time
origin restarts the driver. No public timekeeping subsystem is part of Chio.

## btop-inspired UI inventory

The accepted btop-inspired work is delivered: a compact palette, optional border
headings, measurement meters and a passive history graph in `--metrics`.
Applications own sampling and interpretation. Dense sorting is demonstrated by
`--inbox`; it does not establish sortable table headers. Draggable split panes,
multiple graph series and additional glyph modes remain unproved. The original
[inventory](https://github.com/echoz/Chio/blob/v0.1.0/Docs/Plan.md#btop-inspired-ui-inventory)
records the reference audit and extraction rationale.

## Implementation and verification

- [MeasurementGauge.swift](../../Sources/Chio/Instrumentation/Presentation/MeasurementGauge.swift)
- [InstrumentReadout.swift](../../Sources/Chio/Instrumentation/Presentation/InstrumentReadout.swift)
- [Sparkline.swift](../../Sources/Chio/Instrumentation/Presentation/Sparkline.swift)
- [SparklineTests.swift](../../Tests/ChioTests/Instrumentation/Presentation/SparklineTests.swift)
- [DurationTextTests.swift](../../Tests/ChioTests/Instrumentation/Presentation/DurationTextTests.swift)
