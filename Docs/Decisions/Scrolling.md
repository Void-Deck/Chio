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
scrolling styles. Native focus reveal still includes the reserved vertical
track column and can shift the horizontal body offset by one cell. The current
upstream revision aligns an oversized vertical target at its start, preserving
the first row instead of shifting down to reveal the bottom track. Chio preserves
that geometry; the earlier one-row vertical shift is superseded.

Interaction tests retain exact keyboard, wheel, focus, theme, resize and drag
assertions. Mouse release is exercised at the track midpoint, where it changes
the bound offset, rather than waiting for a new frame after releasing at the
already selected origin. Automatic and Chio styles both check the corrected
initial vertical position.

## Implementation and verification

- [ChioScrollViewStyle.swift](../../Sources/Chio/Scrolling/Presentation/ChioScrollViewStyle.swift)
- [ChioScrollViewStyleTests.swift](../../Tests/ChioTests/Scrolling/Presentation/ChioScrollViewStyleTests.swift)
