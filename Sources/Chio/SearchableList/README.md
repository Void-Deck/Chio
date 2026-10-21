# SearchableList

`SearchableList<Item, RowContent>` combines an always-visible native search field
with a selectable, scrollable native list. Items need stable, unique IDs, with
`Item: Identifiable` and `Item.ID: Sendable`.

## Use

Import `Chio` and `SwiftTUI`. Supply an application-owned optional ID binding:

```swift
SearchableList(items, selection: $selectedID, searchText: \.name) { item in
    Text(item.name).lineLimit(1)
}
.onActivate { item in openedID = item.id }
.filtering(.fuzzy)
.style(.default)
```

The application supplies `items`, selection and activation policy. The
initializer accepts a random-access collection, optional `query:` binding and
`prompt:` string. Omit the query binding for component-owned native query state.
Fuzzy matching is the default; `.filtering(.substring)` preserves source order.

## Selection, focus and styling

Filtering preserves a visible selected ID, otherwise chooses the first result
or nil. Filtering never activates an item. Activation reads the current retained
query and reconciles selection, including rapid input and rejected query writes.
Empty source data and unmatched queries have distinct messages.

Selection and native focus are separate. Tab can move row focus independently;
Return activates the selected ID. Slash enters search, and Escape clears the
query. See the [searchable selection contract](../../../Docs/Decisions/SearchableSelection.md)
for the complete input table and search-to-results handoff behavior.

Rows are passive presentation; place buttons and editors outside the list.
Scope result shortcuts with `.onResultKeyPress(perform:)` so ordinary characters
remain search text. `.onSearchFocusChange` supplies render-driven presentation
feedback and can lag input; do not use it to gate ancestor shortcut handling.

The inherited Chio style supplies search/list presentation and whole-row vertical
insets. Applications own row content, available width and action meanings;
SwiftTUI retains measurement, focus, selection navigation and scrolling.

## Source and verification

- [SearchableList.swift](Presentation/SearchableList.swift) owns the public view and binding transitions.
- [SearchMatcher.swift](../Search/Domain/SearchMatcher.swift) supplies shared pure matching.
- [SearchFilter.swift](../Search/Domain/SearchFilter.swift) defines supported filter choices.
- [SearchableListTests](../../../Tests/ChioTests/SearchableList/Presentation/SearchableListTests.swift) covers authoritative bindings, batched input, filtering, activation, focus, theme and resize. Simultaneous-list cases check independent editing and selection with overlapping IDs and different item and row types.
- [ListRowSpacingTests](../../../Tests/ChioTests/List/Presentation/ListRowSpacingTests.swift) covers inherited row spacing.

See [Usage](../../../Docs/Usage.md#search-and-keyboard-hints) and
[Verification](../../../Docs/Verification.md) for recipes and required checks.
