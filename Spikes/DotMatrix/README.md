# Dot matrix visual study

An internal experiment for a passive LED-like display. This is not public Chio API.
Lettering and a four-frame icon share one immutable frame type and native Canvas
presentation. The view owns no clock, playback, input or external resource.

```sh
swift run -c release DotMatrixPreview
```

Space plays or pauses, Right advances one frame, `t` switches amber/green lettering,
`s` changes round/square dots, and `q` quits. The example owns these actions and its
300 ms animation task. It starts paused for repeatable inspection.

Each logical LED occupies its own terminal cell, with a blank column between LEDs.
This approximates square pitch with terminal cells twice as tall as they are wide;
actual glyph shape and proportions depend on the terminal font. Lit dots keep their
supplied color. Unlit dots use a smaller glyph and the supplied inactive color, so
their distinction does not rely on color alone. Braille packing is not used.

Frames must be rectangular, 1–64 dots wide and 1–32 dots high. Construction and
decoding validate those bounds. Work per draw is bounded by 2,048 logical LEDs.
The complete grid keeps its pitch and proportions across resizing; it does not
stretch or silently crop. If it does not fit, native text shows the authored label.
Applications supply a meaningful label, including for icons.

`MatrixLettering` is a small fixture font for CHIO, digits and colon. It admits
1–10 characters and rejects unsupported text. It is not a general font, localization
or user-facing error policy. The separate launcher keeps `@main` out of test imports.

## Verification

```sh
swift test -c release --filter 'DotMatrix'
python3 -B Spikes/DotMatrix/Scripts/capture.py .build/release/DotMatrixPreview \
  --output .build/dot-matrix-captures
```

Tests cover invalid construction/decoding, independently expected lettering,
per-dot colors, style changes, fixed dimensions, exact fitting, text fallback and
passive accessibility. The PTY probe checks actual updates, palette/shape changes,
animation, narrow/tiny/wide resizing, clean exit and terminal restoration.
Generated captures remain outside tracked sources. The existing vendored player
renders previews from the recorded terminal output; see the capture script's help.
Results and public API decisions remain in [Plan](../../Docs/Plan.md).

Candidate API: a frame view for arbitrary dot imagery; dot-matrix numeric lettering
could later become an `InstrumentReadout` style. Promotion requires visual review.

## Findings — 2026-10-23

Actual PTY output, replayed through the vendored asciinema player, makes both round
and square dots readable at 80 × 32 cells. Round amber dots give the clearest LED
sign treatment; green squares read as pixel art. The heart retains separate pink
and warm highlight colors without the shared foreground limitation of Braille.
These are font-dependent presentation observations, not terminal-independent guarantees.

The complete lettering needs 45 × 7 terminal cells. At 36 × 24, the lettering falls
back to text while the heart remains a full 8 × 8 image. At 24 × 14, the example
allocates one row to each matrix so both use authored text. It keeps the current
frame caption and controls visible. The application owns these layout priorities;
the matrix only chooses between a complete grid and its label.

The real PTY probe passes stepping, animation, palette and shape changes, all three
allocations, exact paused-frame recovery after resizing, clean exit, and terminal
mode/cursor restoration. Rendering tests cover individual colors and fitting.
The preview is from macOS terminal output in a browser player, not a screenshot of
Blink or Ghostty. Linux, SSH, arbitrary fonts, and allocations below 24 × 14 remain
outside this visual qualification.

The reusable part is the fixed grid, supplied colors, passive semantic label and
fitting policy shared by text and imagery. The fixture font and playback controls
remain example code. Public API promotion and a numeric `InstrumentReadout` style
remain separate decisions; this prototype adds neither to the package's library.
