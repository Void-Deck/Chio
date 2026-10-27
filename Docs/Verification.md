# Chio verification

Current requirements for implementation, dependency and visible example changes.
[Plan](Plan.md) tracks active work; [release records](Releases/0.2.2.md) preserve
revision-specific results. For documentation-only changes, check links, anchors
and preservation of current contracts.

## SwiftTUI 0.19.1 qualification

The candidate replaces SwiftTUI revision `3999a9a5` with exact release `0.19.1`
at `a67d15046ebd8b1cc83d781f50149a3e3ff0da80`. All seven other lockfile entries
must remain unchanged. Earlier release and CI results do not qualify this input.

Required evidence includes the fresh compiler-backed rules/documentation gate,
the complete release gate on macOS and Linux, and independent engineering review.
An external canonical consumer must resolve, build and exercise public API/raster
checks with the matching SwiftTUI version. Paused indexed/true-color dashboard
captures must preserve the documented presentation contract. The adoption PR
records exact revisions, commands, results and remaining limits before readiness.
No new Chio release, downstream adoption or static Linux qualification is implied.

## Borrowed-output adoption qualification

Published [Chio 0.2.2](https://github.com/echoz/Chio/releases/tag/v0.2.2) is
`4ded80f870fb2c92c92d7d402fd71d42213ecee8`. It pins merged SwiftTUI
`3999a9a57dde52fb00aa98952460b0819a0641bf`, including #62 and #63.
The released merge and reviewed head `5600d1da4a4e50cadb449754c311501a79747f92`
share tree `11a562a781a0021d36bd19cf4e41835e28025d43`.
[PR #24](https://github.com/echoz/Chio/pull/24) records the checks and independent review.

The complete local macOS release gate passes: 511 library, 166 map and 177
dashboard tests, including both two-list isolation cases. The
[PR gates for the same source tree](https://github.com/echoz/Chio/actions/runs/39926861526) pass
on macOS and Linux. Linux reports 510 library, 166 map and 177 dashboard tests.
All standalone products, snapshots, sixteen dashboard terminal workflows, three
appearance sessions, four map workflows, loopback HTTP, cache and offline-pack
process probes pass. Existing platform-dependent skips, assertions and deadlines
remain unchanged.

Compiler-backed EngineeringRules 0.1.10 passes across 350 files with one retained
baseline exception. Documentation checks pass for 57 documents, eight modules and
twenty deliverables. The naming inventory is empty; independent semantic review
has no remaining actionable findings. All runtime, test and verification inputs
are unchanged between the original runtime qualification and the reviewed tree.

A separate canonical GitHub consumer resolves the exact released Chio commit and
matching SwiftTUI. Its default Apple SwiftBuild release build and all six public
API/raster groups pass, including external `SearchableList` specialization.
All nine checkouts match the lockfile and remain clean; the other eight pins and
probe source are unchanged. The final installation refresh reuses the existing
isolated build cache; it does not repeat complete application-consumer qualification.

The [post-merge CI](https://github.com/echoz/Chio/actions/runs/39968810104) is still
pending in the 2026-10-23 publication snapshot. The
[demo workflow](https://github.com/echoz/Chio/actions/runs/39968810145) passed build
and deployment; no fresh browser smoke result is inferred.

Marquee, Blackbox and Pitwall passed isolated affected-path refreshes. Their owners
have started adoption of the published commit; those earlier checks and delivered
requests do not establish completed release adoption. Earlier results below retain
their original revisions and remain separate from this merged-pin qualification.

### Earlier provisional qualification

The initial exact #63 trial uses `c07d686e176f0116024545d6577f97f6d854a18d`
with the runtime source from Chio `94e87d0`. Apple Swift 6.4 / SwiftBuild release
linking fails on private `FocusStateLocation` metadata before tests can run.
Moving only the private list focus enum to file scope fixes that link boundary.
The same trial passes 511 library, 166 map and 177 dashboard tests, including both
two-list isolation cases. Existing filesystem skips and interaction deadlines stay
unchanged. Its full gate was intentionally stopped during terminal checks after
upstream changed the PR head; this is not a complete gate pass.

The earlier provisional input was upstream head
`65043a7b411c1bdfbce5c469e496836e6da95445`, which merges `main` at `82d9ea69`.
It retains the exact borrowed-output patch but also changes rendering and terminal
behavior. All seven other lockfile pins remain fixed.

The complete, unchanged release gate passes on macOS arm64 with Apple Swift 6.4
and its default SwiftBuild backend. It reports 511 library, 166 map and 177
dashboard tests, including both two-list cases. The case-insensitive filesystem
skip remains explicit. All standalone examples, dashboard and appearance terminal
workflows, four map workflows, loopback HTTP, cache and offline-pack process
probes pass. Assertions and deadlines are unchanged.

The same gate passes on Linux arm64 with the pinned Swift 6.4 Noble image
`sha256:31d14d727f4451f25e29bac9c42563a098c39ac66415e8bad970f48038e38aca`.
It reports 510 library, 166 map and 177 dashboard tests, with the existing
permission-enforcement skip. All subsequent executable and process stages pass.
The isolated source snapshot is unchanged before and after the run. This proves
ordinary Linux arm64 execution, not static-musl distribution or hosted x86_64 CI.

Compiler-backed EngineeringRules 0.1.10 passes on macOS: 350 files, one retained
baseline exception and one release Chio compiler configuration. Documentation
checks cover 57 documents, eight modules and twenty deliverables. The naming
inventory has no candidates; semantic naming and compatibility still require
independent review. Both macOS dependency checkout sets match all eight lockfile
revisions without tracked changes.

These checks qualify the provisional source, including the private focus-type
workaround. Later documentation corrections preserve every runtime, test,
dependency and verification-script input. Hosted CI, independent review and
final downstream adoption remained separate evidence at that checkpoint. The
[release record](Releases/0.2.2.md) records the later qualification and publication.

## Repository compiler selection

Repository development and verification use the Swift **6.4 release line** in
[`.swift-version`](../.swift-version). Select it through your existing `PATH`,
`DEVELOPER_DIR` or toolchain manager. The pin does not install tools or change
system selection. `bash Scripts/check-swift-version.sh` checks the selected
`swift --version`; supported verification scripts reject other compiler lines
and development snapshots before building. Stable 6.4 patch releases are accepted.
`Scripts/ci/verify.sh` also runs `python3 Scripts/test-swift-version.py`, whose
disposable compilers exercise accepted versions and prerequisite failures.

This contributor and CI pin does not impose a package maximum compiler version.
The public library retains its Swift 6.4+ consumer requirement, Swift 6 language
mode, existing OS support and dependency pins. Static Linux qualification remains
separate from this compiler-selection check.

## Shared engineering rules

Chio pins [EngineeringRules v0.1.11](https://github.com/echoz/EngineeringRules/releases/tag/v0.1.11)
(`3e42da0e724fe54585cc3cdd9009c749f7ba24d9`) through
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
  bash Scripts/ci/check-rules.sh /path/to/immutable/EngineeringRules-0.1.11
```

Full Xcode supplies the required Swift/SourceKit. On Linux, omit `DEVELOPER_DIR`
and follow the pinned tool's Swift 6.4 and Ubuntu Noble requirements. The normal
gate does not install tools or edit source, configuration or baselines; a missing
pinned installation is a failed prerequisite. It verifies the release commit,
exports the documentation checker and compiler-context helper from that immutable
revision, runs the documentation gate with the prepared Python environment, builds
the actual `Chio` target in release with SwiftPM's native backend, and supplies its real
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

### Naming review

Include the pinned inventory command as a separate planned check alongside the
wrapper and applicable tests in the engineering-review evidence packet:

```sh
~/.local/bin/swift-rules review-candidates --root "$PWD" --format json
```

Retain its JSON output and logs for that exact candidate. The independent reviewer
records each name's meaning and a concrete rename, legitimate retain reason or
explicit out-of-scope deferral. A successful inventory command does not complete
semantic review; candidates are neither violations nor baseline entries.
The pinned tool's [selection contract](https://github.com/echoz/EngineeringRules/tree/v0.1.11#naming-review-candidates)
owns matching and output. Apply the global organization guidance to the names.

Use the released engineering-review workflow for all introduced or changed names,
including unchanged names whose meaning changes. For identities and revisions,
inspect creation, advancement, invalidation and comparison sites to judge the
subject and lifetime. Retain precise scoped names and framework terminology;
this review does not authorize unrelated renames or public/persisted contract changes.

The current configuration includes `Sources`, `Examples`, `Tests` and `Spikes`
without excluded paths. The collector visits Swift declarations in all conditional
branches. References, extension subjects, values/functions, comments, strings and
macro expansions are outside its lexical coverage. `Package.swift`, scripts,
the private C bridge and dependencies are also outside this Swift inventory.
Review relevant names there manually; older tools require manual review too.

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
The gate checks 57 unique documents, eight modules and twenty deliverables.

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

<a id="0111-adoption"></a>

### 0.1.11 adoption

This maintenance change advances the checker and immutable helper revision to
published commit `3e42da0e724fe54585cc3cdd9009c749f7ba24d9`. The documentation
checker and review skill payloads are unchanged from 0.1.10. Rule scopes,
the existing baseline exception, dependency pins and application behavior remain
unchanged.

Chio retains its single native release `compilerContext`. All Swift layout sources
belong to the `Chio` module; no platform-specific source sets or conditional
type/conformance declarations require the optional `compilerProfiles` workflow.
Platform-dependent imports and function bodies remain. The local witness result
covers only the supplied platform and configuration, not Linux analysis or
example/test witnesses. Hosted macOS/Linux builds, tests and terminal workflows
remain separate runtime evidence; public CI does not fetch the private checker.

The adoption PR records the candidate, fresh wrapper and naming-inventory results,
applicable release checks, separate review and hosted status. A passing local
candidate does not establish default-branch adoption or a new Chio release.

<a id="0110-adoption"></a>

### 0.1.10 adoption

[PR #23](https://github.com/echoz/Chio/pull/23) advances the checker and immutable
helpers from 0.1.9 to published commit `756987b0d0e4bf8245abe05611f43aab8ffc700e`.
Version 0.1.9 rejected `-whole-module-optimization` after Chio's release build
succeeded. Version 0.1.10 accepts that release setting and validates native
scheduling operands before omitting them from compiler analysis. It preserves
optimization, conditional-compilation flags and complete source indexing.

The wrapper still builds the actual release target before exporting fresh
compiler context. Missing or invalid evidence still fails the gate. Source
scopes, schemas, application dependencies and the single scratch-state baseline
exception remain unchanged. The released documentation checker is unchanged.
The shared engineering policy now uses release for normal verification, with
additional debug runs only for a named debug-only contract.

The local wrapper passes on macOS with Swift 6.4 and Xcode 27: 350 scanned
files, no new violations and one retained baseline exception. Compiler witness
analysis passes for all 125 Chio source files in the exported configuration.
The context retains `-O` and `-whole-module-optimization`, uses the actual release
dependency modules and omits no source files. The documentation gate checks
56 documents, eight modules and twenty deliverables without findings.

<a id="018-adoption"></a>

### 0.1.9 adoption

This focused adoption updates [PR #22](https://github.com/echoz/Chio/pull/22)
from its 0.1.8 candidate to published commit
`f80213f14acf839b6d5ba9f131d4c113182e2592`. It merged to the default branch as
`04896a6ceb4d44bb7ed88950eaceb4d2c0a5aea6`. The tool pin, documentation source and
compiler exporter advance together; this maintenance PR changes no dependency.
The existing lint, real compiler-context and schema 2 documentation checks remain.
The documentation checker and compiler exporter have identical contents in the
0.1.8 and 0.1.9 releases. Source scopes, application dependencies and the single scratch-state
baseline exception remain unchanged.

The shared engineering-review skill is installed separately from the same release.
Its `SKILL.md` SHA-256 is
`e72f423326e645b7530e01b7ed741305639ca9a1a8c766029a4b2449d02656c1`.
The review packet retains the installation receipt and verified payload hashes;
Chio does not vendor the skill or modify shared installations. Loading the workflow
does not establish a completed review or clean naming across unrelated application code.

The initial inventory scanned 350 Swift files and collected one declaration:
`HelpExampleView.Context` at `Examples/AgentDashboard/Presentation/HelpExampleView.swift:22`.
Its cases select the shortcut groups for browsing, editing, actions or all groups.
The private enum becomes `ShortcutScope`; its derived property becomes
`activeShortcutScope`, and `openHelp` takes a `scope`. No public identity, behavior,
test assertion or deadline changes. Existing help-example tests cover the rendered
groups, modal dismissal, restored focus and query, compact layouts and key handling.

Manual review retains references to SwiftTUI's `CanvasContext` and Swift's
`DecodingError.Context`: these are framework-owned drawing and decoding contracts.
The gate's compiler-context names describe real compiler inputs and also remain.
No collected declaration is deferred. The final inventory and separate review
must verify this disposition; an empty final list alone does not establish it.

The exact candidate `c26b6a039711fa8ad2183c2ae102d2b1e4da4e73` passes all seven
local checks and independent review. The compiler-backed gate checks 350 Swift
files with no new violations and one retained baseline item. Documentation checks
56 documents, eight modules and twenty deliverables with no findings. The final
naming inventory is empty, and ten help tests pass in each configuration.

[Hosted CI](https://github.com/echoz/Chio/actions/runs/39556673983/attempts/2) passes
on macOS and Linux x86_64. Both jobs test merge `b704b23e`, with the exact candidate
and base `3194d11f` as parents. Its tree equals the candidate and merged main tree.
The Linux-only retry follows a container-registry failure before checkout; it
completes the unchanged full gate. Existing runtime warnings remain in the logs.
These results establish default-branch adoption, not a new Chio release.

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

Initial qualification tested SwiftTUI
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
The native-only regression now fails at the direct focus read for both `onChange`
overloads, then passes with the correction in
[SwiftTUI #60](https://github.com/SwiftTUI/swift-tui/pull/60).
The final native candidate `89c8fef1` passes both cases; its independent source
review has no actionable findings. Its full gate and platform checks remain
separate from this consumer qualification. Chio still pins the unmodified merge.

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

A fresh external consumer installs Chio `cee6d152` and the matching SwiftTUI pin
from their remotes. Its release build and five public-API probe sections pass:
imports/style inheritance, duration labels, list spacing, map values/raster, and
instrument construction. Fresh resolution selects a different compatible
`swift-collections` revision than Chio's lockfile. This is consumer-installation
and raster evidence, not interactive or cross-platform qualification.

The [hosted run for `cee6d152`](https://github.com/echoz/Chio/actions/runs/39326704894)
confirms the retained disabled-membership failure and both grouped-form failures
on macOS. Preflight checks and all 166 map tests pass. The updated viewport
workflow passes; release suites and terminal/process probes are not reached.
Linux fails while pulling the pinned Swift image from public ECR with
`toomanyrequests: Data limit exceeded`. It never checks out the repository or
runs tests. Registry availability supplies no source or platform-test verdict.

These results describe the initial candidate before the callback correction and
the user's disabled-row decision below. They do not qualify the replacement pin.

### Callback correction qualification

The following `16c83687` results are the earlier checkpoint. The
[stacked-observation correction](#stacked-observation-correction) below owns the
current candidate's evidence.

On 2026-10-20, the user approved native navigation that skips disabled rows while
retaining their visibility and membership protection. The owning
[selection decision](Decisions/SearchableSelection.md) records the new contract.
All-disabled results must retain usable search editing.

The draft resolves SwiftTUI #60 commit
`16c8368746765e6fa9543c9d4d0e822cd84f3bc3` through the upstream URL. Its checkout
is clean; no dependency patch or package mirror is used. The lockfile changes
only SwiftTUI's revision and the manifest hash.

This exact native commit passes its complete local 85-step gate. Hosted macOS,
Windows arm64/amd64, public API and TermUIPerf checks pass. Both new callback
cases execute successfully on Linux debug/release, macOS and Windows. The larger
Linux debug runtime shard reaches its 1500-second command limit, and the separate
actor-check job is cancelled. These are incomplete upstream CI results, not a
passing full gate. The required external development guide remains unavailable.

Both new all-disabled editing cases fail on the unchanged checklist, then pass
after its handoff requires an enabled result. The existing five-second waits
remain unchanged. Focused debug qualification passes fifteen checklist tests and
all five unchanged grouped-form tests, including nine layout cases.

Complete consumer runs at Chio `9a6591610046d6e896735f0814eb580551131ba4`
retain the unchanged gate and interaction deadlines:

| Boundary | macOS arm64 | Linux arm64 |
| --- | --- | --- |
| HTTP/online preflight | 19 + 6 pass | 19 + 6 pass |
| Debug library / maps / dashboard | 510 / 166 / 147 reported; one library case skips | 509 / 166 / 147 reported; one library case skips |
| Release library / maps | 510 / 166 reported; one library case skips | 509 / 166 reported; one library case skips |
| Release dashboard | 177 tests, four failures | 177 tests, the same four failures |

All executed tests in the first three rows pass. The library totals include each
skip: macOS executes 509 and Linux executes 508. macOS skips the filename
case-tie test because the host filesystem treats case-only names as the same file.
Linux uses an isolated Swift 6.4 Noble container and an immutable source archive.
Its permission-removal case skips because the root container can still read the
file. The source hashes, lockfile and clean native checkout match the candidate.
This is Linux arm64 evidence, not hosted Linux x86_64 qualification.

The four failures are create-form blur validation, conditional-field error reveal,
diff hunk reveal, and the diff's earlier vertical-only End expectation. Native
focus reaches Role and Test suite; those waits also require visible validation.
The narrow Test suite capture leaves its error below the viewport, so it does not
prove missing validation state. The diff header advances to hunk two while its
viewport remains at zero. End correctly reaches both native scroll limits; its
test must follow the accepted [scrolling contract](Decisions/Scrolling.md).
Those consumer logs do not establish whether the observers dispatch.
Grouped-form tests pass unchanged in both configurations on both platforms.

The follow-up diff test checks End at both scroll limits, then returns to the
leading column before retaining the original horizontal-clamping and file-change
assertions. Its focused macOS release run passes. This resolves the expectation
migration; it does not qualify the other three failing workflows or Linux.

A test-only native debug probe on unchanged `16c83687` reaches the next focused
field inside `ScrollViewReader` and `GeometryReader`, but its focus observer
records no invocation. The blur error therefore never appears. No presentation
portal is needed to reproduce this failure. The original two callback-scope cases
still pass. A separate plain state-driven reader probe successfully dispatches
and accepts its scroll request, so it does not yet reproduce the diff failure.
The probe patch and logs remain local evidence, not a published native correction.

Both gates stop at release test failure. Release product, snapshot, PTY and map
process stages are not reached; their previous-pin results cannot qualify this
candidate. The macOS compiler-backed EngineeringRules 0.1.7 gate and site assembly
pass. The rules gate retains one baseline finding.

A fresh external consumer resolves exact Chio `9a659161` and SwiftTUI `16c83687`
from their canonical remotes. Its release build and all five public API/raster
probes pass. Fresh resolution selects a newer compatible `swift-collections`
revision than Chio's lockfile. This proves installation and those probes, not
hosted interaction or Linux execution.

The [hosted run for `9a659161`](https://github.com/echoz/Chio/actions/runs/39386480023)
confirms the same four release dashboard failures on macOS. Its tested merge has
the reviewed base and exact candidate as parents. Hosted Linux fails before
checkout while pulling the public ECR image: `toomanyrequests: Data limit exceeded`.
That job runs no tests.

Independent source review finds two stale current-pin documentation statements,
now corrected in README and NativeIntegration. Qualification remains incomplete.
Keep the adoption PR draft. Upstream merge and requalification of the merged
revision remain necessary before the operational pin advances.

### Stacked-observation correction

The follow-up tests isolate shared observation slots in native stacked `onChange`
modifiers. The same resolved identity can temporarily refer to different graph
aliases. Each alias's counter can claim ordinal zero and overwrite another
observer's baseline. The correction in SwiftTUI
`0283902aa221e5d20bad2a08cc3fd2fce1e4ab6d` counts observers on the resolved
element while retaining the existing graph baseline and lifetime rules.

A native reader/focus reproduction fails on `16c83687`: focus reaches the next
field, but no blur callback runs. With the correction, it dispatches and paints
the validation error. Added tests cover mixed-type and same-type observers,
unrelated child updates and repeated resolution within one pass. The focused
debug run passes 39 tests across seven suites; the release run passes 26 tests
across seven suites. Their filters differ. Existing exact-ID, modifier-order,
cascade, checkpoint and lifecycle tests retain their assertions.

Consumer qualification uses Chio `665540b4a43dff4776036c0cb58bc3df435dc5db`
with an explicit local SwiftPM dependency on the clean native commit above.
Only the manifest and lockfile differ from that Chio commit. All other resolved
dependencies remain fixed, including swift-collections 1.7.2. There is no ignored
dependency source patch or package mirror.

The complete `Scripts/ci/verify.sh` gate passes on macOS arm64 with Apple Swift 6.4
and in an isolated Swift 6.4 Noble Linux arm64 container:

| Boundary | macOS reported tests | Linux reported tests |
| --- | --- | --- |
| HTTP / online preflight | 19 / 6 | 19 / 6 |
| Debug library / maps / dashboard | 510 / 166 / 147 | 509 / 166 / 147 |
| Release library / maps / dashboard | 510 / 166 / 177 | 509 / 166 / 177 |

Each library run includes one existing filesystem skip: case-only filenames on
macOS and permission removal in the root Linux container. All executed tests
pass. Source inventories and dependency revisions remain unchanged across the
Linux run. On both platforms, the unchanged gate also passes standalone release
builds, snapshots,
all sixteen dashboard terminal workflows, appearance checks, map terminal
workflows, loopback HTTP, persistent cache and offline-pack process probes.
The formerly failing blur validation, conditional-error reveal and diff hunk
navigation pass without changing their assertions or five-second waits.
The compiler-backed EngineeringRules 0.1.7 and documentation gate passes with
its existing one-item baseline. Site assembly and whitespace checks pass.

The native `bun run test` gate passes 84 of 85 steps on macOS arm64 with official
Swift 6.4. Its only failure is an incremental TermUIPerf helper crash before the
first assertion (`SIGBUS`). After cleaning only that subpackage, the exact failed
command passes all 151 tests across twenty suites. The affected soundness scan
also passes. The original aggregate remains failed; this separate retry does not
prove the crash's cause. All 84 unaffected passing steps remain applicable.
The linked native development guide returns 404, and `prek` is unavailable;
strict formatting and standalone policy checks pass without claiming hook execution.

Canonical-remote candidate `09ed9c8d14f7e42d36485c3b4d9e151a077c11d0`
resolves the same clean SwiftTUI commit without a mirror or source substitution.
All seven other dependency pins remain unchanged. Its release checks pass ten
checklist cases and eighteen create-form, diff and grouped-form cases. The
compiler-backed rules, documentation, site assembly and input-integrity checks pass.
Executable sources, tests, scripts and gate configuration match the complete
platform runs above; their results remain applicable across the dependency-location
change and subsequent documentation-only edits.

A fresh external consumer resolves that exact Chio revision and SwiftTUI commit
from their canonical remotes with empty build and package caches. Its release
build and all five unchanged public API/raster probe sections pass: inherited
styles, duration formatting and initializer references, bounded list spacing,
checked map values/raster, and instrumentation construction. Fresh resolution uses
compatible swift-collections 1.7.3; the producer lockfile retains 1.7.2. Other pins
match, and both checkouts remain clean at the expected revisions.

Separate source review finds no actionable production or test issues.
These results do not establish hosted Linux x86_64, upstream merge, release
readiness or downstream adoption. Requalify the merged native revision before
completing adoption.

### Merged callback qualification

SwiftTUI #60 merged as `877d7765febd08ffc2ed434a7ef231e4132c3b80`. Its patch matches
the final reviewed upstream head. The merge also includes native graph diagnostics
and terminal-output routing changes, so the earlier `0283902a` results do not
qualify this complete tree. SwiftTUI 0.18.3 remains the latest published release
checked for this adoption and predates these corrections.

Fresh qualification uses Chio `60ea960f5a116c280ce31114eec10bc7a448d385` with only
its manifest and lockfile updated to the merged native revision. Commit
`0d60a607678de999cc526f86440a2287269a683f` records those exact inputs. Resolution
uses the canonical SwiftTUI remote, with no mirror, local substitution or source
patch. All seven other dependency pins remain unchanged, including Collections
1.7.2. All resolved checkouts are clean.

The unchanged `Scripts/ci/verify.sh` passes with official Swift 6.4 on macOS arm64
and in an isolated Ubuntu Noble Linux arm64 container:

| Boundary | macOS reported tests | Linux reported tests |
| --- | --- | --- |
| HTTP / online preflight | 19 / 6 | 19 / 6 |
| Debug library / maps / dashboard | 510 / 166 / 147 | 509 / 166 / 147 |
| Release library / maps / dashboard | 510 / 166 / 177 | 509 / 166 / 177 |

Each library configuration retains its existing filesystem skip. All executed
tests pass. Both platforms pass standalone release products, snapshots, all
sixteen dashboard terminal workflows, three appearance sessions, map terminal
workflows, loopback HTTP, persistent cache and offline-pack process probes.
The Linux snapshot's 559 source hashes and both platforms' dependency inputs remain
unchanged. The disposable Linux container is removed after verification.
No assertions, individual deadlines, workflow selection or skip conditions change.

A fresh external consumer resolves exact Chio `0d60a607` and SwiftTUI `877d7765`
from canonical GitHub remotes with empty package and build caches. Its release
build and all five unchanged public API/raster probe sections pass: inherited
styles, duration formatting, bounded list spacing, map values/raster and instrument
construction. Fresh resolution selects compatible Collections 1.7.3; the producer
retains 1.7.2. Every dependency checkout remains clean at its resolved revision.

All fourteen upstream checks on `877d7765` pass. These support the native revision;
they do not replace consumer checks. The integrated candidate `1c05ff9` also passes all seven local checks: compiler-backed
EngineeringRules 0.1.9, documentation, naming inventory, help tests in both
configurations, site assembly and whitespace. The private help-symbol rename is
the only executable-source difference from the full platform runs above. Their
library, test, dependency and terminal-script inputs remain unchanged. Independent
source review finds no actionable issues. Hosted Chio checks remain a separate
readiness requirement. Repeated ECR pull failures before checkout supplied no test
evidence. The Linux job now retrieves the same pinned image from Docker Hub;
anonymous registry access confirms the identical multi-platform digest and its
Linux x86_64 manifest. The image, gate and individual deadlines do not change.
Local Linux arm64 does not establish hosted Linux x86_64 or static-musl support.
Live providers, SSH appearance, downstream adoption and release publication remain
outside these results. Consumers with a direct SwiftTUI requirement must align
that revision with the selected Chio revision.

### Startup input investigation

The hosted [run at `5ba7261`](https://github.com/echoz/Chio/actions/runs/39628822320)
reached tests on both platforms. The file-picker late-read case timed out at its
input barrier before Parent navigation, so it did not exercise stale-read
rejection. macOS also timed out switching to Workspace in the compact opencode
and btop appearance cases. Linux passed those appearance cases. Release and
terminal stages were not reached; the earlier local passes remain separate.

Chio `d2aaeef` adds bounded send/dispatch observations to those fixtures, retaining
every assertion and five-second wait. Its
[hosted run](https://github.com/echoz/Chio/actions/runs/39651133946) passes the
complete macOS and Linux gates, including debug/release tests, release linking,
terminal workflows and map process probes. Both jobs test merge `5bdf1c602ca439ef4176feb08dcd656b7711d404`.
No timeout occurs, so no failure history explains the earlier input delay.
These observations can affect timing; this passing diagnostic run alone does not
establish a correction.

The final [run at `9b44284`](https://github.com/echoz/Chio/actions/runs/39662117842)
passes the complete macOS gate but fails the same Linux file-picker barrier.
Both jobs test merge `b8f0ef0b28463cfdf356e4e6e08d104d8edfa9eb`.
On Linux, input is sent at about 2.03 seconds,
after frame 3. Loading frames continue through frame 15 at 6.24 seconds, then
Tab and Control-B dispatch. The five-second barrier deadline fires at 7.21 seconds
without a later frame. This establishes a 4.21-second dispatch delay and matches
the native startup acquisition cap. It does not explain the remaining interval
after dispatch or prove that the native candidate repairs the complete hosted
path. The Linux failure occurs before Parent navigation and stale-read rejection;
its release and terminal checks are not reached. Default animated loading, assertions
and interaction deadlines remain unchanged.

[SwiftTUI #62](https://github.com/SwiftTUI/swift-tui/pull/62) reproduces startup
starvation without elapsed-time assertions. Input queued at commit 1 or 3 executes
at commit 17 on base `b23c7338`, then at the requested commit with the correction.
The synchronous appearance/focus preservation case and callback-attribution
checks also pass. Native CI then exposed a missing startup exit flush. Its
unchanged two-frame assertion and a new final-callback/task-lifetime regression
pass after the correction, alongside the focused startup and termination suites.
The upstream PR tracks its full gate and independent review; these focused results
do not qualify that candidate for adoption.

An isolated Chio `d2aaeef` checkout uses a frozen local copy of the native
candidate. All thirteen FilePicker tests and four appearance tests, including
their parameter cases, pass with the seven other dependency pins unchanged.
This is local macOS qualification with an explicit dependency substitution.
It does not qualify the unchanged Chio pin or establish hosted CI success.
The complete local consumer gate passes preflight and debug suites: 509 executed
library tests with the existing filesystem skip, 166 map tests and 147 dashboard
tests. Release linking then fails on private `FocusStateLocation` metadata.
Release tests and terminal/process checks are not reached. The failing native
file is unchanged by the startup correction. The same Apple compiler and source
link `chio-maps` successfully with SwiftPM's native backend. The SwiftBuild
aggregate localizes a weak private-external metadata accessor before Chio's
reference can resolve. Passing `-keep_private_externs` to the final link does not
repair that earlier aggregation. Neither result qualifies the default backend.

A separate [CI-only qualification](https://github.com/echoz/Chio/actions/runs/39655547059)
at Chio `95b9d785` uses native `6c3d5f28` with the original `5ba7261` tests,
scripts and workflow, before diagnostic instrumentation. Its macOS preflight and
debug suites pass, then release linking fails at the same boundary. Only the
SwiftTUI revision and lockfile origin hash differ; the other pins are unchanged.
This experiment does not change the adoption PR's operational pin or qualify the
newer dependency for adoption.

The next isolated trial uses exact SwiftTUI `1a23ffc1`. Unchanged FilePicker and
appearance debug tests pass locally with default animated loading and five-second
waits. The original nested `SearchableList.Focus` still fails release linking.
Moving that private enum to the same file's top level avoids the failure with
the same Apple Swift 6.4 compiler and default SwiftBuild backend. The public API,
enum cases, native focus ownership and seven other dependency pins stay unchanged.
The final source links `chio-maps` in release mode and passes all thirteen focused
list tests in release, including two new simultaneous-list cases. Those cases
also pass in debug and against the original nested type. They exercise real
Tab/Shift-Tab input, independent editing and selection, overlapping IDs, and both
matching and different item/row specializations. Private reflected type identity
changes; cross-version hot-reload compatibility is not established.

The [complete hosted trial](https://github.com/echoz/Chio/actions/runs/39670576712)
uses isolated Chio `0c786c5` with the canonical native revision and unchanged CI
workflow. Its complete macOS gate passes, including release linking, interaction
tests and terminal/map probes. Linux passes the file-picker cases, then fails
`AppearanceExampleTests.narrowSections` for btop while revealing Workspace.
The outer observer sees Control-E about 1.08 seconds after input was sent;
no later hosted frame arrives before the five-second wait fails. That observer
does not prove that the actual edit handler ran. Release and terminal/map stages
are not reached on Linux. The local compiler-backed EngineeringRules 0.1.9,
documentation, naming and whitespace checks pass. This trial covers a broader
native dependency delta than the startup correction alone; focused results do
not replace complete consumer qualification or approve adoption of an unmerged pin.

### Appearance interaction timing

The isolated `0c786c5` source passes six unchanged Linux ARM64 narrow-section
runs: eighteen recipe cases in total, using Swift 6.4 and two CPUs. A separate
profiled btop case answers Control-E in 2.11 seconds. These results do not
establish hosted x86_64 timing or reproduce the failing full-suite run.

The [hosted timing comparison](https://github.com/echoz/Chio/actions/runs/39693162630)
at diagnostic commit `1f1780f` first restores the exact `0c786c5` source and passes
all three narrow-section recipes. It then runs six separate btop processes with
public SwiftTUI profiling and bounded observations. Each actual edit handler runs,
sets Workspace focus and successfully scrolls to settings. Every matching frame
arrives in 4.84–4.89 seconds; the slowest leaves approximately 107 milliseconds
before the unchanged five-second deadline. No timeout occurs, so the diagnostic's
post-failure observation path is not exercised. Instrumentation can affect timing.

Each recorded transition includes a cancelled acquisition before presentation.
The final-frame `pipeline_ms` omits earlier convergence and cancelled work, and
cannot account for the full input-to-frame interval. These observations support
a debug-rendering budget explanation but do not reproduce the original failure
or establish its complete cause. No new upstream correction or verification-policy
change follows from this diagnostic alone. The operational dependency remains
unchanged; a passing diagnostic is not a passing complete consumer gate.

A separate Chio-only experiment replaces the list's `onAppear` focus assignment
with native `defaultFocus`. All thirteen focused list tests and three narrow
appearance recipes pass on Linux ARM64. The first frame already focuses results,
removing one startup presentation, but the measured Control-E response changes
only from 2.11 to 2.04 seconds. This is not a demonstrated timeout correction.
Native default-focus arbitration also differs from unconditional appearance-time
focus assignment; remount and competing-focus equivalence remain unverified.
The experiment is not adopted.

The [complete appearance comparison](https://github.com/echoz/Chio/actions/runs/39694430747)
at diagnostic commit `0fddf56` passes all 22 cases in both configurations
using native `1a23ffc1`. Debug takes 109.713 seconds; release takes 16.405 seconds.
The three narrow Control-E responses take 4.20–4.84 seconds in debug and
0.71–0.79 seconds in release. Every narrow handler sets focus and scrolls
successfully; every matching frame arrives within the original five-second wait.
No timeout or late frame is captured. These instrumented results support a
debug-rendering budget explanation, without proving the original failure's cause
or replacing full consumer qualification.

The user approved release-only routine verification after reviewing these results.
This replaces the narrower proposal to move only two appearance workflows. Every
test, including layout, domain, component and composition cases, still runs in
release with unchanged assertions and deadlines. The transport preflight and the
engineering gate's compiler context also use release. Debug-only behavior and
native debug assertions are no longer part of routine qualification. The
[current gate](#running-checks) owns the accepted policy.

### Release verification qualification

At `487a389d09b6bf1477161a0d6cd36f6122dc9eec`, the complete local release gate
passes on macOS with Swift 6.4 and Xcode 27. It executes 852 tests and retains
one existing case-insensitive-filesystem skip. All snapshots, sixteen example
terminal probes, three appearance sessions, four map probes and both cache/pack
process probes pass. Existing appearance realization warnings remain visible.

Both jobs in [run 39699315848](https://github.com/echoz/Chio/actions/runs/39699315848)
pass on their first attempt. They test merge commit
`13bb0d46e3d2f8864a6dd0d69571af754d8e13f1`, combining that head with base
`04896a6ceb4d44bb7ed88950eaceb4d2c0a5aea6`. macOS reports suite totals of
510, 166 and 177; Linux reports 509, 166 and 177. macOS retains its filesystem
skip; Linux retains its permission-enforcement skip. Both jobs pass the transport
preflight, full release suites and all terminal and map process probes.

These runs retain SwiftTUI `877d7765febd08ffc2ed434a7ef231e4132c3b80` and every
assertion and five-second interaction deadline. The subsequent EngineeringRules
0.1.10 adoption changes only checker configuration, its wrapper pin and owning
documentation. Its application, test, dependency and runtime gate inputs match
the passing candidate, so these runtime results remain applicable. The shared
compiler gate needs its own fresh release-context check under the new tool.
Neither these results nor the policy change prove a debug-only startup fix.

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

The historical debug reproducer used the platform/toolchain setup below:

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
python3 -B Scripts/ci/test-swift-build-cache.py
bash Scripts/ci/verify.sh
```

The gate serializes builds and hosted tests. It runs all tests in release,
a standalone release build, 24 plain-text snapshots and
19 dashboard pseudo-terminal workflows, four dot-matrix sessions, plus the map example's fixture
reproduction and PTY workflow. Snapshot files are inspection artifacts;
Swift tests assert the rendering contracts.

A focused release preflight first checks real map HTTP transport and the online
view lifecycle. SwiftPM continues other test targets after one executable fails;
this exposes acquisition regressions before the longer composition suites. The
complete release suite still includes these checks.

Routine verification uses release builds for all tests, products and compiler
context. No test is excluded because of its suite or execution cost. Assertions,
five-second interaction waits and terminal/process checks remain unchanged.
This policy does not qualify debug-only behavior, native debug assertions or
debug rendering performance. Debug builds remain available for targeted
investigation, but are not a required verification step.

### CI source receipt

Both ordinary [CI](../.github/workflows/ci.yml) jobs invoke the local
[source receipt action](../.github/actions/source-receipt/README.md) after the
event checkout. Linux first installs its existing Python prerequisite. The default
checkout remains at the workspace root with its default shallow history and event
ref: pull requests test the synthetic merge; pushes and manual runs test
`github.sha`. Ordered commit headers establish the PR parent identities without
fetching their full histories.

Chio's public copy contains exactly four generic component files and their
[manifest](../.github/actions/source-receipt/reviewed-copy.json), exported from
`Void-Deck/ci-helpers` commit `ba95ede8d39f70369d817db8f1b1c2f8e5938086`.
The entrypoint checks the manifest and allowlisted hashes before loading the
receipt implementation.
An update requires another explicit export and review. No private action access
or private controller code is required.

The successful step emits compact JSON to its log and
`steps.source.outputs.receipt`. It separates repository, workflow, run, event,
PR base/head, tested checkout and component provenance. It writes no source
files. The receipt observes the runner's supplied identity; it does not establish
freshness, successful verification, independent review or merge approval.
The existing cache and verification gates retain their own contracts.

Expected identity failures report only a fixed validation category, including
`event-merge-commit`, `merge-parents`, `checkout-commit` or `git-read`. Observed
values and raw event, exception or subprocess text are not included. Unexpected
errors retain the generic diagnostic. A populated event `merge_commit_sha` still
requires full SHA format, but it is separate metadata and does not constrain the
tested source. [GitHub Actions selects its merge-branch commit](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request),
while [PR merge candidates are computed asynchronously](https://docs.github.com/en/rest/guides/using-the-rest-api-to-interact-with-your-git-database#checking-mergeability-of-pull-requests).
Those observations have no documented atomic equality guarantee. Actual
`HEAD == github.sha` and exact ordered event base/head parents remain required.
The supplemental field is not emitted; successful schema version 1 remains
unchanged. A category identifies a rejected check; it does not establish the
underlying cause or authorize a retry.

Validate the imported copy from the repository root:

```sh
python3 -I -c 'import runpy; from pathlib import Path; m = runpy.run_path(".github/actions/source-receipt/entrypoint.py"); m["reviewed_copy"](Path(".github/actions/source-receipt"))'
```

Run the upstream receipt contract fixtures at that immutable source revision.
Review the public export allowlist and CI wiring, then run the pinned documentation
gate. No Swift source, package, cache script or platform assertion changes in this
slice. These bounded checks do not establish hosted action evaluation, the
runner's actual event payloads or complete Linux/macOS product verification.
The existing full CI gate remains required when the candidate runs on GitHub.

The canonical component at this pin passes 38 process/Git and export-boundary
tests. Independent source integration review preceded the merged helper pin;
separate public-copy review and hosted adoption qualification remain required.
Earlier 31-, 35- and 37-test receipt suites qualify their preceding copies only.
[Run 40219704304](https://github.com/Void-Deck/Chio/actions/runs/40219704304)
at head `c1b52ca5e881a06507698bcfd97ba9c96b55e0ef` failed both receipt steps
before cache helpers or product tests began. No receipt was emitted. Visible
checkout and runner identities agree, but the rejected observation remains
unknown because the generic diagnostic did not identify its validation check.
[Run 40221305068](https://github.com/Void-Deck/Chio/actions/runs/40221305068) at head
`5a2acb85fe99df2af9bd28b1c76504b3f074f8a1` failed both receipt steps with
`event-merge-commit`. Its actual checkout and runner SHA agree; its real ordered
parents match the observed PR base/head. No receipt, cache or product qualification
result was produced. The raw field is unavailable, so this identifies the stage
without proving malformed data versus a different valid observation. The corrected
model retains malformed-field rejection and binds tested source through actual
checkout and parent checks.

[Run 40222465950](https://github.com/Void-Deck/Chio/actions/runs/40222465950)
at head `f3015d525cc94070750219560a2adca1c3ceaa89` passed complete macOS and
Linux gates. Both raw job logs emit matching schema-1 receipts for tested merge
`14f679eda37fc4b9b5a33f8d8dbb92a418859e41`, base
`9ff6e8e0c866ba2879eff33b2edc059dcc1ae884` and that head. Those receipts identify
the preceding Q-sourced component at `d4914f19327beece5180549ec19b416bb346dae0`.
Both platforms pass the 20 HTTP and six online interaction preflight tests,
13 cache-helper cases, standalone products and subsequent terminal/process gates.
macOS reports 528 library, 166 map, five matrix and 177 dashboard tests;
Linux reports 527 library, 166 map, five matrix and 177 dashboard tests.
Existing platform skips remain explicit. The fixture correction, production
source, dependency pins, workflow and verification scripts are unchanged by this
source-owner adoption, so that product evidence remains applicable to those
inputs. It does not qualify the new component provenance or its hosted loading.
Fresh Linux/macOS receipt and full product execution remain required for the
new exported copy. The original Linux crash's precise cause remains unproved.

### Exact-input CI build cache

`verify.sh` uses separate release scratch paths: `.build/ci-cache/tests` for both
test passes and `.build/ci-cache/products` for standalone product qualification.
SwiftPM retains its default backend. The existing Testing macro flags, resolved
dependency requirement, serial tests, production builds, snapshots and terminal
checks remain in force. Testable modules do not replace production qualification.
Results and captures stay in `.build/ci-results`; rules evidence stays in
`.build/swift-rules`. Neither belongs to the cache payload.

The CI workflow caches only `.build/ci-cache`. `Scripts/ci/swift-build-cache.py`
keys it by repository, absolute checkout path, architecture, compiler binaries,
Swift version/target, SDK identity and build environment. Linux also includes
the existing digest-pinned container and installed package versions. The input
inventory hashes file contents and modes, including the manifest, lockfile,
workflow, scripts, resources and tests. Ignored files within source roots and
`.swiftpm/configuration` are included. Unknown paths remain inputs. Only `Docs/`,
root `README.md`, `AGENTS.md`, `LICENSE` and the PR template are excluded because
the current build does not consume them. Changing that boundary requires a key
policy update. External path dependencies and mutable external toolchain/header
contents are outside this clean hosted-job contract.

The Git inventory command trusts only its canonical checkout through a
command-scoped `safe.directory` value. Container root can differ from the checkout
owner; this exception changes neither global Git configuration nor other commands.
Map probes disable generated Python bytecode so imports cannot change the input
inventory. Script source remains an input.

There are no broad restore keys. An exact hit must also have a matching input
record and complete, valid source timestamps before the helper restores mtimes.
It never restores source bytes. A miss or invalid record discards only the owned
cache directory, then runs the complete gate. Symlinked cache ancestors are
rejected. A successful gate records timestamps before saving. A corrupt exact
entry cannot be replaced under Actions' immutable key; it falls back to a cold
build until that entry expires or is removed.

Actions retains repository/ref trust isolation. This optimizes eligible reruns
and documentation-only changes; it does not promise reuse after source changes
or transfer of a pull-request cache to `main`. It never treats restored products
as passing test evidence. Caches save only after successful verification.

The helper regressions use temporary Git repositories and controlled compiler
identity fixtures. They establish input invalidation, metadata validation,
cleanup boundaries and gate failure propagation. They do not establish Swift
incremental behavior or cache transport performance. Qualification must measure
cold and warm full gates, including production builds, on macOS and Linux, plus
archive size, save/restore time and a restored archive run. Local archive success
does not establish hosted Actions transport or a net speed improvement.

#### Local qualification and remaining transport gap

Swift 6.4 release qualification retains the full gate and recreates all 446 input
files at the same paths before archive restoration. Hashes, modes and Git state
remain unchanged; restored mtimes permit reuse without restoring source bytes.
The cold runs start with empty build stores, not empty global download caches.

| Local measurement | macOS arm64 | Linux arm64 guest |
| --- | ---: | ---: |
| Cold full gate | 995.03 s | 1,265.57 s |
| PAX/gzip archive | 1,324,871,100 bytes | 1,089,375,405 bytes |
| Archive save | 82.80 s | 73.81 s |
| Archive extraction | 12.24 s | 5.59 s |
| Metadata restore | 0.50 s | 0.42 s |
| Restored full gate | 547.98 s | 631.49 s |
| Extraction, metadata and restored gate | 560.72 s | 637.50 s |

These single-pair measurements reduce local restore-plus-gate time by about 44%
and 50%, respectively. Save cost is separate. Linux uses the pinned image's arm64
variant with two CPUs, 8 GiB and Apple Container virtiofs. Its GNU-created archive
was restored with host BSD tar. GNU extraction on that mount failed at eight
relative symlinks; that failed attempt remains recorded. This does not qualify
GNU extraction on Linux local disk, hosted amd64 or Actions' archive transport.

Both platforms' cold and restored phases retain matching 24 snapshots, standalone
production builds, 19 dashboard terminal workflows, four dot-matrix sessions,
four map workflows and cache/pack process probes. Each macOS phase records 900
cases and each Linux phase 899, including repeated preflight cases, with zero
failures/errors. macOS skips one case-ordering test on its case-insensitive
filesystem; Linux skips one permission test under root. Three documented
`collection.unboundedRealization` appearance warnings remain visible per phase.
The pinned rules gate checks 368 files with one retained baseline item and the
supplied native release compiler context.

The first Linux cold gate passed, but its cache record rejected generated Python
bytecode. The four map imports now disable those writes. The later restored guest
gate and final record pass; its host recording wrapper then failed in an exit
trap. Independent inspection confirms the successful guest outcomes while
preserving the wrapper's failed result. No failed attempt is relabeled as passed.

macOS full-gate evidence predates the Python invocation correction. All full-gate
evidence predates the command-scoped Git ownership correction. These changes affect
verification scripts only; unchanged Swift/compiler evidence is reused explicitly.
Before the Python compatibility correction, thirteen helper regressions passed
on both platforms, including real Git rejection before and after scoped inventory
access. Earlier archives retain their original
identities; they do not establish a restore under the final helper's new key.

The first [hosted macOS cache-helper run](https://github.com/Void-Deck/Chio/actions/runs/40170149677/job/121099164783)
fails before Swift verification on Python 3.15. The test reads module `__cached__`,
which Python 3.15 no longer populates. It now reads `__spec__.cached` and preserves
the parser subprocess's error output. The regression removes the legacy attribute
after a real import on older interpreters, verifies suppressed and enabled bytecode
writes, and checks that import errors remain visible. Local red/green checks cover
Python 3.9.6 and 3.12.14. A separate isolated CPython 3.15.0 arm64 runtime on macOS
also reproduces the missing attribute naturally and passes all thirteen corrected
regressions. This establishes actual interpreter compatibility independently of
the hosted runner, whose successful log does not print its Python version.
Only the test and documentation change in this correction. Prior Swift evidence
remains applicable; cache acceptance and source-integrity checks are unchanged.

#### Hosted qualification

[Run 40171238926, attempt 1](https://github.com/Void-Deck/Chio/actions/runs/40171238926/attempts/1)
passes both complete gates for head `7a0f1d3569e1fb4a1cc144302fb37576c919ce0c`,
through tested merge `6108c5216ab58fe0114850301a0df2516440f779` and base
`796b1b9527d72ef7eb5365fa956d3d780b0c9961`. Both jobs pass thirteen helper tests,
seven compiler-pin tests, the complete release suite, standalone product builds
and terminal/process verification. macOS records 900 Swift tests and Linux 899,
including repeated preflight cases and the existing platform-specific skips.
The three documented appearance warnings remain visible on each platform.

| Hosted cold measurement | macOS arm64 | Linux x86_64 |
| --- | ---: | ---: |
| Full gate | 1,744 s | 1,759 s |
| Complete job | 1,792 s | 1,941 s |
| Saved archive | 1,206,580,248 bytes | 1,073,330,261 bytes |
| Cache save step | 21 s | 116 s |
| Compression | zstd | gzip |

Both cache lookups miss and both saves succeed. macOS uses image
`xcode-27-arm64/20261023.0307.1`; Linux uses `ubuntu-24.04/20261012.334.1`
with the workflow's digest-pinned Swift container. These cold results establish
hosted saving and full verification, but not a successful restore or a speedup.

The GitHub integration denies a manual rerun with `Resource not accessible by
integration`. The documentation-only evidence update triggers normal PR checks;
the guarded build inputs remain identical. The next run must establish exact-hit
acceptance, archive restoration, another complete passing gate and net timing.
The PR stays draft until that qualification and independent review pass.

To run the complete test suite separately, keep hosted tests serial:

```sh
swift test -c release --no-parallel
```

To exercise an already-built binary:

```sh
dashboard_binary="$(swift build --scratch-path .build/ci-cache/products -c release --show-bin-path)/chio-dashboard"
python3 Scripts/ci/terminal-smoke.py "$dashboard_binary"
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

The HTTP test fixture avoids `FileHandle.readabilityHandler`. Hosted Linux run
[40213524172](https://github.com/Void-Deck/Chio/actions/runs/40213524172) crashed in
`_dispatch_event_loop_drain` during its first HTTP case. The stack matches the
upstream [epoll read-source lifetime defect](https://github.com/swiftlang/swift-corelibs-libdispatch/issues/949),
but the retained log does not establish this crash's precise cause. The fixture
now polls nonblocking stdout for readiness and owns one asynchronous nonblocking
stderr drain. Cleanup terminates the child, cancels and awaits that reader, then
closes its handle. Retained stderr remains capped at eight KiB while excess bytes
are drained. Startup, transfer and cleanup deadlines and assertions are unchanged.
The focused regression rejects invalid readiness and stdout EOF after substantial
stderr output and checks bounded diagnostics. The unchanged fixture passes both
platform preflights and full gates in [run 40222465950](https://github.com/Void-Deck/Chio/actions/runs/40222465950),
as detailed in the [source receipt evidence](#ci-source-receipt). A successful
repetition alone does not prove the original race is repaired.

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

### Dot matrix

Frame verification must cover RGB/intensity ranges, every nonfinite channel,
nonempty rectangles, checked decoding, preserved matrix data and frames above the
former 65,536-LED cap. Verify the `matrix` source API and retained `rows` coding
key. Public raster checks cover independent colors, intensity scaling, inactive
glyphs, spacing, inherited style overrides, fitting, accessibility and surface
rejection. Verify the unchanged 262,144-terminal-cell guard, including gaps,
and dimension rejection before spaced arithmetic. These renderer checks do not
establish application input, frame memory or runtime budgets.
Example tests retain independently expected lettering and changing icon frames.

Run the focused suite in release and require actual Swift Testing output:

```sh
swift test -c release --no-parallel --filter 'DotMatrix|MatrixScene'
python3 -B Scripts/docs/capture-dot-matrix.py .build/release/chio-matrix \
  --output .build/dot-matrix-review
```

The real PTY probe exercises frame replacement, application-owned animation,
shape, spacing, intensity, narrow/tiny recovery and native two-axis scrolling.
Each session must restore the original terminal state and exit cleanly. Retain
raw session diagnostics separately from the trimmed publication recording.
Generate PNGs from the retained initial casts with the existing terminal preview
renderer, and inspect all three theme previews. Supplied image colors remain
fixed across themes; surfaces and unlit dots consume theme presentation.

The complete CI gate builds `chio-matrix` and runs this probe on macOS and Linux.
These checks do not establish hardware simulation, LED calibration, SSH latency
or every terminal font. The [decision](Decisions/DotMatrix.md) owns public bounds.

### Demo site

The [showcase](https://echoz.github.io/Chio/) assembles seventeen recordings and 51
three-theme previews from `Docs/Media`, using the pinned local asciinema player
in `Docs/Site`. Its upstream license remains with the vendored assets. The catalog
opens on Maps and separates Chio views, styles for native SwiftTUI controls and
example apps. Featured Maps and DotMatrix previews above the catalog link to
their matching entries. With scripts, activation retains the selected theme,
reveals the catalog and moves keyboard focus to its selected option. Native
fragment links remain usable without scripts. Entries identify public APIs,
native controls, application-owned behavior, source, launch command and keyboard guide. Minimal view fragments name
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
Xcode 27 and the Swift 6.4.0 Ubuntu 24.04 container. The Linux job retrieves
[Docker's official Swift image](https://hub.docker.com/_/swift) from Docker Hub,
pinned by its multi-platform digest. Anonymous registry access verifies the image
index and its Linux x86_64 manifest. The former ECR mirror repeatedly failed before
checkout with `toomanyrequests: Data limit exceeded`; switching registries retains
the exact image and requires no account credentials. Builds/tests serialize within
each job; artifacts retain logs, text captures and xUnit reports.
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
