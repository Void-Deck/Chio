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

- **Samples.** A checked, immutable fixed-rate series: a start offset (`Duration`),
  a positive sample rate, and finite values, with `nil` for gaps. Construction
  and decoding reject a non-finite value, a non-positive rate or an offset outside
  the `Duration` range that `HistoryChart` uses. A gap is never zero.
- **Window.** The application supplies the visible window as a `HistoryInterval`.
  It owns panning and zooming, and the view starts no timers or input handling.
- **Reduction.** Chio reduces the samples behind each braille dot column to their
  minimum and maximum. A column with no known sample draws as a gap. When a column
  covers less than one sample, the view uses the neighbouring samples, so the trace
  stays continuous at high zoom.
- **Style.** `bipolar` mirrors the envelope around zero, and is used for flow.
  `magnitude` draws from the lower bound, and is used for pressure. Scale reuses
  `Sparkline.Scale` (`.fixed` or `.automatic`). Colors come from the inherited
  `ChioStyle`; the trace uses the accent, and gaps use muted text.
- **Event bands.** Optional application-supplied time ranges, each with a short
  label and a semantic tone. Labels always carry the meaning; color only
  reinforces it. Chio doesn't decode or classify events.
- **Accessibility.** The view exposes a text summary: window, value range and the
  number of gaps and events.

## Boundaries

Chio performs no clinical interpretation: no AHI, no thresholds and no
classification of readings, as with `MeasurementGauge`. Fixtures, tests and
recordings are synthetic, because Chio is public. Pneuma owns collection,
storage, clocks, sample timing and event decoding. The view is passive, like
`DotMatrix` and `HistoryChart`.

## Open questions

- Should a playhead or cursor marker be part of the view, or application
  composition?
- Does one view draw several aligned traces, or does the application stack
  several views that share a window?
- What bounds apply to sample counts and window length, to keep reduction cost
  bounded?

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
