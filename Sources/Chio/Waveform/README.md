# Waveform

`Waveform` presents a min/max envelope of a checked fixed-rate series in an
application-owned time window. It is a passive public view in the `Chio` library.

## Use

With `Chio` and `SwiftTUIViews` imported, construct checked values in a throwing
application scope:

```swift
let samples = try WaveformSamples(start: .zero, rate: 25, values: [0, 2, -1, nil, 3])
let window = try HistoryInterval(start: .zero, end: .seconds(1))
let scale = try WaveformScale.fixed(lower: -4, upper: 4)
Waveform(samples, window: window, scale: scale, mode: .bipolar)
    .frame(width: 40, height: 6)
    .style(.btop)
```

## Behavior and ownership

Applications supply sample timing, the window, explicit scale, mode and optional
labelled events. They compose axes, captions, counts and aligned traces. Chio
performs no clinical interpretation. The inherited style supplies accent trace,
muted zero axis and semantic event colors. Labels carry event meaning.

Reduction preserves extrema in every braille dot column. Nil samples stay gaps;
interpolation joins only adjacent known samples inside the window. Magnitude
mode fills upwards from the lower bound. Bipolar mode draws a muted zero axis.
An event row reserves one row whenever the supplied event array is nonempty.
The accessibility summary counts visible samples, gap runs and labelled events.

Checked immutable domain types throw typed errors. Admission allows 2,097,152
samples and 4,096 events; proposals above 512 columns or 64 rows replace the plot
with an unavailable message. A fixed bipolar scale must include zero.
See the [accepted contract](../../../Docs/Decisions/Waveform.md) for exact rules.

## Source and verification

[Waveform.swift](Presentation/Waveform.swift) composes native drawing;
[WaveformColumns.swift](Presentation/WaveformColumns.swift),
[WaveformBounds.swift](Presentation/WaveformBounds.swift) and
[WaveformEventRow.swift](Presentation/WaveformEventRow.swift) own pure reduction,
scale mapping and placement. Domain files own checked values.
[Supplementary tests](../../../Tests/ChioTests/Waveform/Presentation/WaveformRenderingTests.swift)
exercise internal boundaries and render a 720,000-sample series. The
[study](../../../Spikes/Waveform/README.md) consumes the public view with hosted
captures. See [Verification](../../../Docs/Verification.md) for repository gates.
