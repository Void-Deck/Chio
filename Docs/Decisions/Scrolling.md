# Native scrolling

**Status:** Accepted; shipped in 0.1.0. These contracts remain current.

Theme native scroll indicators while retaining native geometry, reveal and event routing.

## Scrolling

`ChioScrollViewStyle` paints idle indicators muted, focused viewports accent, and
focused individual tracks accent only on that axis. Suppression retains muted
paint. Native disabled opacity, glyphs, track space, insets and inherited
background remain intact; the style does not change sizing or cover surfaces.

SwiftTUI owns positions, clipping, input, dragging, reveal and clamping;
`.scrollIndicators(_:axes:)` controls visibility. The style reaches native editor
scroll views, but editor focus is not viewport focus. Lists/Tables have separate
scrolling styles. Native focus reveal aligns oversized targets at their start on
both axes, preserving the first row and column. Focusing an individual track can
still reveal its reserved column. Chio preserves that native geometry; the earlier
one-cell horizontal shift on initial viewport focus is superseded. Home and End
move both enabled axes when the viewport owns focus. A focused individual track
moves only its own axis.

Interaction tests retain exact keyboard, wheel, focus, theme, resize and drag
assertions. Mouse release is exercised at the track midpoint, where it changes
the bound offset, rather than waiting for a new frame after releasing at the
already selected origin. Automatic and Chio styles both check the corrected
initial position on both axes. Hosted tests also check that a focused descendant
stays visible after viewport shrink and that later content changes do not undo
deliberate application scrolling.

## Implementation and verification

- [ChioScrollViewStyle.swift](../../Sources/Chio/Scrolling/Presentation/ChioScrollViewStyle.swift)
- [ChioScrollViewStyleTests.swift](../../Tests/ChioTests/Scrolling/Presentation/ChioScrollViewStyleTests.swift)
