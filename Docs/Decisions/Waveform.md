# Waveform

**Status:** Accepted by the user on 2026-11-16, with Pneuma's CPAP nights as the
consumer. The public view was delivered in PR #40; [Plan](../Plan.md) records
example and showcase delivery status.

## Need

Pneuma records a ResMed AirMini's diagnostic blower flow and pressure at 25 Hz.
An eight-hour night is about 720,000 samples for each signal. A terminal shows
80 to 120 columns, so each column summarizes thousands of samples. `Sparkline`
draws one value per slot, and `HistoryChart` draws observations within a time
window; neither reduces dense samples or draws a signed signal around zero.
Every application that plots such data would otherwise rebuild the same
reduction. Slow signals, such as one-minute leak, remain `HistoryChart` content.

## Contract

- **Samples.** `WaveformSamples` is a checked, immutable fixed-rate series. It
  holds a start offset (`Duration`), a positive finite sample rate in hertz and
  values of type `Double?`, where `nil` marks a gap. A gap never reads as zero.
  The throwing initializer reports a typed error for a non-finite value, a
  non-positive or non-finite rate, an offset outside the range that
  `HistoryInterval` admits, an empty series or more than 2,097,152 samples
  (about 23 hours at 25 Hz). The view takes only a checked series, so it has no
  runtime failure path.
- **Window.** The application supplies the visible window as a `HistoryInterval`.
  It owns panning, zooming and any cursor. The view is passive: it starts no
  timers and handles no input.
- **Reduction.** Every braille dot column draws the minimum and maximum of the
  known samples it covers, at every zoom level. The view never substitutes a
  trend or an average. An application that wants a coarse trend computes it and
  draws it as a second, lower-rate `Waveform`. A column with no known sample draws
  as a gap. A column that covers less than one sample interval uses the two
  neighbouring known samples, so the trace stays continuous at high zoom; it does
  not join across a gap. Reduction reads only the samples inside the window.
- **Scale.** The application chooses the vertical scale for each view, and there is
  no default:
  - `.fixed(lower:upper:)` takes finite bounds with the lower below the upper;
    its throwing factory rejects anything else.
  - `.automatic(padding:)` uses the minimum and maximum known samples inside the
    window, ignores gaps, adds the non-negative finite padding on both sides and
    rounds each bound outwards to a whole unit. A constant window is centred
    within one unit of padding. A window with no known sample draws only gaps.
  `Waveform` owns this type; it doesn't reuse `Sparkline.Scale`.
- **Mode.** `.bipolar` draws around zero and requires zero inside the scale; it
  draws a muted zero axis. `.magnitude` draws upwards from the scale's lower bound.
  Colors come from the inherited `ChioStyle`: the trace uses the accent, and the
  axis uses muted text. Gaps draw nothing.
- **Traces.** One view draws one trace. Applications stack views that share one
  `HistoryInterval` to align several signals, as the study does with flow and
  pressure.
- **Event bands.** Optional application-supplied ranges, at most 4,096, each with a
  start, a duration, a short label and a semantic tone (`.muted`, `.warning` or
  `.error`). The view draws a label at its start column only when the label fits
  without touching the neighbouring labels, with one blank cell between them.
  Otherwise it draws a `▾` marker, and markers in one column merge to the most
  severe tone. Labels always carry the meaning; color only reinforces it. Chio
  doesn't decode, count or classify events. Summaries such as counts are
  application composition.
- **Limits.** As with `HistoryChart`, a proposal above 512 columns or 64 rows
  replaces the whole plot with an explicit unavailable message. The view never
  silently clips or rescales.
- **Accessibility.** The view exposes a text summary: the window, the visible value
  range, the number of gaps and the number and labels of the visible events.

## Public interface

All types are in the `Chio` library, under `Sources/Chio/Waveform`. Domain types
are `Hashable` and `Sendable`, and their validation errors conform to `Error`.

```swift
public struct WaveformSamples {
    public static let maximumCount = 2_097_152
    public let start: Duration          // offset of values[0]
    public let rate: Double             // samples per second
    public let values: [Double?]        // nil marks a gap
    public enum ValidationError { case startOutOfRange, endOutOfRange, invalidRate, empty, tooManySamples, nonFiniteValue(index: Int) }
    public init(start: Duration, rate: Double, values: [Double?]) throws(ValidationError)
}

public struct WaveformScale {
    public enum ValidationError { case nonFiniteBound, nonIncreasingBounds, invalidPadding }
    public static func fixed(lower: Double, upper: Double) throws(ValidationError) -> WaveformScale
    public static func automatic(padding: Double) throws(ValidationError) -> WaveformScale
}

public enum WaveformMode { case bipolar, magnitude }

public struct WaveformEvent {
    public static let maximumLabelLength = 16
    public enum Tone: CaseIterable { case muted, warning, error }
    public let start: Duration
    public let duration: Duration
    public let label: String
    public let tone: Tone
    public enum ValidationError { case startOutOfRange, nonPositiveDuration, emptyLabel, invalidLabel }
    public init(start: Duration, duration: Duration, label: String, tone: Tone) throws(ValidationError)
}

@MainActor public struct Waveform: View {
    public static let maximumEvents = 4_096
    public init(_ samples: WaveformSamples, window: HistoryInterval, scale: WaveformScale,
                mode: WaveformMode, events: [WaveformEvent] = [])
}
```

### Validation

- `WaveformSamples` checks in this order. `startOutOfRange`: `start` is below zero or
  above `Duration.seconds(Int64.max)`. `invalidRate`: the rate is not finite or
  not above zero. `empty`: no values. `tooManySamples`: more than `maximumCount`.
  `endOutOfRange`: the last sample's offset, `start + (count − 1) / rate`, exceeds
  `Duration.seconds(Int64.max)`. `nonFiniteValue(index:)`: the first non-finite
  value. Sample `k` sits at offset `start + k / rate`.
- `WaveformScale.fixed` throws `nonFiniteBound` for a non-finite bound, then
  `nonIncreasingBounds` unless `lower < upper`. `automatic` throws `invalidPadding`
  unless the padding is finite and at least zero.
- `WaveformEvent` throws `startOutOfRange` under the same bounds as samples, then
  `nonPositiveDuration`, then `emptyLabel` for an empty label, then `invalidLabel`
  for more than `maximumLabelLength` characters, or for any scalar in
  `CharacterSet.newlines` or `CharacterSet.controlCharacters` (Unicode Cc and Cf). An event covers `start..<start + duration`.

### Layout and drawing

- When `events` is not empty, the top row is the event row and the plot uses the
  remaining rows. Otherwise the plot uses every row. The plot is a braille canvas
  with two dot columns and four dot rows per cell.
- Dot column `i` of `W` covers window time `[s + i·(e−s)/W, s + (i+1)·(e−s)/W)`,
  and the last column also includes `e`. A sample belongs to the column that
  contains its offset.
- A column with known samples spans their minimum and maximum. A column with no
  sample, between two adjacent known samples `k` and `k+1`, spans the values
  linearly interpolated at the column's start and end times. Both neighbours must
  lie inside the window. Any other column is a gap and draws nothing.
- Automatic bounds: `lower = floor(min − padding)` and `upper = ceil(max +
  padding)`, over known samples inside the window. In `.bipolar` mode they then
  extend to include zero. If `lower == upper`, they become `lower − 1` and
  `upper + 1`. With no known sample in the window, `.bipolar` uses `-1...1` and
  draws only the axis, and `.magnitude` draws nothing. A fixed bound equal to zero
  counts as including zero.
- Value `v` maps to dot row `round((upper − v) / (upper − lower) · (H − 1))`,
  rounding halves away from zero,
  clamped to `0...H−1`, where row zero is the top. Fixed-scale values outside the
  bounds therefore draw on the edge row.
- `.bipolar` fills each column from its minimum row to its maximum row and draws
  the zero row across every column, gaps included, in muted text. A cell holding
  both trace and axis dots keeps both and takes the accent. `.magnitude` fills each column from the bottom dot row up to its
  maximum's row. The trace uses the style's accent.
- An event is visible when its range intersects the window. Its anchor cell is
  `max(0, floor((start − s) / (e − s) · width))`, limited to the last cell. Visible events are processed in
  order of start time, then input order. A label occupies `label.count` cells
  from its anchor. It is drawn only when it ends at or before the row's end,
  starts at least two cells after the previous occupied cell, and leaves at least
  one blank cell before the next visible event's anchor. Otherwise the event draws
  `▾` at its anchor. A marker in an already occupied marker cell keeps the more
  severe tone: error, then warning, then muted. Tones use the style's
  `mutedText`, `warning` and `error` colors.

### Unavailable states

The whole view is replaced by one line of text, which is also its accessibility
label. The first matching condition applies, in this order:
- the size exceeds 512 columns or 64 rows: `Waveform unavailable: allocation limit exceeded.`
- there are more than `maximumEvents` events: `Waveform unavailable: event limit exceeded.`
- `.bipolar` uses a fixed scale whose bounds exclude zero: `Waveform unavailable: zero is outside the fixed scale.`

### Accessibility

The label reads `Waveform: K known samples, G gaps in window.` K counts known
samples whose offsets lie in the window. G counts maximal runs of `nil` samples
with at least one offset in the window. When K is above zero, ` Minimum: MIN.
Maximum: MAX.` follows, using Swift's default `Double` description. Then
` Events: N.` follows, with N the number of visible events; when N is above zero,
the labels follow in drawing order inside parentheses, separated by `, `,
before the full stop, as in ` Events: 2 (OA, CA).`

## Boundaries

Chio performs no clinical interpretation: no AHI, no thresholds and no
classification of readings, as with `MeasurementGauge`. Fixtures, tests and
recordings are synthetic, because Chio is public. Pneuma owns collection,
storage, clocks, sample timing, event decoding and any trend calculation. The
view is passive, like `DotMatrix` and `HistoryChart`.

## Evidence so far

The isolated Waveform study, since promoted to the [standalone example](../../Examples/Waveform/README.md), rendered a
synthetic eight-hour, 25 Hz night through native SwiftTUI and Chio styles. Hosted
captures, rendered with `Scripts/docs/render-raster.py` and including animated
pan and zoom sequences driven by real key events, show the following:

- At 30 seconds and 2 minutes, single breaths and the zero crossing read clearly
  in both the btop and light themes.
- At 8 hours, each column covers about 160 seconds, and flow becomes an amplitude
  band. The mask-off gap remains a clean break.
- Event labels collide in wide windows, so a placement rule is needed.
- The whole-night overview strip summarizes no amplitude or events.
- Pressure's breath ripple isn't visible on a 4–14 cmH₂O scale.
- On the same window, the existing `HistoryChart` differs mainly by vertical holes,
  where individual observations miss braille columns.

## Waveform stays separate from HistoryChart

The user decided on 2026-11-16 to develop `Waveform` as a standalone view.
`HistoryChart` remains unchanged, and the two share no implementation for now.
`HistoryChart` models irregular observations with per-sample offsets, admits
16,384 samples and draws one history. A CPAP night is a fixed-rate series of
about 720,000 samples, with a signed zero axis and event bands. Reusing
`HistoryChart` would need a rename and a more general design. Revisit
generalization only when a second concrete use case needs both shapes.
