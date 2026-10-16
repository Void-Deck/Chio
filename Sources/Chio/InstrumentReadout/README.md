# InstrumentReadout

`InstrumentReadout` gives an application-formatted numeric string a prominent,
themed presentation. It offers segmented lettering or ordinary native text,
without assuming what the value measures. It is a public view in `Chio`.

## Use

With `Chio` and `SwiftTUIViews` imported, compose this expression in a view:

```swift
LabeledContent("Temperature") {
    HStack(alignment: .bottom, spacing: 1) {
        InstrumentReadout("21.4")
        Text("°C")
    }
}
.labeledContentStyle(.instrument)
.style(.btop)
```

`init(_:style:)` accepts a `String`; `.segmented` is the default.
Use `InstrumentReadout("Unavailable", style: .plain)` for ordinary native text.
A titled `GroupBox` can host the readout directly. The inherited `ChioStyle`
provides its accent color; native composition owns labels, units and spacing.

## Behavior and ownership

Segmented lettering supports digits, decimal points, colons, plus and minus signs.
It admits at most 32 characters. Empty, unsupported or longer strings use native
text. Native `ViewThatFits` also chooses text when the complete lettering cannot
fit the available width and height.

The lettering always measures three rows, including under an inherited line
limit. The ordinary text fallback retains the caller's native line limit and
wrapping behavior. The supplied string is the accessibility label; override it
when additional units or domain context are needed.

The application owns formatting, localization, measurement acquisition, units,
missing-reading policy and interpretation. An empty string is not an inferred
missing value. This passive view owns no changing state, clock or task and adds
no focus stop. SwiftTUI owns layout and rendering.

## Source and verification

[InstrumentReadout.swift](Presentation/InstrumentReadout.swift) owns the font and
fallback composition. [DurationText](../DurationText/README.md) reuses its styles.
[InstrumentReadoutTests](../../../Tests/ChioTests/InstrumentReadout/Presentation/InstrumentReadoutTests.swift)
cover glyphs, allocation, line limits, fallback, colors and semantics.

See the [instrumentation decision](../../../Docs/Decisions/Instrumentation.md)
for the owning contract, [Usage](../../../Docs/Usage.md) for compositions, and
[Verification](../../../Docs/Verification.md) for current checks.
