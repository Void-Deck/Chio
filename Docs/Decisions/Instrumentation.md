# Compact instrumentation and duration display

**Status:** Accepted presentation contracts. Compact styles, `Sparkline` and plain
`DurationText` shipped in 0.1.0; measurement gauges and segmented readouts extend
those contracts and have not yet been included in a tagged release.
The responsive instrument tile below is a proposal, not an available API.

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

Target bands, trend indicators and timestamped history remain separate proposals.
Existing sparklines describe equally spaced slots and must not silently acquire
irregular-time semantics. Paired facts, navigation displays and collection layout
remain application compositions until a separate shared contract is demonstrated.

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
