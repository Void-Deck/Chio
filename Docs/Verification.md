# Chio verification

Current requirements for implementation, dependency and visible example changes.
[Plan](Plan.md) tracks active work; [release records](Releases/0.1.0.md) preserve
revision-specific results. For documentation-only changes, check links, anchors
and preservation of current contracts.

## Shared engineering rules

Chio pins [EngineeringRules v0.1.4](https://github.com/echoz/EngineeringRules/releases/tag/v0.1.4)
(`fc3de546794e7e4b0429b0b03e282ac7218bde8b`) through
[.swift-rules.json](../.swift-rules.json). This is a required local development
gate alongside the compiler, tests and platform checks below. It is not a package
dependency or a guarantee of purity, correct enum policy or API compatibility.

Install the pinned tool from its repository using its README. Keep a local
EngineeringRules checkout containing that release tag. On this Mac, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash Scripts/ci/check-rules.sh /path/to/EngineeringRules
```

Full Xcode supplies the required Swift/SourceKit. On Linux, omit `DEVELOPER_DIR`
and follow the pinned tool's Swift 6.4 and Ubuntu Noble requirements. The normal
gate does not install tools or edit source, configuration or baselines; a missing
pinned installation is a failed prerequisite. It verifies the release commit,
exports the shared compiler-context helper from that immutable revision, builds
the actual `Chio` target with SwiftPM's native backend, and supplies its real
compiler arguments to the checker. The helper stays in EngineeringRules; Chio
does not copy or maintain its implementation.

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

The initial [.swift-rules-baseline.json](../.swift-rules-baseline.json) records
reviewed existing findings, with exact paths, source anchors and occurrence counts:

- Older test-fixture constructor shorthand is adoption debt. Replace it with
  concrete types when changing the owning suite, then prune the fixed entries.
- `MapShapeSimplification.Budget.remaining` is invocation-owned, private scratch
  storage passed `inout` through bounded geometry work. Its local mutation is an
  intentional exception to the checker's lexical stored-property rule; public
  domain inputs remain immutable. Preserve its work and cancellation bounds.

New findings and stale baseline entries fail the check. Baseline expansion,
exclusions and tool upgrades require review; do not regenerate the baseline to
silence failures. Inspect rule categories for checker limitations before changing
application behavior. The shared tool owns rule implementations.

EngineeringRules is private. This local gate does not add credentials or a private
fetch to Chio's public CI or package build. Hosted lint requires a separate tool
distribution/access decision; the public platform gate below remains required.

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

## List row spacing qualification

**Status:** BLOCKED. The added `ChioListStyleTests` qualification suite uses the
public raster and hosted-session APIs against the unchanged SwiftTUI revision
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

Run the focused reproducer with the platform/toolchain setup below:

```sh
swift test --force-resolved-versions --jobs 2 --no-parallel --filter ChioListStyleTests
```

No new spacing API or showcase assets are qualified. Fresh release, Linux, PTY,
pointer and broader style-change checks remain outstanding. The completed #16
gates cover their exact merged tree; they do not cover these new qualification
cases. Native interaction ownership, assertions and deadlines must remain intact
when resolving this blocker.

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
compatibility aliases and retained `theme:` initializer signatures. Cover explicit
surface overrides and `.base` inheritance after palette replacement; construct,
replace and decode bounded input padding, including the historical absent key.
Use public raster and hosted-session checks for the supported searchable composed
lists: native focus, selection, query, activation and scroll reveal through width
and style changes. New per-row density controls are in qualification under the
[native list conditions](Decisions/NativeIntegration.md#tall-list-rows) and
[the current checks](#list-row-spacing-qualification).
Single-line truncation limits row height but does not establish that arbitrary
list/checklist scrolling is safe or fix the separate reproduced focus failure.
Inspect unchanged default/light presentation, the intentional btop border-heading
change, and opencode leading edges, roomy inputs and compact list rows.
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
Both jobs allow sixty minutes for the complete gate. Earlier forty-five-minute
caps cancelled runs during forward progress: Linux after its test suites passed,
and macOS after all debug/release suites and dashboard terminal workflows passed,
as the map build started. The larger job budget preserves all test assertions,
frame deadlines and terminal workflows; it does not extend an individual test's
deadline or establish that a stalled test is healthy.

[0.1.0 verification](Releases/0.1.0.md#platform-verification) records the tested
platforms. Ordinary Linux executables need the Swift/Foundation runtime libraries.
Future failures require evidence and must not be hidden by weakened tests.

For static distribution, see the current [dependency decision](Decisions/Dependencies.md#static-linux-blocker).
