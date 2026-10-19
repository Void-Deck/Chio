# Chio verification

Current requirements for implementation, dependency and visible example changes.
[Plan](Plan.md) tracks active work; [release records](Releases/0.2.0.md) preserve
revision-specific results. For documentation-only changes, check links, anchors
and preservation of current contracts.

## Shared engineering rules

Chio pins [EngineeringRules v0.1.7](https://github.com/echoz/EngineeringRules/releases/tag/v0.1.7)
(`4dd986441275fa768709887eaa0952218057397e`) through
[.swift-rules.json](../.swift-rules.json). This is a required local development
gate alongside the compiler, tests and platform checks below. It is not a package
dependency or a guarantee of purity, correct enum policy or API compatibility.

Install the pinned tool from its repository using its README. Prepare the released
documentation checker's hash-pinned Python dependencies in a clean release
checkout's `.build/docs-venv`. Several projects can share that immutable checkout
and environment; do not change a shared development checkout for this purpose.
On this Mac, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/ci/check-rules.sh /path/to/immutable/EngineeringRules-0.1.7
```

Full Xcode supplies the required Swift/SourceKit. On Linux, omit `DEVELOPER_DIR`
and follow the pinned tool's Swift 6.4 and Ubuntu Noble requirements. The normal
gate does not install tools or edit source, configuration or baselines; a missing
pinned installation is a failed prerequisite. It verifies the release commit,
exports the documentation checker and compiler-context helper from that immutable
revision, runs the documentation gate with the prepared Python environment, builds
the actual `Chio` target with SwiftPM's native backend, and supplies its real
compiler arguments to the checker. The shared checker implementations stay in
EngineeringRules; Chio does not copy or maintain them. The documentation checker
requires exactly `markdown-it-py` 3.0.0 and `mdurl` 0.1.2. Missing or different
parser dependencies fail before the native build; normal checking never installs
packages or fetches the tool.

Generated build settings and compiler context stay under ignored
`.build/swift-rules`. The gate removes the old context before rebuilding; a build,
export or compiler-analysis failure cannot fall back to syntax-only success.
The repository configuration also requires that context for a direct checker
invocation. Run the script after source, dependency or toolchain changes instead
of reusing a prior build description. Witness evidence covers the supplied
platform and build configuration; it does not prove other conditional branches.
Swift 6.4 warns that the native backend is deprecated. This pinned exporter
requires its build description; support for a different backend belongs in the
shared tool rather than a guessed set of compiler flags in Chio.

The gate scans all retained Swift files in `Sources`, `Examples` and `Tests`,
with no path exclusions and explicit target import allowlists. Its production
layout and file-scope checks apply to `Sources`. The explicit
`componentFirstTargets: ["Chio"]` setting checks component/responsibility order
and selects the nested `Domain` groups for immutability and direct-effect checks.
Other targets retain the default responsibility-first layout. Moving files only
translates their existing baseline paths; anchors, rules, counts and reasons stay
unchanged. Those production rules cannot
target `Examples`, whose syntax, constructors, ternaries, imports and selected
SwiftLint rules are still checked. Tests receive the latter checks too. Extend
the configuration when introducing retained source roots such as new spikes;
empty local directories and `Package.swift` are not scanned by this version.

The [.swift-rules-baseline.json](../.swift-rules-baseline.json) retains one
reviewed exception, with its exact path, source anchor and occurrence count.
`MapShapeSimplification.Budget.remaining` is invocation-owned, private scratch
storage passed `inout` through bounded geometry work. Its local mutation is an
intentional exception to the checker's lexical stored-property rule; public
domain inputs remain immutable. Preserve its work and cancellation bounds.

The test suites now spell out all 395 formerly baselined constructor calls.
Their fixture values, assertions and interaction deadlines are unchanged. The
316 resolved baseline entries are removed; ordinary initializer delegation and
enum-case shorthand remain valid. Historical adoption results below describe
their original candidates, before this cleanup.

New findings and stale baseline entries fail the check. Baseline expansion,
exclusions and tool upgrades require review; do not regenerate the baseline to
silence failures. Inspect rule categories for checker limitations before changing
application behavior. The shared tool owns rule implementations.

EngineeringRules is private. This local gate does not add credentials or a private
fetch to Chio's public CI or package build. Hosted lint requires a separate tool
distribution/access decision; the public platform gate below remains required.

### Documentation coverage

[.documentation-rules.json](../.documentation-rules.json) uses schema 2. Its
existing eight module mappings under `Sources`, `Examples`, `Tests` and `Spikes`
remain unchanged, with no exclusions. They link Design, Examples, Verification
and the routing spike guide. Current decisions, release guidance and map fixture
provenance remain enrolled.

The deliverable inventory adds twenty source-root guides: the Chio library,
its sixteen public views, both example applications and the static showcase.
Each view has a distinct real source root and its own `README.md`; the library
is its declared parent. The [library guide](../Sources/Chio/README.md) links those
views, and [source ownership](Design.md#source-ownership) explains their boundaries.
The gate checks 56 unique documents, eight modules and twenty deliverables.

Schema 2 rejects duplicate roots, invalid parents, missing or blank READMEs,
symlinks and invalid local Markdown file destinations. Module discovery still
covers immediate children only; linked documents are not enrolled recursively.
The checker cannot establish complete public-view coverage, actual source ownership
or useful documentation. Review those facts against the public API and supported
products, including new views. Internal helpers may share their owner's guide.

Heading fragments, HTML, external URLs, prose accuracy and browser behavior remain
outside the gate. Check relevant anchors manually and keep site verification
where visible output changes. The source README is excluded from assembled Pages
output; SwiftPM excludes source guides from build inputs without excluding code.

### 0.1.7 adoption

The published stable release resolves to
`4dd986441275fa768709887eaa0952218057397e`. The SwiftRules pin and wrapper's
explicit source revision advance together from 0.1.5 on the default branch,
superseding the pending 0.1.6 update in [PR #21](https://github.com/echoz/Chio/pull/21).
Both documentation checking and compiler-context export use the verified release.

This adoption adds schema 2 enforcement and source-root guides. Seven public views
leave shared family roots; their source, supporting values and focused tests move
without content changes. Component-first depth, public identifiers, imports,
behavior, application dependencies and the single reviewed baseline exception stay
unchanged. [PR #20](https://github.com/echoz/Chio/pull/20) already removed the
constructor debt and is included in the base.

The user-wide engineering-review skill covers deliverable inventory completeness,
source ownership and README quality. Use the installed skill without copying it
into Chio. Keep this PR draft until the pinned gate, applicable platform checks
and independent review pass. Publication of EngineeringRules does not itself
establish Chio default-branch adoption.

### 0.1.5 adoption

The user requires this adoption before cutting Chio 0.2.0. The published stable
target resolves to `d777c8ccbe990a8e90462c928042574d9dbe9d53`; it retains 0.1.4's
Swift rules and adds the separate documentation gate. The prior Swift baseline
and source scopes remain unchanged.

On macOS arm64 with Swift 6.4 and full Xcode, the complete wrapper passes:
36 documents across eight modules, an actual native Chio build and compiler-context
export, and 350 Swift files with no new violations and 396 baseline findings.
Compiler witness analysis passes. Real-wrapper checks reject a missing Python
environment, missing parser, wrong parser version and wrong release commit; each
failure removes stale compiler evidence. The initial sandboxed build could not
write its compiler cache; the authorized normal-cache run passes.

This is developer-tool qualification. Application source, package dependencies,
tests, the public CI workflow and its verification script are unchanged. The
release record owns application-platform qualification. A passing macOS wrapper
does not establish Linux execution of the private checker. Independent review reports no actionable findings.
[PR #19](https://github.com/echoz/Chio/pull/19) merged into the release branch at
`af6cb3664e9609716fd7b3594dfb3f9959073972`, whose tree matches the reviewed
`8ce64608ac96c022609947757428e75c92c1a689` candidate. Default-branch delivery and
0.2.0 publication remain with release PR #18. After integrating the release
documents and recordings, the complete wrapper passes again with the same
36 documents, eight modules, 350 Swift files and 396 baseline findings.

<a id="014-adoption-candidate"></a>

### 0.1.4 adoption

On 2026-10-12, authenticated published release metadata resolved the stable target
[EngineeringRules v0.1.4](https://github.com/echoz/EngineeringRules/releases/tag/v0.1.4)
to `fc3de546794e7e4b0429b0b03e282ac7218bde8b`. The focused adoption starts from
`d940d56`; its source-only check reports 86 placement/order diagnostics across
57 production files. The change keeps synthesis, visibility, actor isolation,
initialization and serialized representations intact. Private nested types that
cannot be named from a file-scope extension retain their language exception.
The existing baseline must not expand.

The macOS and Linux arm64 debug compiler-backed gates pass over all 122 Swift
production files; the complete source check covers 332 Swift files. The 329
baseline entries remain byte-identical and account for 414 tracked findings.
Independent source and gate review reports no actionable findings.

The unchanged macOS and Linux arm64 gates report exactly the accepted 16 SwiftTUI
issues: three disclosure assertions and 13 compact-inbox/tree issues. Debug runs
cover 482 library tests on macOS and 481 on Linux, 157 map tests on each platform,
and 146 dashboard tests. Both scripts exit 1 before release and terminal stages.
Separate full release runs cover the same library/map counts and 176 dashboard
tests, with the same 16 issues and no additional failures. All map tests pass.

Separate release builds and 24 snapshot commands succeed on each platform.
Fifteen dashboard PTY modes and all three appearance workflows pass; the tree
mode fails waiting for `SearchableList.swift`, matching the accepted missing-child
layout defect. Offline maps, forward/reverse search, local online acquisition,
cache and pack process probes pass on both platforms. Linux search additionally
passes all three themes. These are local fixture checks, not live-provider or
SSH qualification; snapshots are inspection artifacts. No assertions, deadlines,
dependency pins, test files or baseline entries changed.

The complete gate is not green. The user approved adoption with these previously
accepted native limitations. [PR #15](https://github.com/echoz/Chio/pull/15) merged
on 2026-10-13 at `38fc258`, whose tree matches the reviewed `14edf069` candidate.
Its [hosted macOS/Linux checks](https://github.com/echoz/Chio/actions/runs/38510440943)
also report only the same 16 issues, with all 157 map tests passing. This records
default-branch adoption of the tool, not a new Chio release or repaired native layouts.

## Palette and scroll-focus qualification

The adoption candidate pins SwiftTUI
`13c07f3981e0bb9160f8dfc8939ffa085824b340`, containing merged #58 and #59.
Other dependency revisions remain unchanged. Earlier Chio and upstream results
do not qualify this new combination.

Qualification covers public-hosted palette navigation at short heights, focused
scroll descendants through height changes, and deliberate scrolling followed by
content changes. Retained list-row, search, appearance and dashboard workflows
remain required, with the existing debug/release split and five-second waits.
Local macOS checks use Apple Swift 6.4 and full Xcode. The library builds. The
full consumer gate passes its 19 library HTTP and six map preflight tests, then
stops during debug tests. All 166 map tests pass. Of 509 library tests, the
retained disabled-membership test fails because native focus now skips disabled
rows. The dashboard reports two grouped-form failures and an outdated viewport
origin expectation. Release suites and later terminal/map stages are not reached.

Focused checks pass native list navigation, palette visibility, selected search
and appearance workflows, and scroll input/recovery. Corrected scroll tests now
expect both axes at Home/End and leading-edge preservation for oversized content.
The updated hosted viewport workflow passes; its corresponding PTY expectations
still need release verification. Pointer coverage verifies that clicking a disabled
row retains the enabled row's focus and does not activate the disabled row.

The new descendant-focus regression fails on the prior `7e62e95c` pin after
shrinking the viewport and passes on `13c07f39`. The short-height palette test
passes on both pins and is compatibility coverage, not evidence of a prior defect.

Both grouped-form workflows pass unchanged against `7e62e95c`. On `13c07f39`,
the isolated ordered-validation workflow fails to reveal the invalid field's
error. Temporary diagnostics show that the focus-change callback receives the new
field while a direct `@FocusState` read returns `nil`. These diagnostics are not
retained in production. Preserve the complete-error visibility contract.
A temporary native patch that retains the authored owner for `onChange` callbacks
passes all five unchanged grouped-form tests, including nine layout cases.
The dependency source is restored after this experiment. This result does not
qualify the unmodified pin or replace native regression tests and upstream review.

The pinned EngineeringRules 0.1.7 compiler/documentation gate and static-site
assembly pass. The gate reports no new violations and retains one reviewed
baseline exception. Independent source review identified the disabled-row policy
conflict and a search handoff risk when all visible results are disabled; readiness
review remains incomplete.

Real PTY captures compare the same paused 100-by-30 dashboard on old/new pins in
indexed and true-color modes. New indexed output uses the corrected native color
quantization; authored true-color values remain identical. Both previews are
inspected through the vendored terminal player, and terminal restoration passes.
This does not establish live Blink/Ghostty SSH behavior or qualify release binaries.

The upgrade remains a draft candidate. Complete local/platform gates, release
terminal checks, external-consumer installation and final independent review are
still required. The accepted disabled-row policy remains unchanged pending the
user's decision; no workaround for the form regression ships in this candidate.

## Merged layout corrections

**Status:** Delivered in [PR #16](https://github.com/echoz/Chio/pull/16), merged
on 2026-10-14 at `b79f0096fbc19872bd91cc887b03048e7e9d2a47`. Its tree matches the
verified `0d42bfd41a0316c85c95fbb520641df3785f6eb5` candidate. The complete hosted
[run 38546312684](https://github.com/echoz/Chio/actions/runs/38546312684) passes
on macOS and Linux x86_64, including debug/release suites, release products,
snapshots, dashboard/map terminal workflows, appearance checks and map process
probes. All sixteen original layout failures are resolved. The final local
compiler-backed SwiftRules 0.1.4 gate passes with 351 files and 398 retained
baseline findings; independent review reports no actionable findings.
These results qualify that candidate and its identical merged tree, not a tagged
Chio release, static Linux distribution or downstream application adoption.

The earlier runs below preserve failure and diagnostic evidence. They do not
represent the final merged candidate's gate status. The historical intermittent
tab failures passed the final hosted gate; their cause remains unproved.

The 2026-10-14 candidate pins SwiftTUI
`bf9a697f2a5da4d0392730d0cba9e3ddcbbfa5d1`, with explicit approval to use this
unreleased upstream revision after verification. Only the SwiftTUI revision and
manifest hash change in the lockfile. Qualification uses the complete gate
below under the existing verification policy, retaining all 16 previously accepted failing assertions and the
five-second interaction waits. Scroll-style expectations migrate to the corrected
vertical focus reveal: the first row stays visible. Mouse release moves to the
track midpoint so that it still verifies a real offset change. All other keyboard,
wheel, drag, theme and resize assertions remain exact; the automatic style checks
the same native behavior. The viewport example and its terminal probe retain
the same first-row contract on initial focus and F6 restoration. Twelve constructor spellings in the two
touched suites are made explicit, removing exactly seven baseline entries
covering twelve findings.
No passing outcome is implied by the dependency change; platform results must
identify the tested tree.

Before the change, PR #16's hosted run at `95d80ae` reports the accepted 16 issues
on each platform, plus a Linux map-search timeout and three macOS tab/appearance
timeouts. The map trace records a native results-list focus callback but no
subsequent delivered frame in the timeout snapshot. Its event clock does not
record the wait start/deadline, so it cannot prove a lost request or a precise
deadline race. Twenty separate unchanged macOS tab-test launches pass locally;
that bounded result does not explain the hosted failures.

At candidate `42a72856`, complete local macOS and Linux ARM64 gates pass,
including debug/release suites, terminal workflows, appearance checks and map
process probes. Compiler-backed SwiftRules passes on both platforms with 351
files and 402 baseline findings. The [hosted candidate run](https://github.com/echoz/Chio/actions/runs/38531964141)
resolves all sixteen layout issues on both platforms. macOS's debug tab activation
case still times out after Return; map and dashboard targets pass. Release and
terminal checks are not reached on that platform. Linux x86_64 passes every debug
and release test, the dashboard build, 24 snapshots and eleven terminal workflows;
the duration example then remains at `0:00 Running` during its fifteen-second
advancement check. Later terminal and map process checks are not reached there.
That earlier candidate remained draft while the remaining failures were addressed.

The library recorder retains up to 64 lazily formatted observations of wait
start, deadline-task start, frame delivery, match and timeout. The tab workflow
also observes public native focus and runtime issues. These diagnostics preserve
input, predicates and five-second waits. Fifty bounded local tab launches pass
without reproducing the hosted failure; that is not evidence of its resolution.

The map recorder also retains exact wait deadlines, matches and timeout
observations. A results-list focus callback follows native frame submission;
its presence without a delivered frame does not establish a lost focus request.
The example now publishes accepted results, selection and desired native focus
together, avoiding an intermediate results frame that still focuses the editor.
Forward/reopen and reverse regressions inspect the first accepted-results frame.
The forward checks fail before the correction. Initial/preloaded response,
current-phase, dismissal and batched-input coverage remain in place, as do all
five-second waits and the existing debug/release verification policy.

The duration failure reproduces with the unchanged executable on macOS when
`CI=1`; the same binary passes the complete duration workflow with `CI=0`.
SwiftTUI's CLI intentionally suppresses animation timelines under CI's stable-output
policy. The example now composes a native periodic schedule that continues
functional clock updates under reduced motion and emits no entries while idle.
The existing live-timeline test also runs with reduced motion enabled and fails
before this correction. Its five-second wait and the fifteen-second terminal
advancement assertion remain unchanged. Four constructor spellings in that suite
are made explicit, removing exactly three additional baseline entries.

## Dynamic row-spacing candidate

The 0.2.0 candidate `f01569f896b47732da17cc35d5e068b664938c7e` removes the legacy
theme APIs and adds bounded `Spacing.listRowVerticalInset`. On unchanged SwiftTUI 0.18.0,
macOS debug and release each pass fifteen of seventeen new `ListRowSpacingTests`
cases. Both mixed-height dynamic-spacing cases fail: growing the row padding
after scrolling moves native focus from ID 7 to ID 6. Assertions and five-second
waits remain unchanged. These are historical results before adoption of the
merged native correction; they do not describe the current dependency pin.

Passing cases cover intrinsic row positions at 0, 1 and 32 cells, composed row
geometry and selection paint, maximum-inset clipping, wrapped-row style changes,
padded pointer targets, adjacent padding boundaries after scrolling, and disabled
checklist membership. The eighteen existing list qualification cases pass in both
configurations. Style value/presentation checks and release appearance workflows
also pass; nine focused appearance geometry cases pass in debug.

Pinned SwiftRules 0.1.4 reports no new violations across 350 files, with 396
retained baseline findings. This is focused local evidence, not a complete
macOS/Linux gate or complete showcase qualification.

The candidate's [hosted macOS and Linux gate](https://github.com/echoz/Chio/actions/runs/38711402499)
reproduces exactly the same two focus failures on each platform. macOS runs 507
library tests and Linux runs 506, each with two issues. All 166 map and 147
dashboard tests pass on both platforms. All eighteen retained library list cases pass.
Both gates stop before release, terminal and process stages. The tested merge is
`671a4903bc2cc504dabbb10173af5b5d1d9d4128`.
The separate [demo-site build](https://github.com/echoz/Chio/actions/runs/38711402835)
passes for the same candidate.

The capture-only follow-up `2bd8895e` has the same two failures on both platforms
in [run 38754370083](https://github.com/echoz/Chio/actions/runs/38754370083).
Library, map and dashboard totals are unchanged; all eighteen retained list cases
pass, and release and later stages are not reached. The tested merge is
`3af6f8cfbb1f256e5a551797dd4f2f301901efc1`. Its separate
[demo-site build](https://github.com/echoz/Chio/actions/runs/38754370086) passes.

The candidate release binary refreshes all six appearance recordings/previews
and the tree recording with default/light/btop previews. All nine terminal
sessions pass their existing restoration checks. Appearance retains one native
`collection.unboundedRealization` warning per four-row session after teardown;
tree sessions report no diagnostics. All nine previews are inspected and the
site assembles. Capture-only child environments disable the browser companion.
Published clips omit only the exact known reader notice before the first ANSI
control; unknown startup output fails. All ANSI setup bytes and timestamps remain,
and full raw logs retain the original output and teardown warnings. Nine regenerated
PNG previews are byte-identical to the earlier previews. Safari verifies style/size
selection, matching commands, preview rendering, clean playback startup, seeking
and return to previews. These are focused checks of refreshed media and existing
controls; unchanged responsive and fallback behavior retains its earlier evidence.
The captures use the unchanged SwiftTUI 0.18.0 pin, not the proposed native fix.

A separate macOS consumer resolves this Chio candidate and matching SwiftTUI
revision from GitHub. Build, linking and noninteractive execution pass canonical
style inheritance, row-spacing raster positions, retained duration behavior,
map values/rendering and instrumentation construction. Its fresh transitive graph
differs from the producer lockfile, as recorded in the release notes. This does
not exercise the failing dynamic focus journeys.

[SwiftTUI #57](https://github.com/SwiftTUI/swift-tui/pull/57), candidate
`6d9e3699dfb0a90d50a88e06bcec0f8930595d03`, corrects row-geometry recovery and
scroll-registration ownership. Its 55 focused native tests and separate review
pass. An isolated Chio `f01569f` copy uses that frozen source without changing
the repository pin. All seventeen new row-spacing cases, eighteen retained list
cases and appearance checks pass in debug and release. Debug takes 126.402 seconds;
release library and appearance groups take 12.478 and 6.331 seconds respectively.

The isolated release attempt with SwiftPM's deprecated native backend built but
launched the dashboard instead of the test runner; no tests ran in that attempt.
The normal project backend passes the same tests in a fresh scratch directory.
At `6d9e3699`, the unmodified native repository gate passes all 85 steps locally.
All 24 hosted checks also pass, including [Repo Gate](https://github.com/SwiftTUI/swift-tui/actions/runs/38713220425),
[macOS](https://github.com/SwiftTUI/swift-tui/actions/runs/38713220609),
[Windows](https://github.com/SwiftTUI/swift-tui/actions/runs/38713220514),
[release soundness](https://github.com/SwiftTUI/swift-tui/actions/runs/38713220517),
API baseline and performance. Hosted checks test merge
`357a6f74d1579b9710856251b185dddc7c8cd13d` against base SwiftTUI 0.18.0.
Expanded tests at `0d39074a9c61c9f888fb2e20dd037bf44c09fbea` pass 38 focused
test functions across five suites. Parameterized cases include 26 geometry/anchor
combinations and four registration/replay ownership combinations. The final
clear-focus case passes separately after narrowing its claim to host-refresh
stability. Independent review has no remaining findings. New coverage checks
first committed spacing-change frames, repeated navigation and activation,
sibling controls, explicit requests, viewport changes, oversized rows, equal-total
height redistribution, and live-target consistency after removal or replacement.
The production fix is unchanged. At `0d39074a`, the unmodified native local gate
passes all 85 steps, with no failures or skips. All 24 checks across six fresh
hosted workflows also pass: [Repo Gate](https://github.com/SwiftTUI/swift-tui/actions/runs/38753800354),
[macOS](https://github.com/SwiftTUI/swift-tui/actions/runs/38753800252),
[Windows](https://github.com/SwiftTUI/swift-tui/actions/runs/38753800386),
[release soundness](https://github.com/SwiftTUI/swift-tui/actions/runs/38753800294),
[API baseline](https://github.com/SwiftTUI/swift-tui/actions/runs/38753800255) and
[TermUIPerf](https://github.com/SwiftTUI/swift-tui/actions/runs/38753800350).
These checks test merge `d328c5042e3dd8d428384916af490030cb4ad1b7` against
base SwiftTUI 0.18.0. Linux and macOS logs confirm both expanded runtime suites
execute successfully.
At that candidate checkpoint, upstream acceptance and dependency adoption were pending.

The user approved expanding #57 after the collection audit found two more native
defects. Candidate `ab0c305d1e204835b189c9aaf4ac9ff3157d1a1b` retains measured
eager-table row geometry and removes the duplicate automatic selection tag from
direct outline-list initializers. Public initializer signatures and authored
ambiguity diagnostics remain unchanged.

New native journeys realize rows, hide them, change their content and size, then
reveal and revisit them. They cover indexed, builder and sectioned lists;
indexed and eager tables; composed outlines; and both lazy stack directions.
Assertions distinguish focus, selection, membership, visible content and current
action handlers. Eight direct outline-list initializer cases check native row
navigation. Additional cases inspect first committed frames, collapsed or removed
targets, disabled controls and bounded table chrome. Lazy
control traversal is checked after realization; no implicit offscreen Tab reveal
or new focus fallback policy is claimed.

Focused hidden-update checks pass at `f87e881e`. Its full gate exposed a compact
eager-table indicator regression. The corrected `ab0c305d` preserves one arrow
when only two body cells remain. Forty-one test functions across four suites pass,
including the unchanged stress regression and eight viewport/indicator cases.
Independent source review has no remaining findings. The unmodified native
repository gate passes all 85 steps locally at `ab0c305d`, with no failures or
skips. All 24 checks across six fresh hosted workflows also pass:
[Repo Gate](https://github.com/SwiftTUI/swift-tui/actions/runs/38772809564),
[macOS](https://github.com/SwiftTUI/swift-tui/actions/runs/38772808906),
[Windows](https://github.com/SwiftTUI/swift-tui/actions/runs/38772809145),
[release soundness](https://github.com/SwiftTUI/swift-tui/actions/runs/38772808912),
[API baseline](https://github.com/SwiftTUI/swift-tui/actions/runs/38772809495) and
[TermUIPerf](https://github.com/SwiftTUI/swift-tui/actions/runs/38772808991).
These checks test merge `82390adf9e29fdc716791ed6b390760f1856eccd`, with exact
parents SwiftTUI 0.18.0 (`4791281a`) and candidate `ab0c305d`.
Logs confirm that all five collection-update suites execute and pass on Linux,
macOS, Windows arm64 and Windows amd64, including release execution on Linux.
The unchanged compact-table stress regression also passes. Upstream acceptance
and dependency adoption were pending at that checkpoint.

An isolated Chio `6dc974e5` copy passes the unchanged 35 list cases and
22 appearance cases in both debug and release against `ab0c305d`.
These are 14 test functions across three suites, with no failures.
The runs use official Swift 6.4, the normal SwiftPM backend and full Xcode on
macOS arm64. Source provenance is checked before and after execution; only the
isolated dependency manifest and lockfile differ. Other resolved dependency
revisions remain unchanged. This establishes focused consumer integration, not
complete Chio platform or live-terminal qualification.
That isolated check did not change Chio's then-current SwiftTUI 0.18.0 pin.

## 0.2.0 merged-pin qualification

The release candidate now pins merged SwiftTUI #57 at
`7e62e95c913508f4fef42db36fde6fd60acb541c`. Its source tree matches the final
upstream candidate `8408901e1b8703fcf046eaaf16722fc4d920f4a7`. Other dependency
revisions and the existing assertions, deadlines and verification policy remain
unchanged. SwiftTUI #58 and #59 are separate follow-ups outside this pin.

Chio code candidate `40b5d8c2da40bda2640758ceacb30a76bc7caa2a` passes the complete
local gate on macOS arm64 with official Swift 6.4 and full Xcode. Debug runs pass
507 library, 166 map and 147 example tests. Release runs pass 507 library,
166 map and 177 example tests. The gate also passes both release products,
24 snapshot commands, 16 dashboard terminal workflows, all three compact
appearance sessions, map fixture verification, offline/search/routing/online
terminal journeys, and the real-process persistent-cache and offline-pack probes.
Online checks use retained bytes over loopback, not a public provider.

Compiler-backed SwiftRules 0.1.4 checks 350 files with no new violations and
396 retained baseline findings. Separate read-only source/API/test review has
no actionable findings. Source, tests, dependency revisions, assertions and
deadlines remain unchanged during the final documentation and media refresh.

A fresh external consumer resolves, builds, links and runs against the immutable
Chio code candidate and again against combined candidate
`bdd9fcd93f7e44d058bcb7075a8bf0ee1e3c8cab`, with the matching SwiftTUI revision.
It checks custom views,
inherited `ChioStyle`, canonical APIs, duration formatting and initializer
references, checked list-row spacing and raster positions, map values and a
no-source map raster, and instrumentation construction. Its fresh resolution
selects Collections 1.7.3; Chio's retained lockfile still uses 1.7.2. This is
noninteractive public-API installation evidence, not a live terminal or service test.

All six appearance recordings were refreshed from a release build of the same
code candidate at 100 × 30 and 36 × 64. The later product-build stage relinks the
executable; capture evidence retains its own binary digest. Each session passes
clean exit, termios restoration,
cursor restoration and alternate-screen restoration. Their initial PNG previews
are byte-identical to the retained previews and pass visual inspection. Each raw
session retains one native `collection.unboundedRealization` diagnostic for the
four-row fixture after teardown; published clips omit that diagnostic and startup
announcements. This does not establish large-collection performance.

Site assembly passes. Safari checks confirm matching appearance choices,
commands and previews, clean playback of refreshed wide btop and narrow OpenCode
clips, and the main catalog's btop map selection. Site implementation is unchanged;
earlier six-clip, responsive-layout and asset-fallback checks remain applicable.
Final documentation/media review passes, including 246 local links and 96
Markdown fragments. Published-site and immutable-tag verification follow release
acceptance.

The first hosted [run](https://github.com/echoz/Chio/actions/runs/38929764539) tests
merge `6513fbbcf7c53f15fc6cebf6b90c362f4cfae559`, with base `7d44bd6` and head
`40b5d8c`. macOS passes the complete gate with the same test counts above.
Linux passes 506 library, 166 map and 147 example tests in debug; release passes
506 library, 166 map and 177 example tests. All dashboard and appearance terminal
checks pass. The offline-map probe continues progressing when the 60-minute job
limit cancels it. Later map search, routing, HTTP, cache and pack probes do not
run. No assertion failure or stalled probe is observed; this is incomplete Linux
qualification, not a passing platform gate.

The release candidate increases only the overall Linux job limit to 90 minutes.
Builds and tests account for the elapsed time; assertions, individual interaction
deadlines, verification stages and macOS limits stay unchanged.
The complete combined [hosted run](https://github.com/echoz/Chio/actions/runs/38938281033)
passes on macOS and Linux. It tests merge
`dc2b03e41992660d1ced5ff96c6aca96f0439442`, with base
`7d44bd6bd85290f2c6e3526cf19e6647d551797c` and head
`bdd9fcd93f7e44d058bcb7075a8bf0ee1e3c8cab`. EngineeringRules 0.1.5 is included;
its integrated local wrapper passes separately, with the same baseline.
macOS completes in 45 minutes 52 seconds and Linux in 58 minutes 49 seconds.
Both pass the same platform-specific test counts recorded above and every
terminal/process stage, including map search, routing, HTTP loading, persistent
cache and offline packs. The completed Linux gate replaces the earlier partial
platform evidence without erasing that timeout.
The [site build](https://github.com/echoz/Chio/actions/runs/38938281006) also passes.
Final changes reconcile release status in documentation only; unchanged source,
test, dependency, workflow and capture evidence remains applicable.

## List row spacing qualification

**Original-pin result:** BLOCKED. The added `ChioListStyleTests` qualification suite uses the
public raster and hosted-session APIs against the former SwiftTUI revision
`bf9a697f2a5da4d0392730d0cba9e3ddcbbfa5d1`. Compact and uniformly padded native
single/multiple-selection journeys and searchable-checklist journeys pass on
macOS debug. Both indexed and builder intrinsic padded placement pass; one
wrapped same-ID resize journey preserves focus and activation.

Four native mixed-height cases and the mixed-height checklist case fail while
reversing upward. The requested label disappears and native focus moves to a
different row; single-selection bindings still identify the requested row.
The new failing assertions remain enabled, with the existing five-second wait.
This is an incomplete qualification candidate, not a passing application gate.
[Native integration](Decisions/NativeIntegration.md#current-row-qualification)
records the fixture and exact failure points.

The final integrated macOS debug run completes all four parameterized test
functions with exactly five issues: the four native mixed-row cases and the
mixed checklist case. SwiftRules 0.1.4 passes for 352 files with the same 398
baseline findings. Separate review finds no actionable issue in the reproducer
or its documented evidence limits. These checks validate the diagnosis artifact;
they do not make the feature ready to ship.

The hosted [run 38637395321](https://github.com/echoz/Chio/actions/runs/38637395321)
confirms the same five failures on macOS and Linux x86_64. It tests PR #17 head
`6c1556a42bb621a03e210232ed59bd81bb03ba57` through merge commit
`e04aa8230b40e3fb7bf841ed17e630020c2877f4`. Both platforms pass the map transport
and online-lifecycle preflight; the other map and dashboard test executables
also pass. The failing debug gate prevents release, product, snapshot, terminal
and map-process checks from running. This is platform reproduction of the
blocker, not a new failure in those later checks.

The isolated [SwiftTUI #56](https://github.com/SwiftTUI/swift-tui/pull/56)
candidate `0aadc0e392a29717f1016321b223ab5ad66595bc` passes all eighteen
unchanged Chio qualification cases in macOS debug (49.162 seconds) and release
(8.155 seconds) through an explicit temporary local-package dependency. The
manifest and lockfile are restored after this qualification; the candidate is
not adopted by the committed package.
Native regressions fail before the respective corrections; 46 focused native
tests, configured hooks and separate review pass. After restoring the original
pin, Chio's SwiftRules 0.1.4 gate passes again for 352 files with the same 398
baseline findings. The full native `bun run test` gate also passes on macOS at
that candidate, including all three runtime shards, platform suites, performance
tests and soundness checks. All upstream hosted checks subsequently pass; #56 is
merged and included in 0.18.0. These native and local-candidate checks do not
establish Chio adoption, a full consumer gate, or live terminal behavior.

Run the focused reproducer with the platform/toolchain setup below:

```sh
swift test --force-resolved-versions --jobs 2 --no-parallel --filter ChioListStyleTests
```

No new spacing API or showcase assets are qualified. The released-pin qualification
below addresses the original-pin blocker for dependency adoption only. Pointer
and broader style-change checks remain required before a new density field.
The completed #16 gates cover their exact merged tree; they do not cover these
new qualification cases. Native interaction ownership, assertions and deadlines
remain intact.

### 0.18.0 adoption qualification

The candidate pins published [SwiftTUI 0.18.0](https://github.com/SwiftTUI/swift-tui/releases/tag/0.18.0)
at `4791281a55e5bbdb683718a7282afd10c2f5e42c`. Release metadata and Git ancestry
confirm that it contains the previous operational pin and merged #56. Upstream
manifest and lockfile comparisons are unchanged; Chio's lockfile changes only
SwiftTUI's revision and the root manifest hash. Chio production source, the eighteen
list qualification cases, viewports, deadlines and CI policy remain unchanged.

The first released-pin macOS gate passes all eighteen list cases in debug, then
reports eight checklist and two choice-example failures. Its map tests pass;
the remaining dashboard run is stopped before rerunning the corrected candidate.
Both affected suites mistake
`▌` for focus. SwiftTUI 0.18.0 intentionally reserves it for checked membership
and uses `>` for the active unchecked row. The public native focus regions remain
present; this is a test-predicate compatibility issue.

The two helpers now require the requested label inside the currently focused,
activatable native row region. The checklist journey separately checks `>`/`▌`
and `[ ]`/`[x]`, including a checked row remaining selected while another row has
focus. Existing membership, activation and five-second checks remain intact.
Explicit constructors in the touched suites remove two old baseline entries;
no new entry or exclusion is added.

EngineeringRules 0.1.4 remains the highest published stable release at task start.
The initial compiler-backed macOS gate passes over 352 files with 398 tracked
findings and no new violations. After the migration, the nine checklist and three
choice test functions pass in focused debug runs. The fresh compiler-backed gate
passes with 396 tracked findings and no new violations. The complete local macOS
gate and [hosted macOS/Linux gates](https://github.com/echoz/Chio/actions/runs/38694392124/attempts/2)
pass at head `0b82ccb7e748da3ee57807f62ab0e9faedd6f00b`, through tested merge
`35f8acf9d81415625276220f388466f13bc1b12d`. All eighteen list cases pass in debug
and release. Independent review reports no actionable findings. [PR #17](https://github.com/echoz/Chio/pull/17)
merged the identical tree at `7d44bd6bd85290f2c6e3526cf19e6647d551797c`.

Hosted Linux passes on its first attempt. The first hosted macOS attempt reports
one previously documented tab-activation timeout; the unchanged macOS retry
passes. That retry does not establish the cause or repair of the intermittent
failure. Local and hosted appearance captures retain three native unbounded-list
measurement warnings per platform; the fixture contains four rows.

This slice adopts a release and retains the regression suite. It does not add
row-density API, change showcase assets, qualify live SSH behavior or establish
downstream adoption. Static Linux remains blocked by the documented upstream
portability gaps; ordinary Linux checks do not establish static linking.

## Running checks

The 2026-10-13 personal-client rollout explicitly accepts the released SwiftTUI
0.17.0 [disclosure and compact-layout regressions](Decisions/Dependencies.md#0170-adoption-candidate).
Keep their failing assertions and the normal gate unchanged. Record the failed
cases and any checks not reached; do not call that result a passing full gate.
Consumers update Chio and SwiftTUI together and verify their own affected paths.
This historical scoped acceptance does not cover new regressions or establish
qualification of the current upstream-revision candidate.

After the shared local check, with Swift 6.4 and Python 3 installed, run from the
repository root:

```sh
bash Scripts/ci/verify.sh
```

The gate serializes builds and hosted tests. It runs all tests in release,
selected tests in debug, a standalone release build, 24 plain-text snapshots and
19 dashboard pseudo-terminal workflows, plus the map example's fixture
reproduction and PTY workflow. Snapshot files are inspection artifacts;
Swift tests assert the rendering contracts.

A focused debug preflight first checks real map HTTP transport and the online
view lifecycle. SwiftPM continues other test targets after one executable fails;
this exposes acquisition regressions before the longer composition suites. The
normal debug/release suites still include these checks.

The approved debug/release split keeps library controls, domain values, raster
layouts and focused examples in debug. `CreateAgentTests`, `DashboardPaletteTests`,
`AgentReportInteractionTests` and the selected inbox/diff composition interactions
listed in the script run only in release, because unoptimized rendering can
exceed their frame deadlines. Their assertions and five-second waits are
unchanged. This does not establish full debug composition performance or cover
those workflows' debug-only native checks.

For a full debug investigation or a release-only suite, keep hosted tests serial:

```sh
swift test --no-parallel
swift test -c release --no-parallel
```

To exercise an already-built binary:

```sh
python3 Scripts/ci/terminal-smoke.py .build/release/chio-dashboard
```

The map example additionally runs `Scripts/maps/prepare-fixtures.py --verify`
and `Scripts/maps/terminal-probe.py` against its release binary. The PTY checks
compare map samples after pan and detail changes, including batched detail keys,
endpoint limits and cycle wrapping, as well as retained camera text, offline
coverage status and terminal restoration. Its `--benchmark` mode measures the first completed hosted UI frame, including
native startup, asynchronous preparation and frame delivery. It uses one warm-up
and three measured fresh sessions per scene/allocation; small allocations measure
the compact summary. Fixture I/O is excluded. These measurements replace the
spike's separate preparation/drawing/raster timings and do not measure SSH latency.
Use `--detail` and `--source` to choose retained input and presentation.
`Scripts/maps/render-snapshot.py` converts `--snapshot-json` exports into
inspection previews with Pillow and explicit text/braille fonts. Its default
fonts are macOS paths; supply `--font` and `--symbol-font` elsewhere. It is an
optional capture tool, not a Swift package or CI dependency.

Shape changes additionally compare land and water fills without labels, preserve
holes and seam behavior, and exercise unsafe-candidate/work-budget fallback.
Compare both world and street captures across detail levels; fewer annotations
alone do not establish geographic shape simplification. Keep abstract/source
captures unchanged when their geometry contracts are unchanged.

Drawing-work changes require exact/over-budget accounting cases and adversarial
overlapping polygons, long strokes and complex rings. Check whole-drawing rejection
before native painting, finite coordinate handling and the fill-disabled path.
The hosted overload workflow verifies retained camera/focus, batched detail keys,
theme changes, fill recovery and resizing; fixed fixtures must still render at
the documented allocations. Work counters are operation allowances, not latency
guarantees; benchmark drawing setup (admission and label placement) separately
from native raster work.

Source-adapter changes additionally check the pinned raw MVT/TileJSON hashes,
malformed/truncated protobuf, tag indices, command state, buffered coordinates,
ring orientation/holes, multipart identities and input/work bounds. Exercise the
real tile through all four shared detail levels, the three themes and narrow
allocations. Hosted checks preserve camera, detail, theme and native focus across application
source replacements. PTY checks exercise marker selection/activation, rapid input,
coverage recovery, resizing and restoration. Provider comparisons are shelved.
`--benchmark --source openfreemap` measures the tile through the same public hosted component; fixed tile resolution does not establish source-level selection,
network acquisition, tile stitching or arbitrary-provider support.

Online acquisition additionally requires complete XYZ coverage/model tests,
viewport admission with whole crossing/enclosing parts and holes, invalid offscreen
selected-data rejection, and retained-region coverage across same-tile pans,
controlled transport/clock checks for cache freshness, two-request admission,
replacement cancellation, budget-only fallback and current-result publication.
A bounded localhost HTTP fixture exercises URLSession response status, MIME,
redirects, decompressed-byte limits and cancellation on macOS/Linux. Python 3 is
required for that fixture. Hosted tests verify loading/failure/retry, retained
source/focus (including an initially absent source), compact recovery and independent
detail/theme changes. Real zoom-1 fixtures verify all four world tiles, complete
coverage across seam pans, coarse edge conversion and land/ocean raster samples
across detail levels, themes and narrow allocations. CI uses no
live provider. Separately inspect bounded OpenFreeMap acquisition and adjacent
tile rendering; this is integration evidence, not an availability guarantee.

Place-search changes additionally verify checked query/result values and decoding,
provider order and attribution, exact/over response limits, required JSON headers,
redirect restrictions, cancellation and HTTP failure metadata through real
loopback HTTP. Hosted example checks distinguish editing from submitting and
selecting from opening, retain camera zoom and attribution, reject unsupported
polar projection, and preserve native focus through narrow/wide resizing.
An eight-result compact-to-wide workflow checks native scroll reveal and the
public runtime-issue channel, including bounded measurement of the results list.
Public raster checks verify semantic light-row colors before and after native
selection moves, alongside visual inspection of all three theme captures.
A preloaded-result session verifies native list focus on first mount and that
Return opens the selected place without resubmitting the query.
Lifecycle handoffs cover acceptance and dismissal before deferred focus delivery,
allowing native focus to converge normally. Response replacement during one native
key dispatch verifies that activation uses the displayed place and its attribution.
Controlled providers cover one active request, replacement after cancellation
acknowledgement, latest-pending admission and stale A-B-A completion. The map
PTY probe's `--place-search` workflow uses synthetic local places without network;
refresh its default/light/btop previews when that presentation changes. A separate
bounded Photon request establishes live adapter integration only, never service
availability or permission for unrestricted use.

Reverse lookup additionally checks coordinate/limit construction and decoding,
explicit reverse paths and independent latitude/longitude query assertions,
attributed empty responses, poles and the shared transfer limits. Mixed-direction
submissions must retain one active operation, wait for cancellation acknowledgement,
replace only the latest pending request and reject stale publication. Hosted
interaction checks explicit centre lookup, submitted-coordinate captions,
no request on pan/style/zoom, retained credits, activation without zoom changes,
and compact focus recovery. Reverse endpoint configuration must not enable
forward search or tiles. The same fixture-only PTY workflow records centre lookup
alongside forward search; no public provider is used by tests or captures.

Routing adds checked two-point requests, finite optional estimates, attributed
no-route responses and source/wire-compatible shared credits. OSRM decoding checks
ordered longitude/latitude, exact one-route admission, full geometry bounds and
status/code consistency. Real loopback tests exercise 200/400 body handling,
unchanged Photon/tile rejection, decompressed limits, MIME, cancellation and the
ten-second deadline. Controlled routing providers cover latest-pending replacement,
acknowledgement and stale publication; native tests cover explicit keys, retained
credits, search coexistence and resize. Run the routing PTY workflow with:

```sh
python3 Scripts/maps/terminal-probe.py .build/release/chio-maps --routing \
  --record .build/routing/maps-default.cast --output-dir .build/routing/default
```

Repeat with `--theme light` and `--theme btop`. Render their `-initial.cast` files
with the shared player renderer and inspect the complete recordings before
replacing public assets. These fixtures do not prove live route correctness.
Those historical routing checks preceded the completed
[native corrections](#merged-layout-corrections) and the adopted SwiftRules 0.1.4 gate.

The 2026-10-13 routing candidate passed 324 selected map/Photon/OSRM tests in
release on macOS. After the final framing and decoder-boundary correction,
20 affected tests passed again in both debug and release. Linux Swift 6.4.0
on Ubuntu 24.04 arm64 passed all 325 selected release tests, including that new
framing regression. Real macOS PTY runs passed default/light/btop routing and
the existing forward/reverse search workflow, including terminal restoration
and diagnostic checks. The pinned SwiftRules check reported no new findings
across 351 files, retaining 414 baseline findings.

The refreshed preview images use the recorded terminal output and the vendored
player. Inspection confirmed readable route contrast in all three themes and
both endpoints inside the standard 100 × 30 frame. The unselected destination
is intentionally muted; tight bends and same-cell color collisions remain
terminal limitations. Site assembly passes. Safari inspection passed theme previews,
matching commands/snippets, playback, pause, seeking, category navigation and
browser history. The actual page also fits an embedded 390-pixel viewport;
isolated script-free and missing-theme-image fixtures retain the preview,
download and command fallbacks. After merge at `6f3c630`, the
[site deployment](https://github.com/echoz/Chio/actions/runs/38519554062) passed.
The published page was inspected with actual recording playback, loaded
default/light/btop route previews and matching theme-specific launch commands;
no browser warnings or errors appeared in that smoke check.
No public routing endpoint or SSH terminal was exercised.

The normal macOS gate at `bf39e2ff` reproduced exactly the 16 accepted SwiftTUI
issues: three disclosure placements, three compact inbox allocations, nine tree
layouts and one nested-tree interaction timeout. All 166 map/example tests pass
locally. The fresh hosted [run at `ed85b1e`](https://github.com/echoz/Chio/actions/runs/38506314063)
reports only those 16 issues on macOS, with all 166 map tests passing. Linux
reports the same 16 plus one place-search `nativeInteraction` timeout: the North
Pole result appears, but native result-list focus does not arrive within the
unchanged five-second wait. The new routing suites pass on both platforms.

An earlier run had six additional macOS timeouts; none recurred there, while the
same focus-wait context recurred on Linux. Six focused macOS repetitions also
pass (three debug and three release). These are intermittent observations, not
a demonstrated cause or fix. The next diagnostic boundary is actual semantic
focus and runtime issues during the native TextField/List reopen workflow; no
application polling or longer deadline has been introduced. The initial Linux
image-registry failure was cleared; it supplies no test evidence. Both hosted
scripts stop at their debug failures, so the separate local release and terminal
results above remain distinct. [PR #14](https://github.com/echoz/Chio/pull/14)
records the integrated checks; hosted verification is not claimed to pass.

Routing was rebased onto the merged rules upgrade at `38fc258`. The overlapping
attribution and HTTP conformance declarations retain their existing public and
transport behavior. Independent integration review found no actionable issues;
the rebased macOS compiler-backed gate passes across 351 Swift files with the
same 414 baseline findings. Dependency pins, tests and visual assets are unchanged
by the rebase. [PR #14](https://github.com/echoz/Chio/pull/14) records subsequent
platform results; reorganization does not claim to repair the search-focus failure.

The follow-up test recorder retains at most 64 frame, focus-presentation and
runtime-issue observations through public hosted-session APIs. It formats the
trace only on timeout, including the failing wait callsite, relative event times,
native focused identity, control roles/rectangles and available focus regions.
The latest raster remains in the report. Stored historical frames do not satisfy
waits: input, success predicates, sequence checks, five-second deadlines and
10 ms polling remain unchanged. Instrumentation may affect allocation or timing;
passing repetitions do not establish that the original intermittent is fixed.
The trace does not expose authored focus-request or lifecycle generations and
therefore cannot by itself prove the native cause.

To record the search workflow, run the map probe with `--place-search --theme
default --record .build/captures/maps-default.cast` and an explicit `--output-dir`.
It also saves `maps-default-initial.cast` from the actual submitted-results frame.
Repeat with `light` and `btop`, then pass those initial casts to
`Scripts/docs/render-terminal-previews.cjs` using its documented Playwright option.
Inspect all three rendered images and the complete recording before replacing
the gallery assets. Keep reports and intermediate captures under ignored `.build`.

Both HTTP fixtures bind numeric loopback directly, preserving the OS-selected
ephemeral port without Python HTTPServer's reverse-DNS lookup. Fixture readiness
must not depend on the runner's DNS configuration. Startup failure diagnostics
retain bounded child output and identify progress through imports and binding.
Test owners await child shutdown even after cancellation or a thrown operation.
Cleanup retains a five-second bound and reports signal results and observed process
state when it fails.

Persistent-cache changes additionally exercise source/format isolation, checked
file framing, original expiry, clock movement, encoded byte and entry bounds,
FIFO eviction, corrupt entries, interrupted temporary cleanup and explicit closed
ownership. `Scripts/maps/cache-probe.py` runs actual map executables against counted
loopback fixtures: cold acquisition, live ownership contention, warm reuse without
HTTP, graceful terminal restoration and reopening after SIGKILL. The kill occurs
after loading; a separately planted partial temporary proves startup cleanup,
not a kill during a real write. Unit cases cover publication failures. Run these
on macOS and Linux; they establish neither power-loss durability nor hostile
filesystem safety. Map geometry and the default recording remain unchanged.

Offline-pack changes additionally check bounded plan construction and decoding,
exact index completeness, offsets/lengths/checksums, version rejection, byte caps,
no-overwrite publication, cancellation cleanup and closed-reader behavior.
Exercise pack memory eviction/rereading and wall-clock independence without HTTP,
and preserve online cache freshness tests. Genuine world fixtures and hosted
sessions verify geometry, unavailable coverage, retained camera/focus and recovery.
`Scripts/maps/pack-probe.py` prepares a pack through the real executable, reopens
it in fresh processes from read-only storage, checks interaction and terminal
restoration, and compares file bytes before/after. Run on macOS and Linux. These
checks do not simulate power loss or kill a writer during a filesystem operation.

Pass an example flag such as `--choices`, `--inbox` or `--diff` for its workflow;
[verify.sh](../Scripts/ci/verify.sh) is the complete list. Terminal checks cover
input/output, raw mode, cursor/alternate-screen restoration and exact original
terminal attributes. They do not prove live SSH latency or every emulator's
appearance. Recheck responsiveness when editing or navigation paths change.

Dependency upgrades also require a paused dashboard comparison (`--paused`) under
`TERM=xterm-256color`, first without `COLORTERM`, then with `COLORTERM=truecolor`,
both without `NO_COLOR`. The indexed run exercises the actual terminal palette;
the true-color run must preserve authored RGB.

### Instrumentation

Instrument changes additionally verify independent current/target/reference facts,
checked normalized annotations, coincident marker captions, pure native style slots,
and native slider/stepper keyboard, pointer and accessibility routes. Retained tests
cover focus, input replacement, missing observations, theme changes and resizing.
Gauge sizing checks preserve the legacy plain dial's 20 × 5 plot boundary and
exercise annotated bars under wide/short and narrow/tall proposals, wrapped
captions, inherited line limits, complete track height and native numeric
fallback/recovery. Dial targets must preserve the original geometry and nil-target
paint, independent theme roles, endpoint/full/narrow intervals, shared-cell needle
priority, accessible target facts and complete fitting/resize recovery. References
remain bar-only. Inspect actual RGB and NO_COLOR terminal emissions; monochrome
numeric captions carry target meaning when the colored segment cannot.
History tests exercise equal timestamps, separate segments, nil breaks, real time
and Y intersections, extreme finite arithmetic, dense spikes and whole-plot work
rejection. A drawing bound does not bound an arbitrary caller's root allocation;
measure extreme proposals inside a bounded test surface.

The `--instruments` release PTY workflow checks missing/current restoration,
reference captions, history replacement, native numeric editing, theme changes,
compact recovery and terminal restoration. The example owns its playback task;
this is not live telemetry or SSH latency evidence. Inspect all three theme
previews and an uncolored capture before accepting changes to marker presentation.

### Demo site

The [showcase](https://echoz.github.io/Chio/) assembles sixteen recordings and 48
three-theme previews from `Docs/Media`, using the pinned local asciinema player
in `Docs/Site`. Its upstream license remains with the vendored assets. The catalog
opens on Maps and separates Chio views, styles for native SwiftTUI controls and
example apps. Entries identify public APIs, native controls, application-owned
behavior, source, launch command and keyboard guide. Minimal view fragments name
their application-owned inputs; examples link back to the pieces they compose.
Supporting APIs sit beside their owning view rather than implying a separate
performance toolkit. Component options remain independent of themes.

One shared static-preview theme follows navigation. The preview, Swift fragment
and command follow that choice; original recordings retain their recorded themes.
The optional `theme` query parameter and entry fragment support shareable choices
and browser history. Unknown themes use Chio; unknown entries show Maps.
Playback is explicit, pauses when leaving a recording, and can return to the
selected preview. Fragment links/history, script-free previews/downloads and
missing-asset fallbacks remain supported. The build gives owned CSS/JavaScript
content-hashed names. The player's NPT-poster limitation is recorded alongside
the vendored assets.

The separate [style comparison](https://echoz.github.io/Chio/appearance.html)
compares six actual terminal captures (default, opencode and btop at 100 × 30 and
36 × 64). [PR #10](https://github.com/echoz/Chio/pull/10) supplies the unified
`ChioStyle` implementation and refreshed, inspected captures. Refresh affected
captures from the verified candidate when appearance changes.
The main catalog retains default/light/btop previews;
this comparison does not establish opencode previews for every catalog entry.

Verify one inherited environment key, nearest complete-style overrides,
canonical style APIs and retained `theme:` initializer labels. Cover explicit
surface overrides and `.base` inheritance after palette replacement; construct,
replace and decode bounded input padding, including the historical absent key.
Use public raster and hosted-session checks for the supported searchable composed
lists: native focus, selection, query, activation and scroll reveal through width
and style changes. Include clicks on row padding, adjacent boundaries and disabled
checklist entries. Check `listRowVerticalInset` construction, replacement, decoding,
zero defaults and maximum-inset clipping. The
[native list conditions](Decisions/NativeIntegration.md#tall-list-rows) define the
supported contract; [merged-pin qualification](#020-merged-pin-qualification)
records current results and the earlier sections preserve failure evidence.
Single-line truncation limits row height but does not establish that arbitrary
list/checklist scrolling is safe. The merged correction addresses the reproduced
same-viewport focus failure; broader native follow-ups remain separate.
Inspect unchanged default/light presentation, the intentional btop border-heading
change, and opencode leading edges, roomy inputs and padded searchable rows.
The CI terminal probe exercises every comparison style at 36 × 18, including
section shortcuts and clean terminal restoration.

Capture all six recordings and PNG previews with the existing release binary:

```sh
python3 -B Scripts/docs/capture-appearance.py .build/release/chio-dashboard \
  --render-previews --output .build/appearance-review
```

PNG rendering uses the pinned local player and an externally installed Node,
Playwright and Chromium browser. Supply `--node /path/to/node` and
`--playwright /path/to/playwright` for runtimes outside the usual lookup paths.
Choose a fresh output directory under `.build` or outside the checkout. The
command checks prerequisites before recording, verifies each terminal's cleanup,
retains full logs and reports runtime warnings; it does not build or publish.
Omit `--render-previews` for recordings alone. CI's `--verify-only` needs no Node
or browser. The standalone `render-terminal-previews.cjs` also accepts existing
`*-initial.cast` files when only PNG generation is needed.

Inspect every still, full clip and retained log, then copy only the six approved
`.cast`/`.png` pairs into `Docs/Media/appearance`. Published clips end before
teardown; this does not fix recorded warnings. Do not infer color quality from
plain-text snapshots. The comparison
page's style/size controls, matching commands, explicit playback, script-free
links, 390-pixel layout and missing-asset fallback require browser verification
alongside site assembly. Applications own the demonstrated responsive layout.
Deploy only after merge; documentation or old captures do not prove that a changed
implementation passed its gates. [Plan](Plan.md) records the accepted evidence.

Preview the deployable output locally:

```sh
bash Scripts/docs/build-site.sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory .build/site
```

The [Pages workflow](../.github/workflows/pages.yml) builds relevant pull requests
and deploys relevant `main` changes. Pull requests receive no deployment
permissions; assets are served from the site without a CDN or asciinema account.

Completing a visible example change includes updating the showcase:

1. Capture the affected recording/previews from the verified release binary,
   using only local demo data. Reuse unaffected captures.
2. End published clips on the final complete UI frame, before teardown or logs.
   Inspect the full session separately for diagnostics, clean exit and terminal
   restoration; trimming a recording does not fix or suppress runtime warnings.
3. Update captions, matching commands and guide/source links. Preserve the
   Codex-assisted development and personal-software statement.
4. Check site assembly, assets/links, playback, pause, forward/backward seeking,
   category and related-entry navigation, shared-theme commands/snippets, URL
   history, focus, a 390-pixel layout and missing-asset/script-free fallbacks.
5. Commit and merge before deployment, then verify the published result before
   declaring the slice complete. An internal change with no visible difference needs no new capture.

## Linux and CI

[CI](../.github/workflows/ci.yml) runs on `main` pushes and pull requests using
Xcode 27 and the Swift 6.4.0 Ubuntu 24.04 container. The Linux image uses
[Docker's official ECR mirror](https://www.docker.com/blog/news-from-aws-reinvent-docker-official-images-on-amazon-ecr-public/),
pinned to the same image digest verified from Docker Hub, to avoid depending on
Docker Hub authentication during runner initialization. Builds/tests serialize
within each job; artifacts retain logs, text captures and xUnit reports.
macOS allows sixty minutes and Linux allows ninety minutes for the complete gate.
The 0.2.0 Linux run exhausted its former sixty-minute budget during an actively
progressing map probe, after all test suites and dashboard workflows passed.
Earlier forty-five-minute caps cancelled runs during forward progress: Linux after its test suites passed,
and macOS after all debug/release suites and dashboard terminal workflows passed,
as the map build started. The larger job budget preserves all test assertions,
frame deadlines and terminal workflows; it does not extend an individual test's
deadline or establish that a stalled test is healthy.

[0.1.0 verification](Releases/0.1.0.md#platform-verification) records the tested
platforms. Ordinary Linux executables need the Swift/Foundation runtime libraries.
Future failures require evidence and must not be hidden by weakened tests.

For static distribution, see the current [dependency decision](Decisions/Dependencies.md#static-linux-blocker).
