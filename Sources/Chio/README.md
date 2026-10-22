# Chio library

**Beautiful terminal interfaces for Swift.**

This is the source root of the package's public `Chio` library. It supplies
immutable styles, native control styles and composed terminal views over SwiftTUI.
The [package overview](../../README.md) explains installation, dependency limits,
and the project's personal-software and Codex-assisted development status.

## Start composing

Import `SwiftTUI` and `Chio` in an application, then apply a complete style to a
view subtree:

```swift
import SwiftTUI
import Chio

struct ReadyView: View {
    var body: some View {
        Text("Ready").style(.default)
    }
}
```

`ChioStyle` offers default, light, btop and opencode presets. `View.style(_:)`
installs the inherited style and native control styles; the nearest complete
style wins. Applications retain layout and component behavior choices.
See [usage recipes](../../Docs/Usage.md) for selection, forms, maps and other
compositions, and the [runnable examples](../../Docs/Examples.md) for full apps.

## Public view source guides

Each guide owns the view's entry points, composition, limits and verification.
These directories remain part of the single `Chio` module.

| View | Source guide |
| --- | --- |
| `StatusBar` | [Composition](Composition/README.md) |
| `FilePicker` | [FilePicker](FilePicker/README.md) |
| `FormField` | [Forms](Forms/README.md) |
| `DurationText` | [DurationText](DurationText/README.md) |
| `HistoryChart` | [HistoryChart](HistoryChart/README.md) |
| `InstrumentReadout` | [InstrumentReadout](InstrumentReadout/README.md) |
| `MeasurementGauge` | [MeasurementGauge](MeasurementGauge/README.md) |
| `Sparkline` | [Sparkline](Sparkline/README.md) |
| `SearchableList` | [SearchableList](SearchableList/README.md) |
| `SearchableChecklist` | [SearchableChecklist](SearchableChecklist/README.md) |
| `MarkdownView` | [Markdown](Markdown/README.md) |
| `KeyboardHelp` | [KeyboardHelp](KeyboardHelp/README.md) |
| `KeyHint` | [KeyHint](KeyHint/README.md) |
| `KeyHints` | [KeyHints](KeyHints/README.md) |
| `MapView` | [Maps](Maps/README.md) |
| `PageControl` | [Pagination](Pagination/README.md) |

## Ownership and verification

Code follows component-first paths, with `Domain`, `Protocol`, `Execution`,
`Serialization` and `Presentation` groups where needed. `Style` owns the shared
style/environment integration; native control styles stay beside their component.
The private sibling `ChioFileSystem` target supports filesystem operations without
adding a public library product.

SwiftTUI owns rendering, lifecycle, layout, native state, focus, input and scrolling.
Chio styles describe presentation from supplied values. Explicit component
execution owners handle file loading and map preparation/acquisition; applications
own provider invocation policy, storage choices, validation and external workflows.
[Design](../../Docs/Design.md) owns the full architecture and effect contracts.

[Verification](../../Docs/Verification.md) defines the pinned engineering gate,
serial release tests, public raster checks, hosted interactions and terminal
probes. Tests under `Tests/ChioTests` generally mirror these component roots.
Run the required repository checks from the checkout root; a snapshot alone does
not prove interactive, platform or live-provider behavior. Preserve the documented
[native integration limits](../../Docs/Decisions/NativeIntegration.md).
