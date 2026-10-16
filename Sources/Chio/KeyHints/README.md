# KeyHints

`KeyHints` arranges authored shortcut hints in rows as terminal width permits.
It keeps each hint together when moving between rows, making it suitable for
responsive footers and inline reminders. It is a public view in `Chio`.

## Use

With `Chio` and `SwiftTUIViews` imported, compose this expression in a view:

```swift
StatusBar {
    KeyHints {
        KeyHint("↑↓", "Navigate")
        KeyHint("/", "Search")
        KeyHint("q", "Quit")
    }
}
.style(.btop)
```

`init(content:)` takes a native `@ViewBuilder` closure. The array initializer
`init(_ shortcuts: [ShortcutHint])` creates ordered `KeyHint` children from shared
metadata. Reuse those descriptors in `KeyboardHelp` for expanded descriptions.
Repeated descriptors remain repeated; their positions preserve authored order.

## Behavior and ownership

The layout measures each child, starts a new row when the next hint and gap cannot
fit, and proposes the available width to an individually overlong child. Whole
hints move between rows; a long child may still wrap internally through native
text layout. Wide glyphs are measured in terminal cells.

The environment's `spacing.hintGap` controls inter-hint spacing; key and label
colors belong to [KeyHint](../KeyHint/README.md). Gaps appear only between hints,
never after the final child. Zero gaps allow exact fits. Even a valid `Int.max`
gap wraps safely instead of overflowing width arithmetic.

Applications provide current descriptions and own their availability, context,
input handlers and action execution. Descriptor text does not register shortcuts.
The builder's authored content retains its own native ownership; this layout adds
no task or changing state. SwiftTUI owns measurement, placement and rendering.
Ensure the surrounding footer reserves enough height for the wrapped rows.

## Source and verification

[KeyHints.swift](Presentation/KeyHints.swift) owns the view and private flow layout.
[ShortcutHint.swift](../KeyboardHelp/Domain/ShortcutHint.swift) and
[ShortcutGroup.swift](../KeyboardHelp/Domain/ShortcutGroup.swift) own shared values.
[KeyHintsRenderTests](../../../Tests/ChioTests/KeyHints/Presentation/KeyHintsRenderTests.swift)
cover gaps, exact fits, wide glyphs and footer wrapping;
[KeyHintsInteractionTests](../../../Tests/ChioTests/KeyHints/Presentation/KeyHintsInteractionTests.swift)
cover retained content, theme and resize updates.

See the [keyboard-help decision](../../../Docs/Decisions/KeyboardHelp.md) for the
owning contract, [Usage](../../../Docs/Usage.md) for composition, and
[Verification](../../../Docs/Verification.md) for current checks.
