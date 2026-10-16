# PageControl

`PageControl` composes native previous/next buttons with a page and item-range
summary for a finite collection. `Pagination` is its immutable application-owned
position and visible item window.

## Use

Import `Chio` and `SwiftTUI`. Retain the pagination value in application state:

```swift
@State private var pagination = Pagination(totalCount: 23, pageSize: 5)

// In the view body, show items[pagination.itemRange], then:
PageControl(pagination: $pagination)
    .style(.default)
```

`PageControl(pagination:)` accepts a binding. The application owns items, loading
and filtering. The control neither loads pages nor mutates the collection.
The inherited Chio style supplies semantic colors and native button treatment.

## Position and interaction

Counts must be nonnegative and page sizes positive. `pageIndex` is zero-based
and nil for empty collections; `itemRange` is then `0..<0`. Empty results say
“No pages”; empty and single-page sets disable both page actions.

Tab focuses available buttons. Return/Space activates them. Left/Right and
Home/End navigate while page controls have focus. Actions read the currently
retained binding on every event, including batched input, rejected writes and
application-transformed values. A disabled ancestor prevents native actions.

Choose the policy explicitly when data changes:

- `updatingTotalCount(to:)` retains or clamps the current page.
- `resizingPages(to:)` keeps the old first visible item on its new page.
- A new `Pagination(totalCount:pageSize:)` resets to the first page.
- `selectingPage(at:)` returns nil for an invalid page.

These operations return replacements. Give the control at least twenty columns
for ordinary summaries; large numbers truncate within the allocation. See the
accepted [pagination contract](../../../Docs/Decisions/Pagination.md).

## Source and verification

- [PageControl.swift](Presentation/PageControl.swift) owns native controls and binding transitions.
- [Pagination.swift](Domain/Pagination.swift) owns checked position, ranges and replacement policies.
- [PageControlTests](../../../Tests/ChioTests/Pagination/Presentation/PageControlTests.swift) covers compact summaries, native activation, boundaries, authoritative bindings, resize and disabled behavior.
- [PaginationTests](../../../Tests/ChioTests/Pagination/Domain/PaginationTests.swift) covers position and item-window contracts.
- [PaginationExampleView](../../../Examples/AgentDashboard/Presentation/PaginationExampleView.swift) demonstrates filtering and page sizing.

See [Usage](../../../Docs/Usage.md#pagination) and
[Verification](../../../Docs/Verification.md) for recipes and required checks.
