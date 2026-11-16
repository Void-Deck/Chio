# Waveform visual study

Start from the repository root:

```sh
swift run -c release WaveformStudy --theme btop --window 2m --start 00:30
swift run -c release WaveformStudy --window 10m --start 00:30 --compare
swift run -c release WaveformStudy --window 8h --capture --width 120 --height 34 > /tmp/waveform.json
```

This is a spike, **not a public component** or an accepted waveform contract.
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
  A window wholly inside mask-off has no braille and intentionally times out.

Left/right arrows pan by one quarter window. `+` zooms in, `-` zooms out through
these five windows, retaining the center when possible. `t` cycles themes, `c`
toggles comparison, and `q` quits. SwiftTUI owns the terminal and input lifecycle.
The spike owns all window/theme state. Use at least 80×24 for interactive study;
compare is easiest at 120×34 or wider.

## Animated captures

Capture a pan sequence and render its native raster frames with Pillow:

```sh
swift run -c release WaveformStudy --capture --capture-sequence pan --width 100 --height 30 > pan.json
python3 Scripts/docs/render-raster.py pan.json pan.png
swift run -c release WaveformStudy --capture --capture-sequence zoom --theme btop --width 100 --height 30 > zoom.json
python3 Scripts/docs/render-raster.py zoom.json zoom.gif
```

`--capture-sequence pan|zoom` requires `--capture`. Pan starts at the chosen
`--start` and `--window`, sends real right-arrow keys, and reverses with left-arrow
keys at session boundaries. `--frames N` controls pan's total frame count
(default 24, range 1–240). A whole-night pan cannot move: it still sends the key
and requests a fresh hosted frame. A pan window wholly inside mask-off times out
under the same nonblank-braille readiness rule as still capture.

Zoom always starts at 8h, sends real `+` keys through 1h, 10m, 2m and 30s,
and repeats the final captured image four extra times: nine frames in total.
For this sequence, `--start` supplies the retained zoom center rather than the
left edge. `--start 01:10` produces 22:31–06:31, 00:40–01:40, 01:05–01:15,
01:09:00–01:11:00 and 01:09:45–01:10:15. Wide windows fit inside session bounds
without discarding the intended center for later zooms. `--window` is ignored
for zoom sequences; `--frames` applies only to pan. Interactive `+`/`-` uses the
same retained center; a pan establishes a new center from its fitted window.

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

## Drawing choices and API assumptions

`StudyWaveform` uses public `Canvas` and `CanvasDrawing`, with `.braille2x4`.
`gridSize` counts dots; `Point` uses cell units, so dot coordinates divide by
2 horizontally and 4 vertically. It reduces only the visible index range,
without copying the whole night. Each dot column gets its minimum/maximum;
sub-sample columns consult neighbouring samples clipped to the visible window.
All-gap columns draw nothing. Partially missing columns retain known extrema;
subcolumn gaps can disappear at overview scale.

Flow uses fixed −60…+60 scaling and every known column includes the zero dot row.
The `0 ┤` caption and sparse muted zero-row ticks identify the axis. Braille has
one foreground per terminal cell: a tick tints the whole cell it shares with
flow. Pressure draws its min/max span with fixed 4…14 bounds; it does not fill
down to the lower bound. Event labels align with the flow plot's time columns;
earlier labels win collisions at overview density, and zoom exposes more labels.
Mask-off gets a muted label when space permits. The one-row whole-night strip
shows the current bracket and leaves a break for mask-off.

HistoryChart admission allows 16,384 samples. Comparison constructs a series only
from the visible range, taking every Nth sample when necessary, where
N = ceil(visible count / 16,384). The title reports N; 2m and 30s retain all
samples. The stride selects observations, not extrema, so narrow spikes can be
lost. Timestamps retain their original 40 ms positions relative to window start;
`nil` stays missing. No extrapolated endpoint is appended. Both plots use fixed
−60…+60 bounds. HistoryChart's own drawing-work/allocation rejection remains
visible, rather than being hidden by a fallback. Side-by-side panels have their
own native layout, so their plot widths may differ slightly due to axis captions.

## Verification handoff

The coordinator reports that the initial spike builds cleanly in release and
single-frame captures and the shared renderer work. The first sequence version
timed out at frame 2 because the study had no native focus region. The subsequent
focus, short-window clock and zoom-center corrections require coordinator runtime
verification. Parser checks and the documentation gate pass. All spike files
typecheck against the existing release modules. A supplementary domain smoke
check passes the requested zoom ranges, seconds labels, quarter-window pan and
center recovery after session-edge clamping; it does not exercise native input.

Earlier sandbox build attempts stopped at SwiftPM sandbox setup; the rules gate
verified all 35 vendored file hashes, then failed on a denied module-cache write.
The coordinator must build the sequence changes, inspect APNG/GIF and still
previews, and exercise keys, resize and terminal restoration. Hosted animation
playback does not prove real terminal input or appearance. No public library
behavior or proposal contract is changed.
