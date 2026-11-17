# Waveform

**Status:** Proposal, not accepted. The user approved drafting this contract and a
visual mock-up on 2026-11-16, with Pneuma's CPAP nights as the consumer. Nothing
here changes a shipped contract until the user accepts it. [Plan](../Plan.md)
records delivery status.

## Need

Pneuma records a ResMed AirMini's diagnostic blower flow and pressure at 25 Hz.
An eight-hour night is about 720,000 samples for each signal. A terminal shows
80 to 120 columns, so each column summarizes thousands of samples. `Sparkline`
draws one value per slot, and `HistoryChart` draws observations within a time
window; neither reduces dense samples or draws a signed signal around zero.
Every application that plots such data would otherwise rebuild the same
reduction. Slow signals, such as one-minute leak, remain `HistoryChart` content.

## Proposed contract

Owner decisions on 2026-11-16 settle the reduction and the scale ownership.
The other rules below are the coordinator's proposal and await acceptance.

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
- **Style.** `.bipolar` draws around zero and requires zero inside the scale; it
  draws a muted zero axis. `.magnitude` draws upwards from the scale's lower bound.
  Colors come from the inherited `ChioStyle`: the trace uses the accent, and the
  axis and gaps use muted text.
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

## Boundaries

Chio performs no clinical interpretation: no AHI, no thresholds and no
classification of readings, as with `MeasurementGauge`. Fixtures, tests and
recordings are synthetic, because Chio is public. Pneuma owns collection,
storage, clocks, sample timing, event decoding and any trend calculation. The
view is passive, like `DotMatrix` and `HistoryChart`.

## Evidence so far

The isolated [Waveform study spike](../../Spikes/Waveform/README.md) renders a
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
