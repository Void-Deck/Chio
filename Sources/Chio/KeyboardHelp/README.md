# KeyboardHelp

`KeyboardHelp` presents grouped, wrapping shortcut descriptions in an inline
region or native sheet. It is passive content: descriptions do not register,
enable or execute input actions.

## Use

Import `Chio` and `SwiftTUI`, and derive descriptions from application context:

```swift
let shortcuts = [
    ShortcutHint("↑↓", "Navigate", detail: "Move through visible items."),
    ShortcutHint("Return", "Open")
]

ScrollView {
    KeyboardHelp([ShortcutGroup("Navigation", shortcuts: shortcuts)])
}
.style(.default)
```

The initializer takes `[ShortcutGroup]`. The application chooses inline or
modal presentation and supplies native scrolling when content exceeds its
allocation. The inherited Chio style supplies heading, key and supporting colors.

## Descriptions and ownership

`ShortcutHint` contains authored `key`, `label` and `detail` strings. Empty detail
omits its row. `ShortcutGroup` contains a title and ordered hints; order and
duplicates are preserved. Empty groups are omitted, and all-empty help displays
an explicit no-shortcuts message. Long headings, descriptions and details wrap.

These immutable values are also shared with the distinct
[KeyHint](../KeyHint/Presentation/KeyHint.swift) and
[KeyHints](../KeyHints/Presentation/KeyHints.swift) views. Their compact
presentation does not display expanded detail. Codable shortcut decoding accepts
historical missing/null detail as empty text; encoding supplies a string.

Applications retain context and availability, modal lifetime and native focus
restoration. Input handlers remain execution authority. Scope printable help
shortcuts outside editors and account for pending modal input. The accepted
[keyboard help contract](../../../Docs/Decisions/KeyboardHelp.md) owns these
presentation and handoff requirements; this component adds no shortcut registry.

## Source and verification

- [KeyboardHelp.swift](Presentation/KeyboardHelp.swift) owns grouped presentation.
- [ShortcutHint.swift](Domain/ShortcutHint.swift) owns shared shortcut descriptions.
- [ShortcutGroup.swift](Domain/ShortcutGroup.swift) owns ordered grouping.
- [KeyboardHelpRenderTests](../../../Tests/ChioTests/KeyboardHelp/Presentation/KeyboardHelpRenderTests.swift) covers style roles, details, grouping, duplicates, wrapping and empty states.
- [ShortcutHintTests](../../../Tests/ChioTests/KeyboardHelp/Domain/ShortcutHintTests.swift) covers description value/encoding contracts.
- [HelpExampleTests](../../../Tests/ChioDashboardTests/Presentation/HelpExampleTests.swift) covers the example's modal input, focus restoration and compact scrolling.

See [Usage](../../../Docs/Usage.md#expanded-keyboard-help) and
[Verification](../../../Docs/Verification.md) for recipes and current checks.
