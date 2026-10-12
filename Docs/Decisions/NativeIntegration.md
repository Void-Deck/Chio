# Native integration boundaries

**Status:** Accepted constraints of the pinned implementation; unresolved limitations remain.

Keep native ownership and visible limitations explicit when composing or extending Chio.

## Upstream contributions

Match SwiftTUI's current contribution instructions, nearby source terminology and
accepted pull-request conventions. Source comments explain a non-obvious reason,
invariant or coordinate system; they do not narrate the patch or carry Chio's
internal task history. Use established names consistently across code, tests and
the PR description. Distinguish measured sizes from estimates explicitly.

Lead PR descriptions with the reproducible problem and resulting behavior, then
explain the correction and relevant verification. Include a minimal reproducer or
regression test and keep unverified platforms visible. Review comments and wording
alongside correctness so maintainers can assess the fix without knowing Chio.

Before publishing or updating a contribution, re-read upstream
[AGENTS.md](https://github.com/SwiftTUI/swift-tui/blob/main/AGENTS.md) and
[CONTRIBUTING.md](https://github.com/SwiftTUI/swift-tui/blob/main/CONTRIBUTING.md).
Audit the full outgoing diff and commit messages, run the applicable upstream
hooks and gates, and state any unavailable guidance or unverified checks. Keep
upstream requirements authoritative for its code and contribution metadata.

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
| List density and focus | New per-row density controls are deferred. Tall-row reveal and placement remain incorrect; generic focus scrolling also undoes compact lists' valid anchors. Current upstream fixes one indexed intrinsic-layout case, but not these scrolling failures. See [the findings](#tall-list-rows). |
| Collection measurement | Native ideal-size probes can realize all rows before a bounded viewport commits and emit deferred `collection.unboundedRealization` warnings. Small fixtures do not prove virtualization or large-dataset performance; diagnostics are retained. |
| Early input | Search, palette and form handoffs cover documented type-ahead/batched paths. Arbitrary multi-control input before presentation settles needs native support, not an application-built editor or focus graph. |
| Editor navigation | End at the end of a native text field is unhandled when it makes no change, so an enclosing ScrollView can scroll to the bottom. The appearance study reproduced this at 36 × 18; ordinary editing remains focused. Its capture moves Left before End to exercise a real caret movement. Repeated no-op End is unresolved at the native input owner. |
| Cooperative shutdown | Continuous state writes can prolong the final native render drain after quit or EOF. The [upstream proposal](https://github.com/SwiftTUI/swift-tui/pull/45) addresses the drain at its runtime owner. It has not been adopted by Chio; the dependency is unchanged. |
| Portability and accessibility | CI and pseudo-terminals cover specific workflows. Other distributions, architectures, assistive technologies and live SSH devices require separate evidence. Static Linux remains [blocked](Dependencies.md#static-linux-blocker). |

## Tall list rows

**Status:** Verified investigation with two upstream candidates: the per-axis
reveal correction in [SwiftTUI PR #46](https://github.com/SwiftTUI/swift-tui/pull/46)
and the measured-height correction in
[SwiftTUI PR #47](https://github.com/SwiftTUI/swift-tui/pull/47). Neither is adopted
by Chio. All new per-row density controls remain deferred from Chio's unified
style API.
Opencode keeps compact rows and roomier input padding/leading frames.

Review #46 first. Keep #47 draft until #46 merges, then rebase it onto upstream
`main` and verify that its diff contains only the measured-height correction
before marking it ready. The branch already includes #46; its PR currently
targets `main` because the dependency branch exists only in the contributor fork.

A standalone package importing only public `SwiftTUIRuntime` reproduces these
failures on macOS with Swift 6.4.0. The same eight parameterized cases ran against
Chio's pin `2d84ac7083993da2ef52e9d3d30255467efb9553` and upstream main
`6d7de72701354b9be074f51098d9d8ee1dcefaac` on 2026-10-11. Neither dependency
checkout was modified. Hosted cases use twelve rows in an eight-line list on a
32 × 12 surface. Passing journeys visit every row down and back and activate the
final row; multi-selection cases check that the focused region paints the target.

| Public native case | Chio pin | Inspected upstream main |
| --- | --- | --- |
| Automatic style, single and multiple selection, one-line rows | Both pass | Both pass |
| Compact style, multiple selection, one-line rows | Fails revealing ID 10 | Same failure |
| Automatic style, single and multiple selection, vertically padded rows | Both fail revealing ID 1 | Same failures |
| Compact style, multiple selection, vertically padded rows | Fails revealing ID 2 | Same failure |
| `List(data)`, three padded rows, unbounded height | Allocates nine lines but overlaps row padding | Passes: labels at lines 1, 4, 7 |
| `List { ForEach(...) }`, same intrinsic-layout fixture | Overlaps row padding | Same failure |

IDs and raster lines in this table are zero-based. Padding is one line above and
below each label. Intrinsic-layout assertions check label positions, not only
total height or text presence: the failing nine-line rasters put labels on
adjacent lines 1, 2, 3. Finite-height raster geometry alone does not establish
keyboard reveal. These are deterministic hosted/raster reproductions, not live
SSH, Linux or full upstream-gate evidence.

### Conflicting focus and collection offsets

`Sources/SwiftTUIGraph/Runtime/LocalScrollPositionRegistry.swift` normalizes both
axes during focus reveal using generic content-minus-viewport bounds, even when
the focused row is already visible. A twelve-row collection with an eight-line
viewport reserves two indicator lines and permits anchor six; generic focus
scrolling clamps it back to four. The target disappears and focus falls back to
the first visible row. This remains present in the inspected upstream main.

An earlier temporary native candidate skipped normalization when no reveal
movement was needed. It passed five single-line native/Chio hosted journeys and
was removed from the dependency checkout. Review found that a whole-offset guard
is insufficient: horizontal reveal can still clamp a valid vertical offset.
The focused correction in PR #46 preserves an already-visible axis independently
of movement on the other axis. Its regression tests fail on unchanged upstream
and pass on candidate `fc80a1894ecd0d3d81f7a621ec67427136cab73c`: 50 tests across
native registry, collection interaction, lazy composition, viewport sizing and
wheel-scroll suites pass on macOS with Swift 6.4.0. Independent review found no
issues. The full native `bun run test` gate also passes on macOS at that revision,
including all runtime shards, platform suites, TermUIPerf and the soundness scan.
GitHub workflows report `action_required` without executing; upstream CI remains
pending. Chio's dependency pin is unchanged.
Cursor reveal and unanchored `scrollTo` share the helper;
explicit anchors and arbitrary binding normalization remain outside this fix.

### Row measurement and navigation disagree

`Sources/SwiftTUIViews/Collections/CollectionScrollState.swift` remains identical
between the two inspected revisions. `CollectionScrollGeometry` calculates a
row's line as `chromeInset + rowIndex * rowSpan`, with one content line per row
plus an optional separator. Reveal, offset conversion, paging and target anchors
therefore omit measured padding and multiline/wrapped content. Rendering already
knows those heights, so navigation can consider an unpainted next row visible.

Current upstream derives indexed lists' intrinsic layout from the measured size
in `Sources/SwiftTUICore/Measure/LayoutEngine+HostedCollectionWindowing.swift`,
correcting the pinned ordering defect. Builder lists bypass that indexed path;
`Sources/SwiftTUICore/Place/LayoutEngine+PlacementRequests.swift` falls back to
uniform row placement without their measured heights. Their larger measured
height does not prevent overlapping child placement.

The measured-height candidate `3e7c1459b565e438a7f5d5fac9a9e74a4a7b7f8c`
in draft PR #47 is based on PR #46. Layout publishes measured row geometry and
the usable viewport through the existing collection registration. Navigation, paging, wheel movement
and target anchors use those cells; unrealized indexed rows retain the existing
one-line estimate. A programmatic target receives one correction after measurement,
unless newer input supersedes it. Builder lists preserve measured row wrappers,
section headers and footers through placement. Home and End can still reach
section-only cells.

Oversized focus targets align at their start. If a focused row leaves a collection
window, a focusable collection can retain focus. A width change that wraps the
focused row out of view reuses the runtime's single eager follow-up pass to reveal
it before replacing focus regions. Explicit focus requests take precedence.
These are native corrections; no Chio scroll controller or public view API was added.

Regression coverage checks exact padded-row placement, mixed-height List/Table
navigation and activation in both directions, sections, paging, wheel reversal,
far programmatic targets, oversized rows and same-ID height/width changes. The
width regression changes the collection frame; it does not establish live terminal
resize or SSH behavior. Existing bounded-realization checks remain intact.
The full native `bun run test` gate passes on macOS with Swift 6.4.0 at that
revision: all 85 steps, including every runtime shard, platform suites, TermUIPerf
and the soundness scan. Focused collection, focus and host-wire contract checks
also pass; independent review found no remaining issues. All six GitHub workflows
report `action_required` with zero jobs, so upstream platform execution awaits
maintainer approval. Chio integration is not yet verified and its dependency pin
remains unchanged.

Current PR #47 head is `98560f9354fe00ec97cc209333af3516297b3dfa`. Its only change
after the tested `3e7c1459` is a comment clarifying the scroll-anchor measurement
contract. Formatting and applicable upstream hooks pass. Upstream explicitly
exempts comment-only changes from repeating the full gate.

Applications can use
`Text(item.title).lineLimit(1).truncationMode(.tail)` to limit row height, but this
is a content policy, not a native scrolling correction. Applications own widths.

Revisiting row density requires native and Chio evidence for overflow, selection,
checkbox focus transfer, activation, scroll reveal and intrinsic sizing. The
focused upstream proposal does not establish a complete list-density fix or
verified Chio adoption. Keep native ownership; do not conceal failures with hidden
dependency patches, another focus system, larger verification viewports or weaker
assertions. The core style consolidation proceeds without new per-row controls.

SwiftTUI's linked `swift-tui-org/docs/swift-tui/DEVELOPMENT.md` returned 404 during
this investigation. Its additional requirements remain unchecked; obtain it
before claiming compliance with the complete upstream contribution process.

## Cooperative shutdown follow-up

The current direction is an upstream correction, following investigation of
an internal workaround. Retained synthetic regression and process evidence
establishes the native drain issue. The proposal limits cooperative exit to
final-input presentation and required synchronous UI follow-ups, retaining the
acquisition cap. Chio has not adopted the patch; any dependency update still
requires native and Chio integration checks.

Candidate `43672d5a678100ef4304147fac66752e5aa2d1ce` passes the full native macOS
`bun run test` gate with Swift 6.4.0: all 85 steps, including the runtime shards,
platform suites, TermUIPerf and soundness scan. Formatting and applicable upstream
hooks also pass. Linux and Windows execution remain pending upstream CI.

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
