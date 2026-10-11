# Native integration boundaries

**Status:** Accepted constraints of the pinned implementation; unresolved limitations remain.

Keep native ownership and visible limitations explicit when composing or extending Chio.

## Native chrome

Native list focus chrome uses SwiftTUI's theme; Chio themes selected content and
controls. The native theme environment is not public. `StatusBar` composes a text
rule because native Divider ignores ambient foreground. Keep these upstream
limits visible without a second focus system or renderer.

## Remaining boundaries

These limits apply to the pinned implementation; none authorizes another
renderer, focus system or hidden dependency patch.

| Boundary | Current limit and responsible follow-up |
| --- | --- |
| Native style hooks | Table border/background chrome, list focus gutter, palette shell, prompt headers and disabled-editor glyph paint are not fully controlled by Chio. Keep native behavior and resolve missing hooks upstream. |
| Layout and lifecycle | Scroll focus reveal can move a two-axis viewport by one cell; nested tab strips can receive stale width proposals; expanded disclosure focus includes descendants. Keep the documented native contracts for [scrolling](Scrolling.md#scrolling), [tabs](Tabs.md#tabs) and [disclosure](DisclosureGroups.md#expandable-groups-and-trees). |
| Choice composition | Changing choice fields inside `GeometryReader` triggered a native debug lifecycle-publication assertion. The full-window example uses `terminalSize`; arbitrary nesting remains unproved. |
| List density and focus | New per-row density controls are deferred. Tall-row reveal/intrinsic sizing is incorrect; generic focus scrolling also undoes compact lists' valid anchors. See [the findings](#tall-list-rows). |
| Collection measurement | Native ideal-size probes can realize all rows before a bounded viewport commits and emit deferred `collection.unboundedRealization` warnings. Small fixtures do not prove virtualization or large-dataset performance; diagnostics are retained. |
| Early input | Search, palette and form handoffs cover documented type-ahead/batched paths. Arbitrary multi-control input before presentation settles needs native support, not an application-built editor or focus graph. |
| Editor navigation | End at the end of a native text field is unhandled when it makes no change, so an enclosing ScrollView can scroll to the bottom. The appearance study reproduced this at 36 × 18; ordinary editing remains focused. Its capture moves Left before End to exercise a real caret movement. Repeated no-op End is unresolved at the native input owner. |
| Cooperative shutdown | Continuous state writes can prolong the final native render drain after quit or EOF. The [upstream proposal](https://github.com/SwiftTUI/swift-tui/pull/45) addresses the drain at its runtime owner. It has not been adopted by Chio; the dependency is unchanged. |
| Portability and accessibility | CI and pseudo-terminals cover specific workflows. Other distributions, architectures, assistive technologies and live SSH devices require separate evidence. Static Linux remains [blocked](Dependencies.md#static-linux-blocker). |

## Tall list rows

**Status:** Reproduced native list limitations; unresolved. All new per-row
density controls are deferred from Chio's unified style API. Opencode keeps
compact rows while adding roomier input padding and leading frames.

Native tests with vertically padded rows in a short overflowing list found that
keyboard navigation can leave the selected item offscreen; checklist focus can
remain stuck because native reveal regards an unpainted next row as visible.
Nil-height intrinsic sizing can also clip tall rows. Finite-height raster geometry
alone does not establish keyboard reveal.

The pinned native owner is
`Sources/SwiftTUIViews/Collections/CollectionScrollState.swift` in SwiftTUI.
`reveal(row:margin:)` uses `CollectionScrollGeometry`, whose line calculation is
`chromeInset + rowIndex * rowSpan`. Without separators it assumes one content
cell per row, excluding authored vertical padding, gaps or wrapped/multiline
content. Visibility and anchor calculations can therefore disagree with painting.

Separately, single-line compact lists lose row focus near the end of an
overflowing viewport. A public hosted reproduction establishes this with a bare
native multi-selection `List` and a minimal style with zero insets and no
separators, without Chio's search composition or styles. Native automatic framed
lists and single-selection container-focused lists traverse the same twelve
rows successfully; Chio's searchable checklist reproduces the compact failure.

At the pinned SwiftTUI revision `2d84ac7`, native focus synchronization in
`Sources/SwiftTUIGraph/Runtime/LocalScrollPositionRegistry.swift` clamps the
collection's valid offset using generic content-minus-viewport geometry, even
when its focused row is already visible. With twelve rows and an eight-line
viewport, the collection reserves two indicator lines and permits anchor six;
generic focus scrolling clamps it back to four. Diagnostic traces confirm both
opposing writes. The requested row then disappears and native focus falls back
to the first visible row. This is separate from tall-row arithmetic.

A temporary native candidate that avoids normalization when no focus-reveal
movement is needed passed five single-line hosted journeys: native single and
multiple selection, minimal compact multiple selection, and both Chio searchable
compositions, including final-row activation or membership toggling. The candidate
was independently reviewed, then removed from the dependency checkout. It is
not adopted, published upstream or verified by SwiftTUI's full gate. Axis-specific
reveal, resize/content shrink, native cursor/scroll regressions and tall-row
geometry still require upstream work; do not treat this bounded proof as a
complete collection-scrolling correction.

Applications can use
`Text(item.title).lineLimit(1).truncationMode(.tail)` to limit row height, but this
is a content policy, not a native scrolling correction. Applications own widths.

Revisiting row density requires native and Chio evidence for overflow, selection,
checkbox focus transfer, activation, scroll reveal and intrinsic sizing. No fix or
upstream PR is claimed. Keep native ownership; do not conceal failures with hidden
dependency patches, another focus system, larger verification viewports or weaker
assertions. The core style consolidation proceeds without new per-row controls.

## Cooperative shutdown follow-up

The current direction is an upstream correction, following investigation of
an internal workaround. Retained synthetic regression and process evidence
establishes the native drain issue. The proposal limits cooperative exit to
final-input presentation and required synchronous UI follow-ups, retaining the
acquisition cap. Chio has not adopted the patch; any dependency update still
requires native and Chio integration checks.

At the pinned revision, `onTerminationRequest` runs after the final render drain
for exit keys and batched EOF. Cleanup in that callback alone cannot prevent the
delay. Any workaround must preserve completed final-input presentation, focus and
lifecycle callbacks, termination cancellation, and terminal cleanup. Applications
own their background producers; Chio cannot silently stop arbitrary external work.
A finite acquisition cap does not guarantee a deadline for an arbitrarily
expensive frame or callback.

An application-specific fallback could quiesce producers before an accepted quit:
prevent subsequent background publication, cancel owned producers, then leave
native final-input rendering and cleanup intact. Cancellation alone does not
exclude a queued publication. Preserve focused-control handling and termination
vetoes; observing an exit chord is not proof that the session will end. An
application owning `RunLoop` can also wrap its public input reader to quiesce
before forwarding EOF. The default scene launcher has no public pre-EOF hook.
These requirements make a transparent Chio modifier insufficient. No internal
workaround was implemented or verified as a process fix; upstream correction is
preferred to expanding Chio's application-lifecycle ownership.

Separate startup and task-cancellation delays reproduced on the upstream baseline
and remain unresolved; incremental-rendering performance needs separate measurement.
