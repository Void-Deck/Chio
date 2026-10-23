# DotMatrix

`DotMatrix` presents a supplied LED image with independent RGB and intensity per
dot. It is a passive public view in the `Chio` library. Lettering, symbols and
animated frames use the same image contract; applications supply their content.

## Use

With `Chio` and `SwiftTUIViews` imported:

```swift
let frame = try DotMatrixFrame(matrix: [
    [SIMD4<Float>(1, 0.25, 0, 1), SIMD4<Float>(1, 0.25, 0, 0.5)],
    [SIMD4<Float>(0, 0, 0, 0), SIMD4<Float>(0, 0.5, 1, 1)],
])
let dots = try DotMatrixStyle(shape: .square, horizontalGap: 1, verticalGap: 0)

DotMatrix(frame: frame, label: "Two amber lights above one blue light")
    .dotMatrixStyle(dots)
    .style(.btop)
```

`DotMatrixFrame(matrix:)` checks a nonempty rectangle without an LED-count cap.
Every `SIMD4<Float>` stores red, green, blue, then intensity. All four channels
must be finite and in `0...1`. The immutable value exposes `matrix`, `columns`
and `height`; access an LED with `frame.matrix[y][x]`. It supports hashing, coding
and sending across concurrency boundaries. Decoding passes through the same
validation as creation. Coding preserves the existing `rows` key through an
explicit mapping; the source API uses `matrix`.

RGB and intensity remain independent facts in the frame. Painting multiplies each
encoded sRGB channel by intensity before creating a native opaque color. This is
a terminal brightness convention, not a physical luminance, gamma-correct light
simulation or alpha channel. Zero intensity and black RGB both paint an inactive
LED, including black RGB with positive intensity. No information is normalized or
removed from the supplied frame.

## Styling and layout

`DotMatrixStyle(shape:horizontalGap:verticalGap:unlitColor:)` is an immutable,
hashable, codable, sendable value. `.round` uses `●`; `.square` uses `■`.
Inactive LEDs always use `·`. Gaps are checked terminal-cell distances in `0...8`,
defaulting to one blank column and zero blank rows. There is no outer gap.
An omitted `unlitColor` inherits `ChioStyle.colors.mutedText`; an explicit color
overrides that role. `.dotMatrixStyle(...)` applies a complete inherited style to
a subtree; the nearest value wins. `EnvironmentValues.dotMatrixStyle` exposes the
same value. Lit colors always come from the supplied frame.

Each LED occupies one terminal cell on a native `.fullCell` Canvas. Logical image
dimensions do not stretch with available space. A matrix of `c` columns and `r`
rows occupies `c + (c - 1) * horizontalGap` terminal columns and
`r + (r - 1) * verticalGap` terminal rows. Terminal font and cell aspect ratio
affect the apparent shape; Chio provides no font or font-file API.

Native `ViewThatFits` selects the complete fixed-pitch image or the authored
`Text` label when either dimension cannot fit. A drawing above 262,144 terminal
cells, including gaps, uses the same text fallback before constructing a Canvas.
Admission checks logical dimensions before calculating spaced extents and
performs no image-sized intermediate allocation. The label is required and also
supplies accessibility text. Use a meaningful authored description, since arbitrary
pixels cannot describe their own application meaning. Native text may wrap or
truncate in very small space.

## Ownership and verification

Applications own input admission, frame memory and runtime budgets, frame
generation, fonts used to compose lettering, animation, clocks, state, focus and
interaction. The component reads only its immutable configuration and inherited
environment. SwiftTUI owns layout, rendering and accessibility. The component
installs no timers, tasks or focus stops.

[DotMatrixFrame.swift](Domain/DotMatrixFrame.swift) owns checked image values.
[DotMatrix.swift](Presentation/DotMatrix.swift) owns bounded native painting and
fallback selection. [DotMatrixStyle.swift](Presentation/DotMatrixStyle.swift)
and its environment integration own inherited presentation.

[Frame tests](../../../Tests/ChioTests/DotMatrix/Domain/DotMatrixFrameTests.swift)
exercise construction, malformed decoding, all channel ranges and frame preservation.
[Style tests](../../../Tests/ChioTests/DotMatrix/Presentation/DotMatrixStyleTests.swift)
exercise defaults, coding and gap validation.
[Rendering tests](../../../Tests/ChioTests/DotMatrix/Presentation/DotMatrixRenderingTests.swift)
exercise independent channel scaling, off-state paint, inherited styles, geometry,
fitting, accessibility and the complete drawing-area bound through public APIs.
These checks establish model and native raster behavior; they do not prove
appearance in every terminal or font. See [Verification](../../../Docs/Verification.md)
for repository checks and recorded terminal evidence.
