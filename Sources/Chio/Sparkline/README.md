# Sparkline

`Sparkline` presents one passive history at equally spaced slots, oldest to newest.
Use it for a compact trend whose spacing does not encode elapsed time. It is a
public view in the `Chio` library and uses SwiftTUI's native braille canvas.

## Use

With `Chio` and `SwiftTUIViews` imported, compose this expression in a view:

```swift
Sparkline([0.2, 0.7, nil, 0.4, 0.9], scale: .fixed(0...1))
    .frame(width: 24, height: 4)
    .accessibilityLabel("Recent utilization; one reading unavailable.")
    .style(.btop)
```

`init(_:scale:)` takes `[Double?]` and defaults to `.automatic` scaling.
Choose a native frame for plot dimensions, and compose labels and unit captions
outside it. The inherited `ChioStyle` supplies the accent color.
Use [HistoryChart](../HistoryChart/README.md) when actual time offsets matter.

## Behavior and ownership

- Known readings must be finite. Fixed bounds must be finite and strictly
  increasing. Invalid readings or bounds fail construction preconditions.
- `nil` occupies a slot and breaks the line; it differs from zero or removing a
  sample. Empty and all-missing histories draw nothing.
- Automatic scaling uses finite extrema and centers constant series. Fixed
  scaling clips outliers. A single-entry series sits at the right edge; a lone
  known reading among gaps retains its original slot.
- Narrow drawings retain first, last, minimum and maximum readings per drawing
  column within each uninterrupted run. Gaps never introduce connecting segments,
  but gaps smaller than a drawing column may not be visibly distinct.

Every drawing scans the supplied history. Applications bound retention and own
sampling, cadence, clocks, units, thresholds and alert policy. The view creates
no sampler or changing state. Its default accessibility summary reports counts,
latest reading and extrema; replace it to include domain meaning. Native canvas
packing shares one foreground color among subcells in the same terminal cell.

## Source and verification

[Sparkline.swift](Presentation/Sparkline.swift) owns the view, scale and reduction.
[SparklineTests](../../../Tests/ChioTests/Sparkline/Presentation/SparklineTests.swift)
cover gaps, placement, reduction, extreme numeric bounds, semantics and invalid input.

The [instrumentation decision](../../../Docs/Decisions/Instrumentation.md) owns
the full contract. See [Usage](../../../Docs/Usage.md) for composition and
[Verification](../../../Docs/Verification.md) for current checks.
