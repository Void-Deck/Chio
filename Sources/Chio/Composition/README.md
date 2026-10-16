# StatusBar

`StatusBar<Content>` presents an authored footer below a themed horizontal rule.
It supplies presentation for application status or contextual hints; the
application chooses the content and where the footer belongs.

## Use

Import `Chio` and `SwiftTUI`, then compose the footer with native views:

```swift
VStack {
    Text("Ready")
    StatusBar {
        KeyHints {
            KeyHint("↑↓", "Navigate")
            KeyHint("/", "Search")
        }
    }
}
.style(.default)
```

The `@ViewBuilder` initializer accepts arbitrary content. The footer takes the
available width, aligns content to the leading edge, and leaves one row of
spacing between the separator and content. `ChioStyle.colors.border` colors
the separator. Authored content retains its own styling and native behavior.

## Ownership and composition

StatusBar owns no status model, timer, input handler or changing application
state. Keep state above responsive layout alternatives when it must survive
switching layouts. Compose [KeyHints](../KeyHints/Presentation/KeyHints.swift)
for wrapping shortcuts or supply ordinary text and controls.

This source root also contains native `ChioGroupBoxStyle` and
`ChioDisclosureGroupStyle`. Their content, focus and expansion remain native;
they are styles rather than additional Chio view components. See the accepted
[composition contract](../../../Docs/Decisions/Composition.md) and
[disclosure contract](../../../Docs/Decisions/DisclosureGroups.md).

## Source and verification

- [StatusBar.swift](Presentation/StatusBar.swift) owns the footer composition.
- [ChioGroupBoxStyle.swift](Presentation/ChioGroupBoxStyle.swift) owns group chrome.
- [ChioDisclosureGroupStyle.swift](Presentation/ChioDisclosureGroupStyle.swift) owns disclosure presentation.
- [DashboardRenderTests](../../../Tests/ChioDashboardTests/Presentation/DashboardRenderTests.swift) checks composed normal, short and narrow dashboard content and essential hints.
- [HelpExampleTests](../../../Tests/ChioDashboardTests/Presentation/HelpExampleTests.swift) checks composed status, actions and help at several allocations.

These are composition checks; there is no dedicated StatusBar test suite.
Follow [Verification](../../../Docs/Verification.md) for current required checks.
