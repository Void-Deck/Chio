# DurationText

`DurationText` displays an application-supplied elapsed or remaining `Duration`.
It formats time consistently and provides a spoken label that names the time's
meaning. It is a public view in the `Chio` library.

## Use

With `Chio` and `SwiftTUIViews` imported, compose these expressions in a view:

```swift
VStack(alignment: .leading) {
    DurationText(elapsed: .seconds(83))             // 1:23
    DurationText(remaining: .milliseconds(12_250))  // 0:13
    DurationText(elapsed: .seconds(83), style: .segmented)
}
.style(.btop)
```

`init(elapsed:)` and `init(remaining:)` default to `.plain`. Their `style:`
overloads accept `InstrumentReadout.Style`; `.segmented` uses the shared numeric
lettering and falls back to native text when the complete lettering cannot fit.
Wrap the view in `LabeledContent` or a titled `GroupBox` for application context.
The environment supplies the accent color through `.style(...)`.

## Behavior and ownership

- Inputs must be in `0...Duration.seconds(Int64.max)`. Invalid input fails a
  construction precondition; this API does not clamp or repair durations.
- Elapsed time rounds down to whole seconds. Positive remaining time rounds up,
  preserving a nonzero display until expiry.
- Formatting uses `m:ss` below one hour and `h:mm:ss` thereafter. Hours continue
  beyond 24. The accessibility label speaks the displayed units.
- Plain text follows native wrapping. Segmented lettering needs three rows;
  its native text fallback retains the caller's line limit.

The application owns clocks, scheduling, pause state, countdown updates and expiry
actions. Supply a replacement duration when time changes. This view reads no
clock, creates no timer and adds no focus stop. SwiftTUI owns rendering and layout.

## Source and verification

[DurationText.swift](Presentation/DurationText.swift) owns formatting and delegates
presentation to [InstrumentReadout](../InstrumentReadout/README.md).
[DurationTextTests](../../../Tests/ChioTests/DurationText/Presentation/DurationTextTests.swift)
cover construction boundaries, rounding, accessibility and segmented fallback.

The [instrumentation decision](../../../Docs/Decisions/Instrumentation.md) owns
the complete duration contract. See [Usage](../../../Docs/Usage.md) for timer
composition and [Verification](../../../Docs/Verification.md) for current checks.
