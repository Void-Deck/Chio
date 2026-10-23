# Dot matrix display

Accepted for public promotion on 2026-10-23 after the isolated visual study.
`DotMatrix` presents application-supplied RGB and intensity frames through native
SwiftTUI Canvas. The [source guide](../../Sources/Chio/DotMatrix/README.md) owns
entry points and examples; [Plan](../Plan.md) records delivery status.

## Frame and presentation

`DotMatrixFrame` retains a rectangular `[[SIMD4<Float>]]`. Each vector contains
red, green, blue and intensity, in that order. Every channel must be finite and
within `0...1`. Construction and decoding reject empty, ragged, oversized or
invalid-channel input. The frame is immutable, hashable, sendable and codable.
There is no per-pixel enum or parallel color representation in the public model.

Intensity scales the supplied RGB channels for terminal output. It is not alpha,
physical luminance or hardware calibration. Zero intensity and black RGB both
produce an inactive dot. The original frame retains all supplied values. A theme
does not recolor supplied imagery.

One logical LED occupies one terminal cell. This preserves independent colors;
packing multiple LEDs into Braille would share one foreground color per cell.
The default round glyph and one blank horizontal cell approximate square pitch
with common tall terminal cells. Actual proportions depend on the terminal font.

`DotMatrixStyle` supplies round or square lit glyphs, horizontal/vertical gaps and
an optional unlit color override. Gaps count blank terminal cells and are checked
within `0...8`. An omitted unlit color inherits `ChioStyle.colors.mutedText`.
The `.dotMatrixStyle(...)` modifier installs an inherited value, with the nearest
complete style taking precedence. It changes presentation without changing RGB,
intensity, logical dimensions, the label or animation ownership.

## Sizing and bounded work

The application chooses the number of rows and columns. A frame permits up to
65,536 LEDs; this replaces the study's 64 × 32 cap. Spacing changes the required
terminal extent:

- width = columns + (columns − 1) × horizontalGap
- height = rows + (rows − 1) × verticalGap

The view admits at most 262,144 terminal cells, including gaps, before creating
its canvas. Over-budget layouts show the authored text label. These are explicit
resource limits, not claims about terminal resolution or refresh performance.
They bound retained frame work and the component's surface; they do not bound
caller allocations or an arbitrarily large parent surface.

The matrix retains fixed pitch. If the complete grid does not fit the layout
proposal, native `ViewThatFits` presents the required authored label. The view
does not crop, stretch or choose a lossy reduction. An application that wants a
viewport composes a fixed-size matrix inside a native `ScrollView`; SwiftTUI owns
scroll offsets, focus and input. Accessibility exposes the authored label once.

## Ownership

The component is passive: it owns no timer, task, changing state, focus or resource.
Applications own frame production, animation cadence, content meaning and viewport
policy. The example's tiny lettering fixture, playback and controls remain under
`Examples/DotMatrix`. A font API, marquee engine, hardware simulator integration
and InstrumentReadout presentation are separate work.

The study established readable round/square lettering and multicolor icon frames
in actual macOS terminal output replayed by the vendored player. The public slice
adds RGB/intensity, spacing and native viewport qualification. See
[verification](../Verification.md#dot-matrix) for required evidence. Terminal
captures do not establish physical LED color accuracy, every font, or SSH latency.
