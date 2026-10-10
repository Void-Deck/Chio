# Compact instrumentation and duration display

**Status:** Accepted presentation contracts. Compact styles, `Sparkline` and plain
`DurationText` shipped in 0.1.0; measurement gauges and segmented readouts extend
those contracts and have not yet been included in a tagged release.
The expansion assessment below contains proposals, not available APIs or an
implementation commitment.

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

**Status:** Full inventory assessed against Chio `c984f66` and its pinned SwiftTUI
revision `2d84ac7083993da2ef52e9d3d30255467efb9553`. This is source-level design
evidence, including separate gauge, chart and composition assessments. Candidate
call sites are uncompiled; numerical safety, fitting, performance and new visual
treatments still require the proofs below.

| Capability | Recommendation | Reusable contribution | Relative work / main uncertainty |
| --- | --- | --- | --- |
| Instrument tile | Prove, then consider one new passive view | Preserve complete readings and essential facts before optional visuals | Medium; native fit probes versus wrapping and minimum allocation |
| Primary reading with supporting facts | Part of the tile | Independent facts remain visible when the current reading is unavailable | Included in tile; no separate model or view |
| Target-band gauge | Extend `MeasurementGauge` | Draw an authored desired interval without interpreting it as success/failure | Medium; monochrome geometry and small dials |
| Timestamped history | Prove a separate one-series `HistoryChart` | Proportional elapsed-time placement, declared gaps and correct clipping | Largest; numerical correctness and dense interrupted histories |
| Trend indicator | Native composition first | Directional glyph with complete authored explanation | Small; public extraction is not yet justified |
| Paired/grouped readings | Composition recipe | Arrange independent instruments/facts without imposing their meaning | Small; complete facts and resize recovery |
| Responsive collections | Application composition first | Native reflow, scrolling or paging selected by the application | Variable; identity and application priority policy |
| Playback controls | Native controls and styles | Existing bindings, input, focus and accessibility | Small recipe; any shared control style needs separate evidence |
| Domain-specific instruments / compass | Retain in applications; compass deferred | Domain interpretation is not generic presentation | Missing compass reference/orientation contract |

The proposed sequence is tile proof and neutral recipes, narrow tile promotion
if justified, target bands, then time-aware history. This is a recommendation for
separate reviewable slices, not authorization to build the entire inventory.
No new package, chart dependency, registry, clock, sampler or telemetry service
is needed. Native Canvas and layout remain the implementation foundation, adding
no new static-Linux dependency requirement. Existing dependency/toolchain limits
still apply; this assessment does not prove a static executable.

## Proposed responsive instrument tile

**Status:** Design recommendation; no implementation or public API yet. Prove
the fitting contract in a small example before promoting it into the library.

The missing behavior is fitting a complete reading and supporting facts into a
small allocation while giving optional visuals the remaining space. Existing
readouts, gauges, sparklines and group styles already supply the drawing and
chrome. A new component must remove repeated fitting policy, not just rename a
`GroupBox` or collect measurement configuration.

### Candidate API

One passive, unprefixed `InstrumentTile` accepts a label, one complete
application-formatted `reading: String`, essential supporting content, and an
optional visual group. Native view builders keep supplied content composable;
convenience initializers omit empty groups. The visual builder receives an
expanded or compact presentation choice. Proposed call-site shape, uncompiled:

```swift
InstrumentTile("Temperature", reading: "21.4 °C") {
    Text("Within target")
    Text("Recorded mean: 20.8 °C")
    Text("Recorded maximum: 24.8 °C")
} visuals: { presentation in
    switch presentation {
    case .expanded:
        VStack(alignment: .leading, spacing: 0) {
            MeasurementGauge(position: 0.535, style: .dial)
                .frame(height: 5)
            Text("Scale: 0–40 °C")
        }
    case .compact:
        VStack(alignment: .leading, spacing: 0) {
            MeasurementGauge(position: 0.535)
                .frame(height: 1)
            Text("Scale: 0–40 °C")
        }
    }
}
```

Chio styles the label, ordinary reading and supporting group through the theme.
The ordinary reading remains present with visuals. Applications can place a tile
inside a native styled `GroupBox` and compose grids or expanded inspectors;
the tile adds no border, terminal-size breakpoint or collection policy of its own.

Use the reading verbatim: no first-word extraction, numeric parsing, unit joining,
conversion or inferred missing state. Supporting facts remain independent of the
current reading. An unavailable reading can coexist with known recorded values;
a missing gauge position remains distinct from zero. Applications choose whether
status, detail and other facts belong in essential content or optional visuals.
They retain formatting, normalization, thresholds, freshness, priorities, clocks,
sampling and retention. No new measurement DTO, registry or style protocol is
justified by this slice.

### Fitting contract to prove

Try complete expanded content, complete compact content, then essential text
alone. Optional visuals and their captions are admitted as a group, so a gauge
cannot displace its scale label or an essential fact. Enlarging the allocation
must restore the preferred presentation. Long readings and facts use native
wrapping rather than intentional ellipsis; terminal-cell width must not be
approximated with string character counts.

Use native stacks and `ViewThatFits`, not a Chio measurement engine. The pinned
native implementation resolves every candidate, probes ideal dimensions on the
selected axes, and chooses the last candidate even if none fits. Therefore this
is a content-priority contract, not a guarantee that arbitrary text fits any
fixed frame. Establish the essential content's minimum allocation in the spike;
the surrounding application owns extra space or scrolling below that minimum.
Keep supplied content passive and its state/resources above the alternatives.

Give a dial its full five-row allocation in the expanded candidate. An unbounded
Canvas or a nested adaptive visual can give misleading fit results; explicitly
bounded visual candidates must be tested in the complete tile. Ordinary text,
native accessibility and existing group styling remain the foundations.

Optional segmented lettering can be supplied using `InstrumentReadout` inside
the visual group. Its existing plain-text fallback remains intact, including for
unsupported strings; the tile must not parse the ordinary reading or promise
that duplicate plain text is suppressed. Prefer a bar/dial proof first, then
validate a caller-supplied numeric readout without adding another public option.

### Acceptance and delivery

1. Prove a compact grid and an expanded instrument with neutral synthetic data,
   including a non-workout example. Compare full and reduced allocations before
   introducing a public type; preserve existing primitive behavior.
2. Cover missing, zero, negative and large readings, long labels, Unicode units,
   complete supporting groups, and missing current values with known recorded
   facts. Test exact fit boundaries, explicit gauge heights and the minimum
   allocation; do not claim that clipped essential content is a successful fit.
3. Use retained hosted sessions to replace readings, clear optional content, cycle
   themes and shrink/expand repeatedly. Verify no stale pixels, recovered visuals,
   no added focus stops, and accessible full readings without decorative duplicates.
4. Check default, light, btop and custom themes, monochrome and true-color output.
   After implementation, run the required local/platform/terminal gates and update
   the public component example and theme previews through the showcase workflow.

## Proposed target-band gauge

Extend the existing gauge instead of adding a second gauge family. Position and
target are independent: a missing reading can still show a known desired interval.
Applications normalize both against the same scale and own threshold meaning,
out-of-range policy, units and explanatory text. The gauge must not infer that
inside means healthy, rising means good, or the upper bound means completion.

Candidate surface, uncompiled:

```swift
let target = try MeasurementGauge.TargetBand(lowerBound: 0.45, upperBound: 0.60)
MeasurementGauge(position: 0.535, targetBand: target, style: .bar)
    .accessibilityLabel("Temperature: 21.4 degrees Celsius. Target: 18 to 24 degrees.")
```

Retain the exact existing `init(position:style:)`, including initializer references,
its missing-position behavior and its preconditions. Add an overload with a
required `targetBand:` argument accepting the checked value or `nil`. Absence means
no authored band; it does not mean a missing current reading. The existing
initializer delegates to the no-band case. No-band glyphs, dimensions, paint and
accessibility remain unchanged.

`TargetBand` stores one authoritative range with finite endpoints satisfying
`0 <= lower < upper <= 1`. Checked construction takes scalar endpoints so reversed
input can throw a typed validation error before Swift constructs a `ClosedRange`.
Reject zero-width bands: a point target would need its own presentation contract.
Do not clamp, widen or silently remove invalid targets. Membership, when described,
is inclusive at both ends and independent of raster rounding. A valid narrow band
may occupy one cell without changing its stored range.

This restricted value justifies a type; another normalized-position wrapper does
not. Use immutable storage and `Hashable`/`Sendable`. If serialization becomes part
of its public contract, decoding must run the same validation rather than use
synthesis that bypasses construction. Do not change legacy position validation as
incidental cleanup.

The first visual proof should keep the existing bar and add a separate bracketed
target track. That proposes two rows when a band is present and preserves one row
without it; callers and tile candidates must reserve the complete height. For a
dial, test a distinct arc with endpoint marks inside the existing five-row budget.
Both styles need a readable result before publishing an overload that accepts
either style. Do not silently ignore the band on dials or treat clipped tracks as
successful fitting. Ordinary target captions remain available in narrow layouts.

Use existing accent and neutral theme roles. Geometry and text must identify the
target in monochrome. All eight Braille dots in a cell share one foreground;
overlapping needle/band/arc colours cannot remain independent. Native Canvas also
uses its final foreground for unstyled grid writes: changing foreground between
line calls does not paint separate coloured lines. Establish whole-cell paint
precedence if colour is used, then inspect actual rasters and terminal captures.
Keep the existing 512-column drawing limit and bound coordinates before native
line submission; pixel clipping alone does not bound line iteration.

Extend existing raster/semantic tests across missing/zero/one/interior positions
and absent/full/edge/narrow targets. Check invalid endpoints independently,
inclusive boundaries and adjacent floating-point values, widths 0/1/2/3/20/512
and over-limit proposals, bar heights 1/2 and dial heights 1/3/5. Retained tests
must clear and restore targets without stale paint. Preserve passive image
semantics and overrideable labels containing the normalized band; application
labels supply units. A reservoir example with a missing reading and known target
provides a second neutral use.

## Proposed time-aware history

A separate passive `HistoryChart` is justified by proportional time placement,
explicit missing intervals and clipping to an authored time window. `Sparkline`
remains one equally spaced series: inserting uniform slots or resampling into it
would manufacture observations or lose timing. Start with one series, straight
connections and a supplied window; multiple series, smoothing, step/hold plots,
interactive inspection and automatic scrolling remain later questions.

Candidate surface, uncompiled:

```swift
HistoryChart(series, window: window, scale: .fixed(0...500))
    .accessibilityLabel("Service latency in milliseconds over the selected five minutes.")
```

### Supplied values and admission

Recommend an immutable checked `HistorySeries`, nested sample/error vocabulary,
and one shared checked `HistoryInterval` for both the display window and missing
intervals. Reuse standard `Duration` offsets from an application-owned origin.
Require timestamps/endpoints in `0...Duration.seconds(Int64.max)` and strictly
increasing interval endpoints, so differences stay representable. Store one native
range rather than duplicate start/end/duration representations. Applications
translate wall timestamps and format labels; Chio reads no clock. A second `Date`
mode, clock protocol or generic numeric-time abstraction is unnecessary initially.

- Samples have strictly increasing times and finite known values. `nil` is one
  unavailable reading at that time and breaks both adjacent connections; it says
  nothing about the duration of an outage. Empty series is valid.
- Known missing intervals are independent source facts. They use closed endpoints,
  must be ordered and nonoverlapping, and cannot contain known numeric samples.
  Touching closed intervals overlap and are rejected. A nil sample inside a known
  interval remains a valid independent observation.
- Reject duplicate/unordered times, invalid intervals and contradictory known
  readings with typed construction errors. Do not sort, average, pick latest
  arrival, merge intervals or repair caller data. Replacement creates a new checked
  snapshot and leaves the old one unchanged.
- Draw only between adjacent numeric observations whose connecting interval crosses
  no declared missing interval. A missing interval suppresses the whole connection,
  conservatively avoiding invented values on either side. Isolated known points
  remain visible. Blank raster space does not claim exact outage boundaries.
- Wide spacing alone does not declare an outage: connecting eligible points is the
  documented linear interpolation assumption. There is no implicit cadence or
  maximum-gap threshold, and no parallel connection flags or generated run IDs.

The interval type enforces shared foundational restrictions; display window and
outage roles do not justify duplicating it. Prefer `Hashable`/`Sendable` values;
any later Codable contract must validate every sample and enclosing relationship
on decoding. A chart snapshot does not require an application persistence format.

### Window, scale and bounded drawing

The window is explicit and never follows the latest sample or current time by
itself. A lone reading sits at its timestamp, unlike Sparkline's right-aligned
singleton. Clip in time before rasterization, retaining exterior neighbours only
to compute intersections of eligible segments with the window edges. A segment
can cross the entire window even when no sample lies inside it. Do not extrapolate
or clamp every exterior observation to an edge.

Automatic Y scaling uses eligible visible geometry: visible observations and
interpolated window-boundary endpoints. An entirely exterior spike must not flatten
the plot. Empty visible geometry draws nothing; a constant series is centered.
Fixed scaling uses true line/rectangle clipping, not independent endpoint clamping
that changes the line's slope or crossing point.

Reuse `Sparkline.Scale` for `.automatic` and `.fixed` configuration; optionally
expose a type alias at the chart for discoverability. It already represents this
choice. Keep its existing configuration coding and consumption-time validation
unchanged; do not introduce a parallel `PlotScale` or silently turn the existing
enum into a restricted persisted value.

Subtract `Duration` coordinates before converting deltas for plotting, preserving
nearby readings at large offsets. Overflow-safe Y normalization is useful existing
work, but interpolation across opposite extreme finite values and clip crossings
needs separate proof. Bound coordinates before integer conversion and native line
submission. Native Canvas allocates buffers from its allocation, and its line
iteration is not bounded merely by discarding off-screen pixels.

Reduce by time-mapped drawing column within uninterrupted runs, retaining
first/last/minimum/maximum in chronological order and preserving real time positions.
Never connect across a break, even inside one column. Subcolumn gaps can be visually
indistinguishable. Many interrupted runs in one column defeat a simple O(width)
work claim: the proof must establish input, interval, allocation and drawing-work
bounds before promotion. Select and benchmark concrete caps during the spike;
oversized supplied snapshots must fail admission explicitly, while a geometry
budget failure needs an explicit whole-chart unavailable presentation. Do not
silently show truncated or incomplete history as a complete chart. Applications
retain sampling and bounded history ownership.

Use one accent series and native image semantics, with authored axis/unit/time
captions outside the drawing. Default accessibility describes only facts in the
displayed window and distinguishes missing observations from supplied intervals;
the application can replace it with domain language. Do not imply a measurement
at a boundary merely because an interpolated segment crosses it. Multiple coloured
series need a separate collision, legend, shared-scale and monochrome contract.

### Chart proof

Use synthetic service latency at irregular offsets, a failed reading, a known
monitoring outage and a brief spike. Replace the supplied window to demonstrate
navigation without introducing a sampler or playback engine.

Cover validation, unchanged originals after failed replacements, duplicate and
decreasing times, closed-interval boundaries, missing versus zero, constant/empty
series, singleton placement, exterior extrema, whole-window crossings and no
extrapolation. Verify independent expected intersections, large time origins with
tiny deltas, extreme finite Y values, same-column gaps, spikes/troughs and exact/
over-budget limits. Raster tests must assert geometry independently of its helper
algorithm. Retained sessions replace series/window/scale, clear missing intervals,
resize and change themes, preserving surrounding focus and clearing old pixels.
These are acceptance requirements, not performance or rendering results from this
assessment.

## Composition recommendations

**Trend:** use native `Label` or `Text` with authored explanation and a decorative
arrow. Rising/falling/stable/unavailable are distinct; no usable comparison is not
stable or zero. Direction has no inherent good/bad colour. The app chooses the
comparison, time window, deadband, freshness, magnitude and desirability. An arrow
with “Response time falling by 12 ms over the last minute” supplies the meaning
without another public component. Promote an indicator only after repeated use
shows shared fitting/accessibility behavior beyond that composition; no inferred
trend from Sparkline or parsed formatted text.

**Paired/grouped facts:** use native `LabeledContent` (including `.stacked`), stacks,
and the tile if its proof succeeds. A primary reading and recorded statistics,
two independently measured channels, or labelled navigation facts do not require
new DTOs or `InstrumentGroup`. Known supporting values survive a missing current
reading. Test complete facts, long units, missing/zero and side-by-side to stacked
recovery; selection, order and which facts matter remain application choices.

**Responsive collections:** native stacks and `AnyLayout` can change the axis of
one authored child set; lazy horizontal/vertical stacks serve scrollable sets.
The pinned native source does not expose `Grid`, `GridItem`, `LazyVGrid` or
`LazyHGrid`, so SwiftUI grid recipes are not currently native SwiftTUI APIs.
Use small authored rows/stacks first. Reflow, scrolling, paging and primary-only
display are different application policies, not a tile's decision. Regrouping
items into new row parents can change identity even with stable item IDs; hosted
focus/selection checks are required. `AnyLayout` identity tests do not prove every
collection reflow. A later layout helper needs a demonstrated shared contract.

**Playback:** compose native buttons, integer `Slider` for sequence position and
`Stepper` where discrete adjustment helps. SwiftTUI owns their binding/input/focus
and accessibility machinery. Applications own play/pause, allowed seeks, bounds,
speed, clocks, source replacement and end behavior. Sequence position is not
elapsed-time percentage. Keep controls outside passive tile alternatives; test
empty/singleton sources, changing bounds, batched input, disabled controls and
focus across resize. A shared Chio slider/stepper style may be justified by visual
reuse in unrelated controls; preserve native routed track/actions instead of
building a playback component or controller.

**Domain displays and compass:** keep domain-specific instrument combinations in
applications. Independent raw indexes, counts or signed angles do not acquire
physical meaning from similar rendering. A compass needs an explicit north
reference, rotation convention, validated display angle, pointer meaning and
textual equivalent before it becomes a viable generic proposal. No source-angle
normalization or direction inference is implied by this inventory.

## Expansion delivery and verification

1. Build neutral tile/grouped-fact/playback recipes and the tile fitting proof.
   Use compact collections and an expanded instrument. If native composition
   stays clear and removes no repeated policy, retain a recipe instead of a public
   tile. Otherwise promote only the tested passive contract.
2. Prove target-band geometry in bars and dials, including monochrome, then add
   the checked band and compatible gauge overload. Update tile examples for the
   extra band-track height; preserve every no-band regression.
3. Prove timestamp validation, explicit discontinuities, true clipping and work
   bounds in an internal chart before freezing public series/window APIs. Promote
   one series only when the numerical and visual evidence supports it.
4. Reassess trend or native slider/stepper styles from those examples. Keep broader
   collections, multi-series charts and compasses deferred without new evidence.

For each visible slice, show the primitive or style separately from application
compositions on the site and refresh its theme previews and runnable commands.
Use default/light/btop/custom themes, true colour and monochrome captures; check
indexed output without changing capability detection policy. Include exact fit
boundaries, zero/tiny allocations, Unicode, retained clearing and resize recovery.
Measure representative complete hosted compositions, especially repeated fit
candidates and dense chart inputs; a bounded pure algorithm is not an SSH latency
or whole-frame performance result.

Run the [required gates](../Verification.md) for implemented behavior: pinned
engineering checks, applicable model/raster/hosted tests, macOS/Linux, release
terminal workflows and affected showcase deployment/inspection. Existing native
runtime follow-ups remain separate; this design neither adopts an upstream patch
nor changes the dependency pin. No new component has been rendered or platform
qualified by this documentation-only assessment.

### Assessment evidence

- [Gauge and its current bounds](../../Sources/Chio/Instrumentation/Presentation/MeasurementGauge.swift), [raster/semantic regressions](../../Tests/ChioTests/Instrumentation/Presentation/MeasurementGaugeTests.swift).
- [Index-spaced Sparkline and reduction](../../Sources/Chio/Instrumentation/Presentation/Sparkline.swift), [gap/extreme-value tests](../../Tests/ChioTests/Instrumentation/Presentation/SparklineTests.swift).
- [Native Canvas colour and coordinate contract](https://github.com/SwiftTUI/swift-tui/blob/2d84ac7083993da2ef52e9d3d30255467efb9553/Sources/SwiftTUIPrimitives/Draw/CanvasDrawing.swift), [line iteration](https://github.com/SwiftTUI/swift-tui/blob/2d84ac7083993da2ef52e9d3d30255467efb9553/Sources/SwiftTUIPrimitives/Draw/CanvasGrid.swift).
- [Native candidate resolution](https://github.com/SwiftTUI/swift-tui/blob/2d84ac7083993da2ef52e9d3d30255467efb9553/Sources/SwiftTUIViews/GeometryReading/ViewThatFits.swift), [ideal fit and fallback selection](https://github.com/SwiftTUI/swift-tui/blob/2d84ac7083993da2ef52e9d3d30255467efb9553/Sources/SwiftTUICore/Measure/LayoutEngine%2BMeasurementWorkStack.swift).
- [Native labelled facts](https://github.com/SwiftTUI/swift-tui/blob/2d84ac7083993da2ef52e9d3d30255467efb9553/Sources/SwiftTUIViews/Primitives/LabeledContentStyles.swift), [slider bindings](https://github.com/SwiftTUI/swift-tui/blob/2d84ac7083993da2ef52e9d3d30255467efb9553/Sources/SwiftTUIViews/Controls/Slider.swift).

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
