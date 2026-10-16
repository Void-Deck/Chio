# SearchableChecklist

`SearchableChecklist<Item, RowContent>` presents searchable multiple choice with
persistent checkmarks and native row focus. Items need stable, unique IDs, with
`Item: Identifiable` and `Item.ID: Sendable`.

## Use

Import `Chio` and `SwiftTUI`. Keep checked IDs in an application-owned set binding:

```swift
SearchableChecklist(items, selection: $selectedIDs,
                    searchText: \.name, isEnabled: \.isAvailable) { item in
    Text(item.name)
}
.filtering(.fuzzy)
.style(.default)
```

The initializer accepts a random-access collection, optional `query:` binding,
`prompt:` string and `isEnabled:` predicate. Eligibility defaults to true.
Omit `query:` for native component-owned search state. Fuzzy matching is the
default; `.filtering(.substring)` preserves source order.

## Membership and interaction

Filtering never changes the checked set. Hidden, removed and already-checked
disabled IDs remain bound; displayed counts distinguish hidden and unavailable
checks. Only visible, enabled IDs can toggle in either direction. Applications
own selection limits, validation, stale-ID removal, reset and submission.

Arrows move native focus; Space or Return toggles a row. Focus is independent of
membership and may change when rows reorder. Return from search requests results
focus. Unmodified input during that handoff is consumed until focus arrives,
preventing stale-row toggles. No-result Return keeps editing focus.

Rows are passive views; place editors and buttons outside the checklist.
`.onResultKeyPress(perform:)` scopes application shortcuts to results. The binding
adapter reads retained query/membership at dispatch and honors rejected or
transformed writes. Eligibility uses the current rendered source; it cannot
promise freshness for source changes that have not rendered.

The inherited Chio style supplies colors, native control treatment and whole-row
insets. Native layout and scrolling remain authoritative. See the accepted
[membership contract](../../../Docs/Decisions/SearchableSelection.md#searchable-multiple-choice).

## Source and verification

- [SearchableChecklist.swift](Presentation/SearchableChecklist.swift) owns composition and binding admission.
- [ChecklistSelection.swift](Domain/ChecklistSelection.swift) owns the pure membership transition.
- [SearchFilter.swift](../Search/Domain/SearchFilter.swift) supplies shared filtering choices.
- [SearchableChecklistTests](../../../Tests/ChioTests/SearchableChecklist/Presentation/SearchableChecklistTests.swift) covers interaction and authoritative membership.
- [SearchableChecklistRenderTests](../../../Tests/ChioTests/SearchableChecklist/Presentation/SearchableChecklistRenderTests.swift) covers checkmarks, counts, disabled/empty states and styles.
- [ChecklistSelectionTests](../../../Tests/ChioTests/SearchableChecklist/Domain/ChecklistSelectionTests.swift) covers membership admission.

See [Usage](../../../Docs/Usage.md#multiple-choices) and
[Verification](../../../Docs/Verification.md) for recipes and current checks.
