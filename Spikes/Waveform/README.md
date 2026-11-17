# Waveform visual study

Start from the repository root:

```sh
swift run -c release WaveformStudy --theme btop --window 2m --start 00:30
swift run -c release WaveformStudy --window 10m --start 00:30 --compare
swift run -c release WaveformStudy --window 8h --capture --width 120 --height 34 > /tmp/waveform.json
```

This study composes the public `Waveform` under its [accepted contract](../../Docs/Decisions/Waveform.md).
Axes, event counts, window state and capture sequences remain application-owned.
The overview uses one magnitude plot row plus the public event row.
All data is synthetic: a fixed-seed eight-hour night starting at 22:31 on
15 November, sampled at 25 Hz (720,000 readings per signal). Positive flow is
inspiration. Synthetic OA, H, CA and FL events modify the flow; they do not
represent clinical interpretation. Pressure has slow APAP-like drift and breath
ripple, bounded to 4–14 cmH₂O. Mask-off is 02:31–02:36: both arrays contain `nil`,
never substituted zeroes. No file, network, device or private recording is read.

## Flags and keys

- `--theme default|light|btop` (default `default`).
- `--window 8h|1h|10m|2m|30s` (default `2m`).
- `--start HH:MM` (default `00:30`), inside the overnight session. A window that
  would exceed session end moves back to fit; the header shows the actual range.
  Windows shorter than ten minutes show seconds in both clock labels.
- `--compare` draws the same visible flow window beside public `HistoryChart`.
- `--capture --width N --height N` exports actual hosted raster pixels as JSON:
  rows of `{character, foreground, background}`. Colors use SwiftTUI's Color
  encoding. Capture dimensions are bounded to 60–240 columns and 24–100 rows;
  defaults are 120×34. It waits up to ten seconds for a correctly sized frame
  containing the header and nonblank braille, then stops and joins the session.
  A window wholly inside mask-off leaves the main trace blank; the overview still supplies braille.

Left/right arrows pan by one quarter window. `+` zooms in, `-` zooms out through
these five windows, retaining the center when possible. `t` cycles themes, `c`
toggles comparison, `e` steps through the event study, and `q` quits. SwiftTUI owns the terminal and input lifecycle.
The spike owns all window/theme state. Use at least 80×24 for interactive study;
compare is easiest at 120×34 or wider.

## Animated captures

Capture a pan sequence and render its native raster frames with Pillow:

```sh
swift run -c release WaveformStudy --capture --capture-sequence pan --width 100 --height 30 > pan.json
python3 Scripts/docs/render-raster.py pan.json pan.png
swift run -c release WaveformStudy --capture --capture-sequence zoom --theme btop --width 100 --height 30 > zoom.json
python3 Scripts/docs/render-raster.py zoom.json zoom.gif
swift run -c release WaveformStudy --capture --capture-sequence events --theme btop --width 100 --height 30 > events.json
python3 Scripts/docs/render-raster.py events.json events.png
```

`--capture-sequence pan|zoom|events` requires `--capture`. Pan starts at the chosen
`--start` and `--window`, sends real right-arrow keys, and reverses with left-arrow
keys at session boundaries. `--frames N` controls pan's total frame count
(default 24, range 1–240). A whole-night pan cannot move: it still sends the key
and requests a fresh hosted frame. A pan window wholly inside mask-off leaves the main plot blank while the
whole-night overview remains visible.

Zoom always starts at 8h, sends real `+` keys through 1h, 10m, 2m and 30s,
and repeats the final captured image four extra times: nine frames in total.
For this sequence, `--start` supplies the retained zoom center rather than the
left edge. `--start 01:10` produces 22:31–06:31, 00:40–01:40, 01:05–01:15,
01:09:00–01:11:00 and 01:09:45–01:10:15. Wide windows fit inside session bounds
without discarding the intended center for later zooms. `--window` is ignored
for zoom sequences; `--frames` applies only to pan. Interactive `+`/`-` uses the
same retained center; a pan establishes a new center from its fitted window.

Events captures three distinct views: 8h, the densest 10m cluster, then 2m
centered on that cluster's median event (upper median when even). Density counts
supplied event starts in a ten-minute window; the earliest window wins ties.
Each captured view occupies four playback frames, for twelve JSON frames total.
The same real hosted `e` key used interactively advances the views. `--start`,
`--window` and `--frames` do not select event-study windows. No event is inferred
from flow or pressure.

`--delay-ms N` sets the exported delay on each frame (default 250, range
1–60000 ms). Capture runs at hosted rendering speed; the delay controls playback,
not sleeps between keys. Each changed window must deliver a newer frame with
its expected clock/window header, the study header, braille and native study
focus within ten seconds. The study content is a native focusable region with
default focus for hosted and terminal key routing. A timeout reports the frame
number and expected header. The session is stopped and joined on success or
failure.

Sequence JSON is `{"frames": [{"delayMS": 250, "cells": [...rows...]}, …]}`.
The shared renderer also accepts the original single-raster JSON. `.png` writes
a still or lossless APNG; `.gif` writes looping animation with quantized colors
and GIF's coarser timing precision. Pillow may merge identical held frames while
preserving their total duration. Default Menlo/Apple Symbols font paths are for
macOS; use `--font` and `--symbol-font` elsewhere. Cell dimensions remain explicit
(`--cell-width 12 --cell-height 24`). These are native SwiftTUI raster previews,
not screenshots of an emulator.

## Drawing and ownership

The study draws through public `Waveform`; its [source guide](../../Sources/Chio/Waveform/README.md)
and [accepted decision](../../Docs/Decisions/Waveform.md) own reduction, scale,
axis, event placement, accessibility and unavailable behavior. No drawing code is
shared with `HistoryChart` or `Sparkline`.

Flow uses fixed −40…+40 L/min bipolar scaling. Pressure uses a magnitude plot:
the application computes visible known extrema with 0.5 cmH₂O padding rounded
outwards for its axis captions and supplies the same automatic rule to the public
view. Both use the inclusive visible window. All-missing pressure reports no known
samples. Magnitude plots fill to the lower bound.

The application counts supplied OA, CA, H and FL labels. An empty window says
`no events`; mask-off remains named in the heading. These counts imply no
clinical interpretation. Public `Waveform` places event labels and markers.

The overview uses checked absolute flow computed once for the synthetic night,
fixed 0…40 magnitude scaling, and the supplied events. Its two terminal rows
hold one event row and one plot row. Brackets overlay the visible window endpoints;
subcell windows use a single vertical marker. Missing samples remain gaps at the
public view's dot-column resolution.

HistoryChart admission allows 16,384 samples. Comparison constructs a series only
from the visible range, taking every Nth sample when necessary, where
N = ceil(visible count / 16,384). The title reports N; 2m and 30s retain all
samples. The stride selects observations, not extrema, so narrow spikes can be
lost. Timestamps retain their original 40 ms positions relative to window start;
`nil` stays missing. No extrapolated endpoint is appended. Both plots use fixed
−40…+40 bounds. HistoryChart's own drawing-work/allocation rejection remains
visible, rather than being hidden by a fallback. Side-by-side panels have their
own native layout, so their plot widths may differ slightly due to axis captions.

## Evidence

The original study motivated the accepted contract. This candidate migrates its
hosted capture and real-key pan, zoom and event sequences to public `Waveform`.
The separate-author spec suites provide contract evidence:
[sample validation](../../Tests/ChioTests/Waveform/Domain/WaveformSamplesSpecTests.swift),
[scale validation](../../Tests/ChioTests/Waveform/Domain/WaveformScaleSpecTests.swift),
[event validation](../../Tests/ChioTests/Waveform/Domain/WaveformEventSpecTests.swift),
[public rendering](../../Tests/ChioTests/Waveform/Presentation/WaveformSpecTests.swift) and
[clarified drawing rules](../../Tests/ChioTests/Waveform/Presentation/WaveformClarificationSpecTests.swift).

[Supplementary implementer tests](../../Tests/ChioTests/Waveform/Presentation/WaveformRenderingTests.swift)
exercise internal reduction and public rendering through the maximum sample count.
See [Verification](../../Docs/Verification.md) for repository and platform gates.
A hosted capture does not establish real-terminal, Linux or live-device behavior.
