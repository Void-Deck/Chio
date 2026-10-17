# MeasurementGauge

`MeasurementGauge` presents an application-normalized reading as a bar or dial.
Independent target bands and bar references provide context without classifying a
reading as success or failure. It is a passive public view in `Chio`.

## Use

With `Chio` and `SwiftTUIViews` imported, construct checked annotations in a
throwing application scope and compose the gauge in a SwiftTUI view:

```swift
let target = try MeasurementGauge.TargetBand(lowerBound: 0.45, upperBound: 0.60)
VStack(alignment: .leading) {
    Text("Temperature: 21.4 °C; target 18–24 °C")
    MeasurementGauge(position: 0.535, targetBand: target, style: .dial)
        .accessibilityLabel("Temperature 21.4 degrees Celsius; target 18 to 24.")
}
.style(.btop)
```

`init(position:style:)` defaults to `.bar`. The `targetBand:` overload supports
bars or dials. `init(position:referenceMarks:targetBand:)` supplies up to two
checked references on a bar. Compose captions and surrounding labels with native
views; reserve the complete plot and caption height.

## Behavior and ownership

Known positions must be finite and in `0...1`; invalid positions fail a construction
precondition. `nil` means missing, independently of known targets or references.
Applications own normalization, units, out-of-range policy and statistics.

`TargetBand` throws unless its finite normalized bounds strictly increase.
`ReferenceMark` throws for an invalid position or empty caption; `ReferenceMarks`
throws for more than two marks or repeated IDs. Authored order determines reference
ordinals. Shared cells show `*`, while both numbered captions remain visible.
These immutable annotation values have no persistence or Codable contract.

A bar prefers twenty columns, permits one through 512, and uses a reading row
plus separate rows for a present target and references. Native caption wrapping
adds height and ignores inherited line limits. A dial retains a fixed 20 × 5
plot and centers in surplus width. Forced undersized frames can still clip it.

Bars and plain dials use theme accent. Target dials use the theme's gauge palette;
target paint wins shared arc cells, then needle paint wins overlaps. All eight
Braille dots in a cell share one foreground, so narrow targets may be obscured.
Keep numeric target captions, particularly in monochrome terminals.

The view owns no sampler, clock, alert policy or focus stop. Its accessibility
summary uses normalized values; override it with units and scale meaning.

## Source and verification

[MeasurementGauge.swift](Presentation/MeasurementGauge.swift) owns presentation.
[TargetBand](Domain/MeasurementGauge+TargetBand.swift),
[ReferenceMark](Domain/MeasurementGauge+ReferenceMark.swift) and
[ReferenceMarks](Domain/MeasurementGauge+ReferenceMarks.swift) own checked annotations.
[Gauge tests](../../../Tests/ChioTests/MeasurementGauge/Presentation/MeasurementGaugeTests.swift)
cover raster, layout and semantics; [annotation tests](../../../Tests/ChioTests/MeasurementGauge/Domain/TargetBandTests.swift),
[mark tests](../../../Tests/ChioTests/MeasurementGauge/Domain/ReferenceMarkTests.swift) and
[collection tests](../../../Tests/ChioTests/MeasurementGauge/Domain/ReferenceMarksTests.swift)
cover validation. See the [owning decision](../../../Docs/Decisions/Instrumentation.md),
[Usage](../../../Docs/Usage.md) and [Verification](../../../Docs/Verification.md).
