# Dependencies and distribution

**Status:** Accepted dependency choices; static Linux remains blocked.

Keep dependency choices reproducible and distinguish supported execution from unverified static distribution.

## Dependency choices

The library uses `SwiftTUIViews`; the executable uses `SwiftTUI` and tests
use public `SwiftTUIRuntime` raster/hosted APIs, without testing SPI or private APIs.
All four direct dependencies are revision-pinned:

| Dependency | Pin and reason |
| --- | --- |
| SwiftTUI in Chio 0.2.2 | `3999a9a57dde52fb00aa98952460b0819a0641bf`; retains #58–#60 and includes #62 startup input and #63 borrowed-output restoration |
| Swift Markdown 0.9.0 | `25cb61d3482054b09ae76ca4f281b1bfe7fe5a43`; revision permits conditional Windows unsafe flags |
| Tree-sitter 0.26.13 | `d97971e24500218865c05ed1febdee2acf41bae1`; last release with upstream SwiftPM manifest |
| tree-sitter-swift 0.7.4 | `82bb3a533e0801fd2bbaa11dc49676e10bf41948`; generated C grammar |

Version-based Chio requirements (`from:` or `exact:`) cannot resolve this
revision-pinned graph. Use the immutable Chio revision recorded in the selected
GitHub release notes.
The other direct revision requirements remain unchanged. Consumers with their own
SwiftTUI requirement must use the same exact revision as the chosen Chio revision,
then resolve their lockfile and verify their workflows.
[Chio 0.2.2](../Releases/0.2.2.md) records the current dependency update and migration.
The [0.2.0 release record](../Releases/0.2.0.md) preserves the earlier feature scope;
it does not change the immutable revision requirement.

Swift Markdown brings swift-cmark 0.9.0 built from source, without a separately
installed library. Tree-sitter/Swift grammar are MIT-licensed C targets requiring
neither a Swift wrapper nor grammar generation. The grammar copies unused queries;
Chio does no query-resource I/O and generates no Objective-C/Foundation accessor.
Build evidence is recorded in [0.1.0](../Releases/0.1.0.md); the current static Linux
blocker is below. Ordinary glibc support does not establish static-musl distribution.

<a id="borrowed-output-adoption-candidate"></a>

## Borrowed-output adoption

Published Chio 0.2.2 at `4ded80f870fb2c92c92d7d402fd71d42213ecee8` pins
merged #63 from the canonical remote at `3999a9a5`.
It also contains merged #62 and the subsequent stream-input scheduling correction.
The maintainer extended #63 to bound writes to saturated Darwin sockets.
Earlier qualification of the unmerged `65043a7b` head does not qualify this revision.
All seven other lockfile entries remain unchanged. PR #24 merged that pin into
`main`; application adoption of the published release has started and remains separate.

The same release moves Chio's private list focus enum out of its generic view
to avoid an Apple SwiftBuild metadata-link failure. Public API and native focus
ownership stay intact. [Native integration](NativeIntegration.md#private-focus-metadata)
owns the compiler limitation; [verification](../Verification.md#borrowed-output-adoption-qualification)
owns exact consumer and platform results. A passing earlier native revision does
not qualify this combined input. The platform gates for the release tree, canonical
installation and independent review pass. Applications retain their own adoption checks.

## Palette and scroll-focus adoption

**Status:** Adopted on `main` by [PR #23](https://github.com/echoz/Chio/pull/23)
at `6df2e336f5a398d34a37e98e431250f8dcaeca02`, included in the 0.2.2 release scope.

[SwiftTUI #58](https://github.com/SwiftTUI/swift-tui/pull/58) and
[#59](https://github.com/SwiftTUI/swift-tui/pull/59) merged on 2026-10-19.
The latter merge, `13c07f3981e0bb9160f8dfc8939ffa085824b340`, contains both fixes.
It also includes the intervening SwiftTUI 0.18.1–0.18.3 changes. This is an
upstream revision, not a Chio patch or fork. The latest release checked for this
adoption, 0.18.3, predates both contributions.

That merged revision regresses authored focus reads inside deferred `onChange`
callbacks. The first #60 correction restores those reads. A second correction
keeps stacked observers from sharing an observation slot when graph aliases change.
[SwiftTUI #60](https://github.com/SwiftTUI/swift-tui/pull/60) merged as
`877d7765febd08ffc2ed434a7ef231e4132c3b80`. Its callback correction matches the
reviewed patch. The merged tree also includes intervening native diagnostics and
terminal-output routing changes. The earlier `0283902a` qualification therefore
does not qualify the complete merged tree.

That adoption resolved this exact merged revision from the canonical SwiftTUI remote;
0.2.2 retains its corrections in the newer pin described above.
There is no ignored source patch or package mirror. All seven other lockfile pins
remain fixed. [Merged qualification](../Verification.md#merged-callback-qualification)
records fresh platform, terminal and installation results. Upstream merge does not
establish Chio adoption or release readiness.

The palette keeps its active command visible when terminal height limits the
result window. Scroll recovery preserves a previously visible focused control
through viewport and content geometry changes. Authored scrolling retains priority;
later content changes must not reveal a control deliberately scrolled out of view.
Chio retains its native palette and scroll styles, without a second focus owner.

Only the SwiftTUI requirement and corresponding lockfile entry advance. Other
dependency revisions remain fixed. Consumers that also require SwiftTUI must align
their exact revision. A published SwiftTUI release can replace this pin after its
contents and Chio integration are verified; no automatic monitoring is requested.

[Verification](../Verification.md#palette-and-scroll-focus-qualification) owns
consumer evidence. Upstream checks and the earlier 0.2.0 qualification do not
qualify this dependency combination. The [0.2.2 release record](../Releases/0.2.2.md)
separates verified source, publication and downstream adoption.

<a id="020-merged-native-correction"></a>

## 0.2.0 merged native correction

**Status:** Exact merged revision approved and qualified for Chio 0.2.0.
Publication and downstream adoption remain separate from qualification.

[SwiftTUI #57](https://github.com/SwiftTUI/swift-tui/pull/57) merged on 2026-10-15
Pacific (2026-10-16 UTC) at `7e62e95c913508f4fef42db36fde6fd60acb541c`.
It corrects focus recovery after same-viewport row geometry changes, eager-table
row placement and native outline focus. It retains the previous 0.18.0 fixes.
The latest published SwiftTUI release checked for this slice, 0.18.0, lacks #57.
The user approved this immutable upstream revision for Chio 0.2.0 rather than
waiting for the next SwiftTUI release.

Historical isolated Chio and upstream candidate results are recorded in
[Verification](../Verification.md#dynamic-row-spacing-candidate). They do not
qualify this final merged pin. The separate
[merged-pin qualification](../Verification.md#020-merged-pin-qualification)
passes complete Chio platform, terminal, installation and review gates.
Chio adds no private native patch, second focus system or renderer.

The user also approved a Chio 0.2.1 dependency patch after SwiftTUI publishes a
release containing #57. Recheck the release contents, align the exact requirement
and lockfile, and repeat consumer qualification and separate review before delivery.
SwiftTUI #58 and #59 were separate upstream follow-ups outside the 0.2.0 pin.
Their later adoption is tracked [above](#palette-and-scroll-focus-adoption).
No automatic release monitoring is requested.

<a id="0180-adoption-candidate"></a>

## Historical 0.18.0 adoption

**Historical status:** Adopted on `main` through [PR #17](https://github.com/echoz/Chio/pull/17),
merged at `7d44bd6bd85290f2c6e3526cf19e6647d551797c`. Included in
[0.2.0 release preparation](../Releases/0.2.0.md); release publication remains separate.

Published [SwiftTUI 0.18.0](https://github.com/SwiftTUI/swift-tui/releases/tag/0.18.0)
resolves to `4791281a55e5bbdb683718a7282afd10c2f5e42c`. Verified ancestry includes
the previous operational pin and the merged measurement-retention correction,
[#56](https://github.com/SwiftTUI/swift-tui/pull/56), at
`bf2faa8ff6aaddb89cae8bc035a781ddbc672c84`. This carries the requested release
follow-up below without changing the existing revision-pin policy.

The release keeps Swift 6.4 and the previous package graph. Only SwiftTUI's
revision and the manifest hash change in Chio's lockfile. It also changes terminal
capability detection and collection/layout behavior, so qualification uses the
complete consumer gate rather than only the original list reproducer.
The complete hosted [macOS/Linux gate](https://github.com/echoz/Chio/actions/runs/38694392124)
passes, including all eighteen retained list regressions in debug and release.
macOS required one unchanged retry after the documented tab-focus timeout; its
cause remains unproved. [Verification](../Verification.md#0180-adoption-qualification)
owns exact qualification evidence. No Chio focus workaround or public row-spacing
field is introduced.

Its multi-selection painting correction separates checked membership from the
active unchecked cursor. Two existing test helpers now use the public native
focus region for focus, with separate assertions for markers and checkmarks.
The interaction contracts and five-second waits remain unchanged.

Applications with an exact SwiftTUI requirement must align it with this release
when adopting the corresponding Chio revision and verify their own workflows.
Static Linux remains blocked; this release does not establish musl support.

## Merged layout corrections

**Status:** Adopted on `main` through
[PR #16](https://github.com/echoz/Chio/pull/16), merged on 2026-10-14 at
`b79f0096fbc19872bd91cc887b03048e7e9d2a47`. The user approved the immutable upstream
revision `bf9a697f2a5da4d0392730d0cba9e3ddcbbfa5d1` after Chio verification.
This is the first upstream commit containing both #49 and #50. It also contains
#47, PTY-test isolation and intervening benchmark/dead-code changes. The public
API baseline and dependency graph are unchanged. This revision is not a published
SwiftTUI release; 0.17.0 was the latest published release at this decision.

The complete macOS/Linux gate passes for the exact verified candidate and its
identical merged tree, resolving all sixteen retained disclosure/tree/compact-inbox
failures without a Chio layout workaround. The same slice fixes first-result
focus publication and functional clock scheduling under CI reduced motion.
Historical intermittent tab failures passed the final gate, but their cause
remains unproved. [Verification](../Verification.md#merged-layout-corrections)
records the outcomes and earlier failure evidence separately.

**Published-release follow-up completed:** [0.18.0 adoption](#0180-adoption-candidate)
above delivers the dependency update through merged PR #17. Its qualification is
separate from this earlier revision's evidence and from Chio release publication.

Applications with their own exact SwiftTUI requirement must align that revision
with the Chio revision they adopt, then resolve and verify their own workflows.
Chio qualification does not establish downstream adoption or a new tagged release.

## 0.17.0 adoption candidate

**Historical status:** Personal-client rollout approved on 2026-10-13 with the known
regressions below. Publish and consume an immutable Chio revision with this exact
SwiftTUI 0.17.0 pin; this is not a new versioned Chio release or a claim that every
component passes qualification.

Downstream applications previously stopped at dependency resolution because
their Chio revision required the older SwiftTUI pin. They must update both
manifest pins and the lockfile together, then verify their own builds, tests and
terminal workflows. Each owning task preserves unrelated work and records its
actual adoption status. Chio's accepted layout failures alone no longer block
those upgrades; unrelated failures still require investigation.

The accepted limitations are expanded disclosure/tree children overlapping and
some narrow input/list compositions exceeding their requested width (the inbox
fixture renders 43 × 18 instead of 36 × 18). The 0.17.0 accessibility migration
below retains the layout, focus and input assertions. Do not skip tests, enlarge
viewports, weaken deadlines or insert private native patches to make the full
gate green. Consumer upgrade evidence must identify any affected user workflow.

Fresh macOS verification on 2026-10-13 uses the clean released dependency and
the migrated assertions. All debug products compile, and the HTTP preflight
passes seven library and six map tests. The library run reports 462 tests
(one existing skip) with three disclosure-placement issues; all 139 map tests
pass. The dashboard run reports 146 tests with 13 issues: three compact inbox
allocations, nine tree layouts and one tree interaction timeout. These match
the accepted limitations. The unchanged `Scripts/ci/verify.sh` exits 1 at debug;
release and later terminal/process checks are not reached in this run. Pinned
SwiftRules 0.1.3 passes with no new findings; independent publication review found
no blockers within the approved scope. Prior patched-dependency evidence remains
separate below.

The initial released-pin run compiled with Xcode Swift 6.4.0 and passed the
focused real-HTTP/online-map preflight. Its full debug gate exposed two distinct
changes:

- Native accessibility now represents disclosure as a button trigger inside a
  group with expanded/controls properties, and labeled content supplies a named
  semantic group. Older Chio assertions required the `.disclosureGroup` role or
  counted every matching label. Those results called for the contract migration
  below, rather than establishing a production behavior regression.
- The accepted multi-child disclosure column no longer places `First`, `Second`
  and `Third row` on separate lines. SwiftTUI's new `DisclosureAccessibilityContent`
  wraps those direct children in an intrinsic `.view` whose placement gives them
  the same origin. Chio's existing public style already composes the content in a
  vertical stack. Weakening the exact placement assertions or adding a hidden
  native patch would conceal the regression.

Restore the native authored-child column contract upstream, then verify the
adopted correction with Chio's complete macOS/Linux and terminal gates before
claiming those regressions resolved. A Chio shim is not the current direction.
The local correction qualification below does not change the released pin's behavior.

On 2026-10-12, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SWIFT_BUILD_JOBS=2 bash Scripts/ci/verify.sh` stopped with exit 1 at the debug gate:

| Gate target | Result |
| --- | --- |
| Online preflight | Seven library and six map tests pass |
| Debug library | 462 tests (one skipped), 18 issues across six failing test functions |
| Debug map | 139 tests pass |
| Debug dashboard | 146 tests, 22 issues across eleven failing test functions |

The library issues comprise 14 older disclosure-role assertions/timeouts, three
exact column-placement failures, and one labeled-content all-label count mismatch.
Dashboard issues comprise eight tab-focus checks, three narrow inbox allocations
(rendered 43 × 18 instead of 36 × 18), and eleven tree layout/interaction issues.
Tab accessibility now exposes a `.group` focus owner and a synthetic `.tabView`
child whose `parentIdentity` links to that owner; an updated helper must verify
that relationship rather than accept arbitrary group focus. The inbox allocation
failure is real; the native Spacer correction below addresses its cause. Tree
overlap is consistent with the independently reproduced disclosure-column regression.

A minimal public-API native fixture imports only `SwiftTUIRuntime` and supplies a
custom disclosure style with a vertical content stack. Identical source renders
`First`, `Second` and `Third row` on lines 1, 2 and 3 against the old pin; against
0.17.0 it renders `Thirddrow` on line 1 with lines 2 and 3 blank. The comparison
reuses read-only dependency objects from completed debug builds, excludes Chio
objects, and retains exact compiler commands and outputs. Separate standard
SwiftPM manifests are prepared for fresh reproduction but have not been built.
This is macOS raster evidence, not Linux or live-terminal proof.

That initial run stopped before the release suite, release builds, snapshots,
PTY/color workflows and Linux gates. Its failures remain baseline evidence.

### Local correction candidate

Two native fixes were prepared on the released 0.17.0 base, without the
then-unmerged row-height change in #47:

- Disclosure payload roots remain transparent to authored layout. The semantic
  extractor publishes the labelled content region separately, preserving native
  expansion, controls, nested content and pointer routing.
- An ordinary Spacer's minimum comes from its declared intrinsic size, not a
  previously stretched measurement. Explicit minimum hints and fixed-size
  behavior remain intact. This restores the inbox's 36 × 18 allocation.

The combined native candidate is `91133fae27dd1c977a5f6746c1ff8f73008fdf44`.
[Disclosure PR #49](https://github.com/SwiftTUI/swift-tui/pull/49) is
`3ecf9a9b0f08a9a413e478ca3fce97e98d6cba8a`;
[Spacer PR #50](https://github.com/SwiftTUI/swift-tui/pull/50) carries the same
second patch independently on 0.17.0 at
`d8b845ae2ad47d6b73c4b7f7a333378b374c2b7a`. These are the original contribution
heads, not changes included in the released pin above.

Earlier on 2026-10-13, both PRs incorporated upstream `main`:
#49 is `74bdd6c7a3015ec1f3f5bc647bec068052054949`, and #50 is
`40c1bd8f2f7e73c3bde3630f4fcb21c2481e32ff`. All 24 checks passed on each head
at that check across macOS, Linux/WASI, Windows, public API, performance and
release soundness. The maintainer merged the separate descriptor-reuse test correction
in [#51](https://github.com/SwiftTUI/swift-tui/pull/51). These heads are not used
by this rollout. Earlier failure evidence below belongs to the original heads;
passing newer CI does not itself establish the original release crash's cause.

The subsequent 2026-10-13 status check confirms #49 and #50 are merged. Their
final heads are `50b29b147ca07f825863b141aebad4a36637f382` and
`40c1bd8f2f7e73c3bde3630f4fcb21c2481e32ff`; the maintainer added a semantic
accessibility follow-up to #49. At that check, SwiftTUI 0.17.0 remained the latest
published stable release and Chio's pin. Upstream merge does not establish released
availability or Chio qualification of those final trees.

Chio's test migration at `ff870923bd86d9b76195f54cd1f0292c8f7c7174` checks the new
button/expanded/controls disclosure contract,
actionable labeled-content slots, and the tab group's related tab-view node.
Exact layout, focus, pointer, binding and input assertions remain in place.
No Chio production shim, hidden native patch or weaker interaction deadline is
introduced. Qualification uses an explicit temporary local package path; the
manifest and lockfile at that historical candidate retain the published pin.

The combined native snapshot passes the full `bun run test` gate on macOS and
Linux arm64 with Swift 6.4.0, including runtime shards, platform suites, TermUIPerf
and the soundness scan. Both individual PR branches pass upstream pre-commit and
commit-message hooks. Independent review found no outstanding production findings.
The required remote maintainer `DEVELOPMENT.md` returned 404; its additional
requirements remain unchecked. Hosted CI for the individual PR heads is separate
from these combined-candidate results. The original heads passed macOS, Windows
amd64/arm64, Public API Baseline and TermUIPerf. PR #49 also passed release
soundness; PR #50 passed the full Linux/WASI Repo Gate. Each originally had one
failed workflow below; the later current-head results above supersede that status.

PR #49's first hosted [Repo Gate run](https://github.com/SwiftTUI/swift-tui/actions/runs/38289979373)
fails one unchanged PTY cleanup assertion: `F_GETFD` on the closed descriptor
number returns 1 while a separate PTY suite is opening descriptors. Independent
review identifies a descriptor-reuse race in that assertion; the precise event
was not traced and a baseline failure was not reproduced. The corresponding
PR #50 core lane passes. No new skips or weaker assertions were introduced. An unchanged-head
retry was requested but GitHub requires upstream maintainer rights; none started.

PR #50's [release-soundness run](https://github.com/SwiftTUI/swift-tui/actions/runs/38290024457)
fails in the serialized `InteractiveRuntimeTests` soak with signal 11 in
`libdispatch`, while another thread tears down a navigation scene's `RunLoop` and
`ViewGraph`. Other soundness shards and actor-race checks pass, as does the
corresponding PR #49 core lane. The repository documents historical runtime-soak
instability, but this trace alone does not establish the cause or rule out a
relationship to the Spacer change. That original head's hosted CI was not fully green.

A bounded release comparison in the official Swift 6.4 Linux amd64 image, under
Rosetta on this arm64 Mac, runs the same serialized `InteractiveRuntimeTests`
with the CI allocator guards (`MALLOC_CHECK_=3`, `MALLOC_PERTURB_=165`), stress
settings and soundness probes. Released 0.17.0 passes three launches, each reporting
94 tests with the existing Linux skip. PR #50's exact head passes two launches,
then exits 139 with signal 11 at the same navigation-test boundary as hosted CI.
The local backtracer also crashes, so an identical dispatch stack is not established.
Preserved baseline binaries, loader traces and runtime environment checks establish
which revision and settings were exercised. This small sample under translation
does not prove causation or clear the candidate; the runtime crash remains an
unresolved historical finding. No assertion, timeout or source change was made
for this probe. The subsequent approval above allows personal-client adoption
of released 0.17.0 while the upstream corrections are pending.

The focused macOS run passes 44 native tests across seven suites and 21 Chio tests
across five suites, including all compact inbox and tree layout cases. The patched
macOS debug gate passes all 462 library, 139 map and 146 dashboard tests; release
passes 462, 139 and 176 respectively (one intentional library skip in each configuration).
Debug and release paused-dashboard PTY captures preserve
authored RGB in true-color mode and identical text/layout in indexed mode, with
clean exit and exact terminal restoration. Indexed color retains the known grey
background limitation. The complete macOS `Scripts/ci/verify.sh` gate also passes,
including standalone release products, compact snapshots, dashboard/map terminal
workflows, loopback HTTP, persistent cache and offline-pack process probes.
The complete Linux arm64 consumer gate also passes, including the same terminal,
HTTP, cache and pack workflows. Linux debug passes 461 library, 139 map and 146
dashboard tests; release passes 461, 139 and 176 respectively. Linux release PTY
captures also preserve authored true-color RGB, matching indexed text/layout,
clean exit and exact terminal restoration. These runs establish
the explicit local combination, not compatibility with unpatched released 0.17.0.
That approved rollout used released 0.17.0 with its known limitations. These
patched-candidate results must not be presented as passing qualification of that
released pin; each consumer owns its actual upgrade checks.

## macOS toolchain findings

Some Apple Swift 6.4 toolchains do not discover the installed Swift Testing macro
plugin. `verify.sh` detects and supplies it when available; its command is the
preferred entry point. The attempted native backend could not find Testing.

Apple Swift `6.4.0.34.1` with Command Line Tools also emitted linker warnings for
nonexistent `CommandLineTools/Developer/usr/lib` and framework search paths.
An independent dependency-free package reproduced the warning and ran; Xcode 27
built that probe without it. This is recorded in
[SwiftPM issue #10557](https://github.com/swiftlang/swift-package-manager/issues/10557).
Chio adds no suppression flags and does not change the global developer selection.

## Static Linux blocker

Static Linux remains unverified at the current pin. The retained blocker below
was reproduced against the earlier `2d84ac7083993da2ef52e9d3d30255467efb9553`
pin; it is historical evidence, not a fresh build of the current pin.
A Swift 6.4.0 ARM64 cross-build with the matching
`swift-6.4.0-RELEASE_static-linux-0.1.0` SDK failed because upstream SwiftFiglet's
platform imports omit Musl, leaving POSIX symbols such as `access`, `opendir`
and `fopen` unavailable. Figlet is reached through Chio's library dependency,
not only the example. No static executable was produced.

[Run 37174543215](https://github.com/echoz/Chio/actions/runs/37174543215)
reproduced the blocker on x86_64. The manual
[static workflow](../../.github/workflows/static-linux.yml) retains failures; if a
future build succeeds, it checks ELF dependencies and executes the terminal
workflow. Use the matching official open-source compiler/Static Linux SDK;
Apple's Xcode compiler is not a substitute.

Source inspection found additional Musl gaps in native math, terminal, image,
link, PTY and socket paths. These are audit findings, not later compiler
failures: compilation stopped at Figlet. Native termios code also contains
Darwin VMIN/VTIME tuple indices. Linux `cfmakeraw` supplies the tested path's
correct values, but passing restoration tests do not prove those indices portable.
One import fix alone cannot establish static support; a changed dependency needs
compiled, linked and executed evidence before a static-distribution claim.
