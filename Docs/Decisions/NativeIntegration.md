# Native integration boundaries

**Status:** Chio's operational pin uses SwiftTUI
`877d7765febd08ffc2ed434a7ef231e4132c3b80`, containing merged #58/#59/#60.
The former form and diff failures pass with
this pin; [Verification](../Verification.md#release-verification-qualification)
records the platform gates and remaining qualification boundaries.
It merged in PR #23 and is included in the 0.2.2 release scope.
The earlier 0.2.0 candidate uses merged #57 at
`7e62e95c913508f4fef42db36fde6fd60acb541c`, with passing macOS/Linux qualification.
The earlier [PR #17](https://github.com/echoz/Chio/pull/17) adopted published
0.18.0 on `main` at `7d44bd6bd85290f2c6e3526cf19e6647d551797c`, including
merged #47/#49/#50/#56.
[Dependencies](Dependencies.md#palette-and-scroll-focus-adoption) owns the current pin decision;
[0.2.2 release record](../Releases/0.2.2.md) records integrated scope and evidence.
Chio qualification remains distinct from upstream checks and earlier local-patch evidence.

Keep native ownership and visible limitations explicit when composing or extending Chio.

The new native corrections keep active palette commands visible in short terminals
and recover previously visible focused descendants through viewport geometry changes.
Explicit scrolling remains authoritative, including after later content changes.
Chio applies its existing styles and verifies those public native interactions.

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

The historical [0.17.0 rollout](Dependencies.md#0170-adoption-candidate) accepts the known
layout limitations and requires each consumer's verification. Its new native
accessibility group/button representation is a
declared contract change; direct disclosure-child overlap is a separate rendering
regression. The [local correction candidate](Dependencies.md#local-correction-candidate)
preserves those column assertions and native ownership. It also corrects an
ordinary Spacer's stretched allocation being reused as a required minimum,
restoring the compact inbox width. Neither fix is part of released 0.17.0;
both are included in 0.18.0 and retained by the current pin.

Native list focus chrome uses SwiftTUI's theme; Chio themes selected content and
controls. SwiftTUI 0.18.0 separates multiple-selection membership from the active
cursor: checked rows retain `▌`, and the active unchecked row uses `>`.
Focus checks must associate the requested label with the current native focus
region; a membership marker alone does not establish focus. Single-selection
markers retain their existing behavior. The native theme environment is not public. `StatusBar` composes a text
rule because native Divider ignores ambient foreground. Keep these upstream
limits visible without a second focus system or renderer.

## Remaining boundaries

These limits apply to the pinned implementation; none authorizes another
renderer, focus system or hidden dependency patch.

| Boundary | Current limit and responsible follow-up |
| --- | --- |
| Native style hooks | Table border/background chrome, list focus gutter, palette shell, prompt headers and disabled-editor glyph paint are not fully controlled by Chio. Keep native behavior and resolve missing hooks upstream. |
| Layout and lifecycle | Nested tab strips can receive stale width proposals; expanded disclosure focus includes descendants. Keep the documented native contracts for [scrolling](Scrolling.md#scrolling), [tabs](Tabs.md#tabs) and [disclosure](DisclosureGroups.md#expandable-groups-and-trees). |
| Choice composition | Changing choice fields inside `GeometryReader` triggered a native debug lifecycle-publication assertion. The full-window example uses `terminalSize`; arbitrary nesting remains unproved. |
| List density and focus | The 0.2.0 candidate adds merged #57 to the previous #46/#47/#56 corrections. Chio qualification of composed-row padding, pointer and style changes passes on macOS/Linux. See [dynamic spacing](#dynamic-row-spacing-candidate) and [retained qualification](#current-row-qualification). |
| Collection measurement | Native ideal-size probes can realize all rows before a bounded viewport commits and emit deferred `collection.unboundedRealization` warnings. Small fixtures do not prove virtualization or large-dataset performance; diagnostics are retained. |
| Early input | Search, palette and form handoffs cover documented type-ahead/batched paths. Arbitrary multi-control input before presentation settles needs native support, not an application-built editor or focus graph. |
| Editor navigation | End at the end of a native text field is unhandled when it makes no change, so an enclosing ScrollView can scroll to the bottom. The appearance study reproduced this at 36 × 18; ordinary editing remains focused. Its capture moves Left before End to exercise a real caret movement. Repeated no-op End is unresolved at the native input owner. |
| Cooperative shutdown | The current pin retains [merged #48](https://github.com/SwiftTUI/swift-tui/pull/48), superseding #45. Accepted quit/EOF retains final-input presentation and synchronous follow-ups without draining unrelated continuous writes. Arbitrarily expensive frames/callbacks and application producers retain their own bounds and ownership. |
| Borrowed output on macOS | Native writes leave no-SIGPIPE suppression enabled on a caller-owned descriptor. [Local investigation](#borrowed-output-policy-on-macos) confirms changed behavior for subsequent writers sharing a pipe or socket; ordinary PTY malfunction is not established. |
| Portability and accessibility | CI and pseudo-terminals cover specific workflows. Other distributions, architectures, assistive technologies and live SSH devices require separate evidence. Static Linux remains [blocked](Dependencies.md#static-linux-blocker). |

## Borrowed output policy on macOS

**Status:** Verified on the `877d7765` pin during Blackbox's 0.2.2 adoption
qualification. The user approved a local native correction and regression tests.
Local regression and full platform gates pass. Review the patch and results before
any upstream contribution; no corrected dependency pin or release exception is approved.

Darwin `terminalPlatformWrite` enables `F_SETNOSIGPIPE` before writing and does
not restore the prior value. This protection was introduced in
[`b5553d3d`](https://github.com/SwiftTUI/swift-tui/commit/b5553d3dd7a5a373ba15b32f3e03aca06cd27127)
to prevent process termination after output disconnects. Removing suppression
would reintroduce that failure.

Blackbox's retained parent PTY descriptor changes from `F_GETNOSIGPIPE == 0`
to `1` after clean child exit. Its old native pin preserves `0`. Both sessions
restore the checked terminal mode and ordinary file-status flags. This observation
does not establish broken rendering, input or ordinary shell behavior.

A separate optimized Swift 6.4 probe compiles the unchanged native platform-write
source on macOS 27. Inherited and duplicated descriptors retain the changed
policy; an independently opened PTY descriptor does not. After a native write,
a subsequent plain writer sharing that pipe or socket receives `EPIPE` without
the `SIGPIPE` observed in the control. Thus the effect is tied to shared output
ownership, not all later processes or newly opened pipes. The native write also
returns `EINVAL` when enabling the socket option after peer shutdown, before
reaching its ordinary `EPIPE` handling.

The responsible boundary is the borrowed native write operation. Raw-mode teardown
alone misses write-only hosts and process-exit output. The local correction uses
per-send `MSG_NOSIGNAL` for sockets and leaves terminal signal policy unchanged.
For pipes, a shared native-output lock protects one nonblocking write and restoration
of the original policy and status flags. Blocking hosts wait for readiness outside
that lock. Runtime, diagnostic and exit-reset writers share this mechanism through
the existing `SwiftTUIPlatformIO` target. Owned PTY and socket configuration remains
unchanged.

On base `963bfb9250dbbcd821b9cda8a21137d6f4307e28`, the new regression suite
reproduces policy leakage, changed subsequent signal behavior and the socket error.
Local native commit `c07d686e176f0116024545d6577f97f6d854a18d` passes 32 focused
release tests on macOS, including all 12 new tests. Coverage includes initial policy values `0` and `1`, duplicated
references, real concurrent native/diagnostic writers, disconnected peers, later
plain writes, backpressure, normal shutdown and process-exit restoration. Test
setup accounts for Darwin's ordinary written-file and pending-input bookkeeping;
the policy, byte and error assertions remain unchanged.

The unchanged full upstream macOS and Linux gates pass with 86 and 85 successful
steps respectively and no skipped steps. WASI cross-compilation passes with warnings
treated as errors. The full macOS gate also executes the new regression suite.
The concurrency tests exercise real schedules rather than every possible interleaving; the
backpressure handshake does not prove that the stalled writer runs first. No
restoration-failure injection is covered. Applications must keep borrowed descriptors
open and coordinate external writers or flag changes on a shared pipe. This local
candidate is not a published SwiftTUI fix or an adopted Chio dependency.

## Startup input service

**Status:** Reproduced in native SwiftTUI; correction proposed in
[PR #62](https://github.com/SwiftTUI/swift-tui/pull/62), not adopted by Chio.

A producer that continuously invalidates during startup can delay already queued
input behind sixteen initial acquisitions and one follow-up frame. A deterministic
native regression at `b23c7338` queues a key at commit 1 or 3; both cases handle it
only at commit 17. The current `877d7765` dependency has the same startup drain.

The candidate gives initial presentation its own drain policy. It preserves the
first noncancellable acquisition and synchronous appearance/focus follow-ups, then
services pending input before unrelated producer redraws. Schedulers without
callback attribution retain the existing bounded fallback. This is native runtime
work, not a Chio input owner or a longer interaction deadline.

The regression proves ordering for a controlled pulling input source. It does not
establish a wall-time limit for expensive frames or asynchronous input delivery.
[Verification](../Verification.md#startup-input-investigation) owns consumer and
platform results; an upstream candidate is not operational adoption.

## Tall list rows

**Status:** SwiftTUI 0.17.0 includes the merged per-axis reveal correction in
[PR #46](https://github.com/SwiftTUI/swift-tui/pull/46), merge
`3701604e009bc113e4c6f01b25e3d5e7aa7b00eb`. The measured-height correction in
[PR #47](https://github.com/SwiftTUI/swift-tui/pull/47) merged on 2026-10-12,
after 0.17.0, and is included in the adopted upstream revision and 0.18.0.
Chio row padding is approved within the 0.2.0 scope. The
[release record](../Releases/0.2.0.md#release-verification) owns final qualification.

`ChioStyle.Spacing.listRowVerticalInset` uses native padding around each complete
`SearchableList` or `SearchableChecklist` row. `FilePicker` inherits this through
its searchable list. The field does not change arbitrary native `List` rows:
SwiftTUI's public `ListStylePresentation` has container insets and separators,
but no per-row padding or authored-content hook. Native-list callers apply the
same value through ordinary padding. Container insets remain container insets.

SwiftTUI owns row measurement, hit regions, focus, selection and scroll reveal.
Changing styles with stable IDs can retain offscreen measurements, so qualification
must exercise growth and shrinkage after scrolling, alongside padded pointer targets.
Bounds prevent excessive individual configuration; they do not promise every row
fits every viewport. A row taller than its viewport can clip its authored content.

<a id="dynamic-row-spacing-candidate"></a>

### Dynamic row-spacing correction

The historical 0.2.0 spacing candidate exposed another native case on SwiftTUI
0.18.0.
After scrolling mixed-height rows to ID 7, increasing row padding from zero to
one makes the preceding row and focused row exceed the unchanged viewport.
The next layout omits ID 7, and native focus falls to ID 6. This occurs for both
single-selection and checklist composition, in debug and release.

On that historical pin, native `revealCollectionFocusAfterResize` observes
viewport size and visible-line changes. It does not consider changed row geometry when those
viewport properties stay equal. Deferred collection resolution can also assign
the scroll registration to a child node, while its route and focused row belong
to the collection node. The existing ownership guard then rejects recovery.

[SwiftTUI #57](https://github.com/SwiftTUI/swift-tui/pull/57), candidate
`6d9e3699dfb0a90d50a88e06bcec0f8930595d03`, extends the existing recovery path
for same-count row geometry changes and registers scroll ownership at the resolved
route's graph node. It preserves the ownership guard, newer-input priority,
graphless ambient fallback and single follow-up budget. Standalone native tests
reproduce both selection modes before the correction; 55 focused native tests
pass afterward, with independent review.

An isolated copy of Chio `f01569f` passes the unchanged new row-spacing, retained
list and appearance checks in debug and release against that candidate. The
SwiftTUI candidate's full local repository gate and all 24 upstream hosted checks
pass. Expanded focus-interaction
coverage at `0d39074a` also passes the full local gate, all hosted checks and
independent review. See
[the current evidence](../Verification.md#dynamic-row-spacing-candidate).
This is historical candidate verification, separate from final merged-pin
qualification. Chio adds no private focus or scroll workaround.

The user approved expanding #57 to correct two defects found by the broader
collection tests. Eager tables measure multiline cells but lose those heights
when placing later rows. Direct outline-list initializers provide a row tag that
duplicates the outline's automatic tag, preventing native row focus. Candidate
`ab0c305d` retains eager-table measurements and omits only that duplicate automatic
tag. It preserves public initializer signatures and authored tag diagnostics.
Hidden-update tests also cover outlines, both table paths, sectioned lists and
both lazy stack directions. These are native corrections; Chio adds no substitute
layout or focus mechanism. Local and hosted checks pass for this candidate.
The owning verification record preserves those candidate results. #57 merged on
2026-10-15 Pacific (2026-10-16 UTC) at
`7e62e95c913508f4fef42db36fde6fd60acb541c`. The user approved that exact revision
for 0.2.0; final Chio qualification passes on macOS/Linux. The published SwiftTUI 0.18.0
release lacks #57. A later 0.2.1 patch will qualify a published release containing
it. The later merged #58/#59 adoption remains outside the immutable 0.2.0 pin;
its [consumer qualification](../Verification.md#palette-and-scroll-focus-qualification)
is recorded separately.

<a id="current-row-qualification"></a>

### Historical row qualification

The original 2026-10-14 qualification uses Chio base `b79f009` and unchanged SwiftTUI
`bf9a697f2a5da4d0392730d0cba9e3ddcbbfa5d1`. The retained
`Tests/ChioTests/List/Presentation/ChioListStyleTests.swift` reproducer adds no
production seam or dependency patch. It uses native row focus, stable IDs,
selection/membership bindings and painted labels inside native focus regions.

| Public case | Original-pin macOS and Linux debug result |
| --- | --- |
| Automatic and Chio native styles, single/multiple selection, compact or uniformly padded rows | Eight cases pass all twelve rows down and back, then activation or membership checks |
| Same styles and selection modes with mixed-height rows | Four cases fail upward reversal: automatic requests ID 6 but focuses ID 5; Chio requests ID 2 but focuses ID 1 |
| SearchableChecklist, compact or uniformly padded rows | Both pass overflow, reversal, filter handoff, Space/Return toggles and retained offscreen membership |
| SearchableChecklist, mixed-height rows | Fails reversal from ID 3 to ID 2; ID 2 disappears and native focus falls to ID 1 |
| Indexed and builder lists, three padded rows at intrinsic height | Both pass height 9 and exact label lines 1, 4, 7 |
| Wrapped rows resized 32 → 18 → 32 columns with stable IDs | Focus and selection remain on ID 7; Return activates it |

IDs and raster lines are zero-based. Native journeys use twelve rows in an
eight-line list on a 32 × 12 surface; the checklist reserves fourteen lines on a
32 × 18 surface so its editor, gaps and footer leave the same list allocation.
Mixed rows contain a title plus `id % 3` detail lines, with `id % 2` lines of
vertical padding on each side. Uniform padded rows add one line on each side.
The mixed fixture therefore varies from one to five lines per row.

The historical compact checklist failure is not reproduced in this qualification.
The remaining mixed-height failure also occurs using automatic native styling,
so it is not established as a Chio padding or palette defect. Selection and focus
diverge in the single-selection failure; the five-second wait is unchanged.
The native retention correction below addresses the reproduced cause. The later
0.18.0 adoption retained all these cases; [Verification](../Verification.md#0180-adoption-qualification)
records the released-pin results. That qualification added no Chio focus/scroll
workaround or public spacing control; the later spacing correction is described above.

The table retains original-pin debug raster/hosted observations on macOS and Linux
x86_64. With adopted 0.18.0, all eighteen retained cases pass in debug and release
on both platforms in [run 38694392124](https://github.com/echoz/Chio/actions/runs/38694392124).
macOS passed after one unchanged retry following the documented tab-focus timeout;
its cause remains unproved. This does not establish live SSH/PTY tall-row behavior,
pointer interaction or comprehensive resize/style-change coverage.
[Verification](../Verification.md#list-row-spacing-qualification)
owns the reproducer command and remaining gates.

### Worker-snapshot retention correction

[SwiftTUI PR #56](https://github.com/SwiftTUI/swift-tui/pull/56), candidate
`0aadc0e392a29717f1016321b223ab5ad66595bc`, corrects the reproduced native
cause. The cancellable hosted renderer measures worker snapshots but retains the
live canonical indexed sources. An obsolete safety check rejects those previous
sources before comparing their now-immutable, nonisolated measurement signatures.
In the reproduced live-to-snapshot path, subsequent hosted frames therefore
discard previously measured row heights.

On upward reversal, reveal can count a preceding tall row as one cell and choose
it as context. Measuring that row again consumes the viewport, excludes the
requested target and causes native focus to fall back. Retaining the valid heights
corrects that decision without another reveal pass or changes to focus ownership.
The same obsolete guard affects lazy-stack prefix measurements and is removed
there too. Axis, membership and count checks remain; neither path realizes
previous-source children on a worker.

The native hosted regression fails at the same automatic-style reverse step
before the correction and passes afterwards. A lazy-stack regression independently
checks that seven already-scrolled one-cell rows remain one cell across the
live-to-snapshot transition. Forty-six focused native tests and configured hooks
pass on macOS; separate review reports no actionable findings. Chio's eighteen
unchanged qualification cases also pass in debug and release against the explicit
local candidate dependency. [Verification](../Verification.md#list-row-spacing-qualification)
records remaining gates. This local-candidate evidence predates release adoption
and does not qualify a new density API. All upstream hosted checks subsequently
passed; #56 merged as `bf2faa8ff6aaddb89cae8bc035a781ddbc672c84` and is included
in published 0.18.0. Chio's completed
[released-pin qualification](../Verification.md#0180-adoption-qualification)
remains separate from these local-candidate results.

### Historical baseline

The investigation below describes earlier pins and candidates. Its failure
table is historical evidence, distinct from the current qualification above.
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
was based on PR #46 while PR #47 was draft. The reviewed candidate below was
rebased onto 0.17.0 before the maintainer's final changes. Layout publishes measured row geometry and
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
The reviewed rebased PR #47 head was `fbcb8873c8df3aa66ee155afb820e10966f55bfe`;
that reviewed head passed upstream CI. A subsequent maintainer revision was
approved and merged, with a PTY test flake addressed separately in #51. None of
this establishes Chio adoption of the measured-height correction.

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
`ee572e38487284092f367ef5b095460a04374ba3`, and retained by the current pin.

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
