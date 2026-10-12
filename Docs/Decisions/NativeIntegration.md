# Native integration boundaries

**Status:** The 0.17.0 dependency-upgrade candidate is blocked by native disclosure-content overlap and an unresolved narrow inbox allocation regression.

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

The [0.17.0 candidate](Dependencies.md#0170-adoption-candidate) is not verified
consumer adoption. Its new native accessibility group/button representation is a
declared contract change; direct disclosure-child overlap is a separate rendering
regression. Keep the accepted column assertions and native ownership while the
layout correction is obtained upstream.

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
| List density and focus | New per-row density controls are deferred. The 0.17.0 pin includes #46's per-axis reveal correction; measured-height navigation and builder placement remain pending in #47. See [the findings](#tall-list-rows). |
| Collection measurement | Native ideal-size probes can realize all rows before a bounded viewport commits and emit deferred `collection.unboundedRealization` warnings. Small fixtures do not prove virtualization or large-dataset performance; diagnostics are retained. |
| Early input | Search, palette and form handoffs cover documented type-ahead/batched paths. Arbitrary multi-control input before presentation settles needs native support, not an application-built editor or focus graph. |
| Editor navigation | End at the end of a native text field is unhandled when it makes no change, so an enclosing ScrollView can scroll to the bottom. The appearance study reproduced this at 36 × 18; ordinary editing remains focused. Its capture moves Left before End to exercise a real caret movement. Repeated no-op End is unresolved at the native input owner. |
| Cooperative shutdown | The 0.17.0 pin includes [merged #48](https://github.com/SwiftTUI/swift-tui/pull/48), superseding #45. Accepted quit/EOF retains final-input presentation and synchronous follow-ups without draining unrelated continuous writes. Arbitrarily expensive frames/callbacks and application producers retain their own bounds and ownership. |
| Portability and accessibility | CI and pseudo-terminals cover specific workflows. Other distributions, architectures, assistive technologies and live SSH devices require separate evidence. Static Linux remains [blocked](Dependencies.md#static-linux-blocker). |

## Tall list rows

**Status:** SwiftTUI 0.17.0 includes the merged per-axis reveal correction in
[PR #46](https://github.com/SwiftTUI/swift-tui/pull/46), merge
`3701604e009bc113e4c6f01b25e3d5e7aa7b00eb`. This Chio upgrade candidate pins that
release. The measured-height correction in
[PR #47](https://github.com/SwiftTUI/swift-tui/pull/47) remains unmerged at
`fbcb8873c8df3aa66ee155afb820e10966f55bfe` and is excluded. All new per-row density
controls remain deferred from Chio's unified style API.
Opencode keeps compact rows and roomier input padding/leading frames.

The investigation below describes the earlier pins and candidates. Its failure
table is historical baseline evidence; it is not a new test run against 0.17.0.
Chio's full consumer verification remains distinct from upstream fix verification.

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
Hosted macOS, Linux, Windows arm64/amd64 and Release Soundness workflows also
pass at that revision. The correction subsequently merged and is included in
Chio's 0.17.0 dependency-upgrade candidate.
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

The earlier measured-height candidate `3e7c1459b565e438a7f5d5fac9a9e74a4a7b7f8c`
was based on PR #46 while PR #47 was draft. The current unmerged head above is
rebased onto 0.17.0 and is no longer draft. Layout publishes measured row geometry and
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
also pass; independent review found no remaining issues. At the earlier candidate, upstream platform execution awaited maintainer approval.
The rebased current PR #47 head is `fbcb8873c8df3aa66ee155afb820e10966f55bfe`;
its upstream CI now passes, but it remains unmerged and has no Chio adoption evidence.

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

[PR #48](https://github.com/SwiftTUI/swift-tui/pull/48) merged as
`87dc035869d2d58817511efe9f09bb4ace689808` and supersedes
[PR #45](https://github.com/SwiftTUI/swift-tui/pull/45). It is included in the
published [0.17.0 release](https://github.com/SwiftTUI/swift-tui/releases/tag/0.17.0),
`ee572e38487284092f367ef5b095460a04374ba3`, now pinned by this Chio upgrade candidate.

The runtime observes invalidations without changing SwiftTUIGraph or public APIs.
Termination vetoes run before shutdown begins. Accepted cooperative exit cancels
framework-owned tasks and refuses new task starts, while retaining final-input
presentation and required synchronous lifecycle/focus follow-ups. Applications
retain ownership of external producers. A finite acquisition cap does not guarantee
a deadline for an arbitrarily expensive frame or callback; off-main writes racing
callback observation can conservatively earn follow-ups within that cap.

### Earlier isolated evidence

The separate `Chio-exit48-test` investigation verified 46 native tests across seven
suites, plus all 13 release fairness tests. Its diagnostic writer continued
invalidating after every presentation: quit and EOF required one acquisition and
presentation, compared with 16 each in retained baseline evidence. Cancelled
acquisition retry, synchronous follow-ups, termination vetoes, cancellation and
the signal acquisition limit were retained.

A real-process fixture with a caller-owned producer writing every 20 ms and
350 ms frames measured quit at 6.395 seconds on baseline and 0.765 with #48;
EOF measured 6.391 and 0.768 seconds. Corrected runs met the unchanged five-second
deadline and preserved final input while the producer remained active. Its aggregate
cleanup assertion still failed on both revisions because macOS immediately reported
an extra `PENDIN` flag; a zero-byte read settled the original termios value and
protocol restoration passed. The aggregate synthetic probe was not passing.

An earlier Chio candidate `b4b406e32f313810391c7935dda983a05629d326` passed
28 focused debug tests and the map-search PTY workflow with exact terminal
restoration using the merged dependency. These are retained focused macOS results,
not the full consumer gate for this upgrade candidate, Linux consumer proof or
private live-telemetry qualification. [Verification](../Verification.md) owns the
required adoption checks.

Separate startup and task-cancellation delays reproduced on the earlier upstream
baseline remain unresolved; incremental rendering needs separate measurement.
No internal lifecycle workaround or second focus/scroll controller is adopted.
