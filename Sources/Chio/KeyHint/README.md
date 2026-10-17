# KeyHint

`KeyHint` presents one authored key label and the action it describes. Use it for
a compact reminder near the relevant content or inside a footer. It is a passive
public view in the `Chio` library.

## Use

With `Chio` and `SwiftTUIViews` imported, compose this expression in a view:

```swift
KeyHints {
    KeyHint("↑↓", "Navigate")
    KeyHint("/", "Search")
}
.style(.btop)
```

`init(_ key: String, _ label: String)` constructs a shortcut description directly.
`init(_ shortcut: ShortcutHint)` reuses the same immutable descriptor as expanded
help:

```swift
let search = ShortcutHint("/", "Search", detail: "Filter the current list.")
KeyHint(search)
```

The descriptor's detail is reserved for `KeyboardHelp`; the compact view shows
only its key and label. Use [KeyHints](../KeyHints/README.md) to wrap several whole
hints as available width changes. Native containers own placement and allocation.

## Behavior and ownership

The key is bold and uses the environment's accent color. The label uses secondary
text color, separated from the key by one space. Authored strings are presented
verbatim. `.style(...)` supplies these semantic colors; it does not change which
action the description names.

A key label is display metadata. It is never parsed into input, registered as a
shortcut or used to enable an action. Applications own available descriptions,
context, native event handlers and action execution. Keep reminders consistent
with those handlers, including editor-specific shortcut scopes.

The view has immutable configuration and reads the supplied style environment.
It creates no task, changing state or focus stop. SwiftTUI owns text layout and
rendering. Expanded help and its presentation belong to `KeyboardHelp` and the
application's native presentation owner.

## Source and verification

[KeyHint.swift](Presentation/KeyHint.swift) owns presentation;
[ShortcutHint.swift](../KeyboardHelp/Domain/ShortcutHint.swift) owns shared metadata.
[KeyHintsRenderTests](../../../Tests/ChioTests/KeyHints/Presentation/KeyHintsRenderTests.swift)
exercise colors and wrapping in composition;
[KeyboardHelpRenderTests](../../../Tests/ChioTests/KeyboardHelp/Presentation/KeyboardHelpRenderTests.swift)
check compact detail omission and shared descriptors.

See the [keyboard-help decision](../../../Docs/Decisions/KeyboardHelp.md),
[Usage](../../../Docs/Usage.md) and [Verification](../../../Docs/Verification.md)
for shared contracts, compositions and current checks.
