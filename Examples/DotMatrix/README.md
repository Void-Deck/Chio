# Chio dot matrix example

A runnable local example of Chio's public `DotMatrix` view. CHIO lettering and a
four-frame heart use the same immutable `DotMatrixFrame`. The application owns
its tiny fixture font, supplied RGB colors, intensity replacements, playback and
300 ms animation task. The view remains passive.

```sh
swift run -c release chio-matrix
swift run -c release chio-matrix --theme light
swift run -c release chio-matrix --theme btop
swift run -c release chio-matrix --viewport
```

The default theme is `default`. The selected `ChioStyle` wraps the complete root;
its semantic colors style captions, controls and inherited inactive dots. The
lettering and heart retain their supplied RGB colors across themes.

Space plays or pauses, Right steps to the next paused frame, `t` switches
amber/green lettering, and `s` changes round/square dots. `g` cycles terminal-cell
gaps through `(1,0)`, `(3,1)` and `(0,0)`. `i` cycles intensity through `1`, `0.5`
and `0.2`. `q` quits. The application starts paused for repeatable inspection.
Controls use wrapping `KeyHints`; the root owns native focus and key handling.
Validated styles and image variants are constructed before interactive launch.

Every LED occupies its own terminal cell. The normal one-column horizontal gap
approximates square pitch with terminal cells twice as tall as they are wide.
Actual glyph shape and proportions depend on the terminal font. The library
retains fixed pitch and presents the complete grid only when it fits; otherwise
it renders the authored semantic label. At 36 × 24, normal CHIO lettering falls
back while the heart can remain visible. At 24 × 14, the application allocates one
row to each image so both use labels and the controls remain available. Wider
gaps can also trigger fallback. These are application layout choices.

`--viewport` composes a larger 64 × 40 RGB gradient into SwiftTUI's native two-axis
`ScrollView`. Its matrix has an explicit 127 × 40 terminal-cell allocation, so
native clipping reveals parts of a complete fixed-pitch image. Arrows scroll;
Home and End jump to the bounds. Native focus, clipping, offsets and input remain
SwiftTUI's responsibility. This demonstrates composition with the same public
view; it adds no scrolling implementation to Chio.

`MatrixLettering` admits 1–10 fixture characters from CHIO, digits and colon. It
rejects unsupported text. It is not a public font or localization API. The
separate launcher keeps `@main` out of the module imported by tests. See the
[public component guide](../../Sources/Chio/DotMatrix/README.md) for checked frame,
style, intensity and rendering limits, and [Design](../../Docs/Design.md) for
ownership contracts.

## Verification

```sh
swift test -c release --filter MatrixSceneTests
python3 -B Scripts/docs/capture-dot-matrix.py .build/release/chio-matrix \
  --output .build/dot-matrix-review
```

The fixture tests protect independently expected lettering pixels, unsupported
text, immutable intensity replacements, distinct heart colors, frame order, gap
choices and RGB gradient corners. Public frame validation and raster behavior
belong to the library tests.

The capture script uses an already-built release executable and a fresh output
directory. It exercises all three themes, stepping, playback, color/shape changes,
intensity/gap cycles, narrow/tiny fallback, paused-frame recovery and native
viewport scrolling. It verifies clean exit and terminal mode, alternate-screen
and cursor restoration. Full logs and untrimmed casts remain with the evidence;
publication clips end before teardown. No service, credentials or external data
are used.

The three 80 × 32 showcase recordings are `dot-matrix-default.cast`,
`dot-matrix-light.cast` and `dot-matrix-btop.cast`, with matching `-initial.cast`
files for PNG rendering through `Scripts/docs/render-terminal-previews.cjs`.
Narrow/tiny captures and `dot-matrix-default-viewport.cast` provide additional
review evidence. Inspect the clips and full logs before publication; recordings
do not establish arbitrary terminal/font, SSH or live-device appearance.
