<a id="chio-plan-and-verification"></a>

# Chio plan

This document tracks active work, next steps and open questions. Current contracts
live in [Design](Design.md) and its decision index; implementation and showcase
checks live in [Verification](Verification.md). Completed release scope and results
live in [0.2.2](Releases/0.2.2.md) and [0.2.0](Releases/0.2.0.md), with
[0.1.0](Releases/0.1.0.md) retained as history.

## Current slice: dot matrix visual study

The user approved an isolated prototype on 2026-10-23. Lettering and an animated
icon will use the same immutable, bounded frame and native Canvas presentation.
The [study](../Spikes/DotMatrix/README.md) owns its run commands and constraints.
One terminal cell per LED preserves independent colors; fixed pitch preserves the
grid on resize, with an authored text fallback when the complete grid cannot fit.
The example owns timing and interaction. No public Chio API changes in this slice.

The isolated implementation now renders lettering and a four-frame heart through
the same view. Actual terminal captures qualify round/square dots, amber/green
lettering, narrow/tiny text fallbacks, animation and paused-frame resize recovery.
The study's [findings](../Spikes/DotMatrix/README.md#findings--2026-10-23) distinguish
macOS terminal/player evidence from untested fonts, SSH and Linux appearance.
Review the look before public promotion. Numeric lettering may extend
`InstrumentReadout`; arbitrary imagery needs a separate view only if the shared
presentation proves useful. The public showcase remains unchanged during this study.

## Chio 0.2.2 release and consumer adoption

[Chio 0.2.2](https://github.com/echoz/Chio/releases/tag/v0.2.2) was published on
2026-10-23 at `4ded80f870fb2c92c92d7d402fd71d42213ecee8`, after
[PR #24](https://github.com/echoz/Chio/pull/24) merged. It pins SwiftTUI
`3999a9a57dde52fb00aa98952460b0819a0641bf`, including merged #62, #63 and the
stream-input scheduling correction. The seven other dependency pins remain unchanged.
The [release record](Releases/0.2.2.md) owns installation, scope and limits;
[Verification](Verification.md#borrowed-output-adoption-qualification) records the
passing PR gates for the same source tree, final installation and pending post-merge CI.

Blackbox found the [borrowed-output policy issue](Decisions/NativeIntegration.md#borrowed-output-policy-on-macos)
during the earlier adoption trial. The published release includes its native
correction and Chio's scoped [private-focus compiler workaround](Decisions/NativeIntegration.md#private-focus-metadata).
Earlier `65043a7b` results remain historical; the merged `3999a9a5` input received
fresh platform, terminal, consumer and independent-review qualification.

The user approved publication and coordinated consumer adoption on 2026-10-22.
Release preparation started from merged PR #23. Requests reached
the owning Marquee, Blackbox and Pitwall tasks, and all three tasks have started.
Their earlier isolated affected-path refreshes passed; final adoption of the
published commit remains in progress. Each owner must resolve both requirements,
verify its integration and preserve its publication and merge-approval boundaries.
Dispatch and candidate verification do not establish completed downstream adoption.

<a id="current-slice-merged-palette-and-scroll-focus-fixes"></a>

## Delivered: merged palette and scroll-focus fixes

The user approved adopting merged SwiftTUI #58 and #59 on 2026-10-19. Qualification
exposed deferred callback-owner reads and stacked observation-slot collisions.
[SwiftTUI #60](https://github.com/SwiftTUI/swift-tui/pull/60) corrects both and is
merged as `877d7765febd08ffc2ed434a7ef231e4132c3b80`.
That adoption resolved the exact canonical upstream revision;
0.2.2 retains those corrections in its newer pin. SwiftTUI 0.18.3, the latest
published release checked for this slice, predates these fixes.
[Dependencies](Decisions/Dependencies.md#palette-and-scroll-focus-adoption)
owns the revision and behavior contract.

On 2026-10-20 the user approved native navigation that skips disabled rows.
Choices remain visible and cannot toggle; search remains editable when no enabled
result can receive focus. The checklist guard and its public interaction tests
belong to this adoption slice. Chio adds no callback or scrolling workaround.

The user approved release-only routine verification after the debug timing
investigation. At `487a389`, the complete local release gate and both hosted
macOS/Linux gates pass. Every test remains included, with unchanged assertions
and five-second waits. Terminal workflows, snapshots and map process probes pass.
[Verification](Verification.md#release-verification-qualification) records the
exact candidate and tested merge. Earlier canonical installation and public
API/raster checks retain the same source and dependency inputs.

EngineeringRules 0.1.10 adds support for native release compiler context. This
PR advances the tool pin and immutable helpers together without changing the
application, dependency, baseline or runtime verification inputs. The
[adoption record](Verification.md#0110-adoption) owns its local checker evidence.
PR #23 merged as `6df2e336f5a398d34a37e98e431250f8dcaeca02` after checks and
separate review passed. Its complete post-merge macOS/Linux gate also passes.
Release publication and downstream adoption remain separate evidence.

The earlier debug failures and isolated experiments remain in the
[qualification record](Verification.md#startup-input-investigation). PR #23 adopted
neither SwiftTUI #62 nor the private focus-type experiment. The published 0.2.2
release includes the scoped focus-type workaround and merged #62 described
above. Release qualification does not establish debug-specific consumer behavior.

## Delivered maintenance: naming review

[PR #22](https://github.com/echoz/Chio/pull/22) merged EngineeringRules 0.1.9 at
`04896a6ceb4d44bb7ed88950eaceb4d2c0a5aea6`. Its unchanged full hosted macOS and
Linux gates pass, together with compiler-backed rules, documentation, naming
inventory, focused help tests and independent review. The first Linux attempt
failed before checkout; the Linux-only retry supplies the passing evidence.

The private `HelpExampleView.Context` is now `ShortcutScope`, without a behavior
change. The released review workflow covers all changed names and relevant
identity/revision lifetimes. An empty inventory does not complete semantic review.
[Verification](Verification.md#019-adoption) owns the disposition and evidence.
This SwiftTUI adoption branch includes that exact maintenance change; published
Chio 0.2.1 retains its recorded EngineeringRules 0.1.7 pin.

[PR #21](https://github.com/echoz/Chio/pull/21) delivered EngineeringRules 0.1.7,
schema 2 and source-root guides. It and the test-constructor cleanup in
[PR #20](https://github.com/echoz/Chio/pull/20) are included in published
[Chio 0.2.1](https://github.com/echoz/Chio/releases/tag/v0.2.1).
Consumer adoption is underway in the owning Marquee, Blackbox and Pitwall tasks;
dispatch is not completed adoption. The later SwiftTUI dependency update is
separate from this maintenance release.

## Current slice: Chio 0.2.0 release

The user approved a 0.2.0 source release on 2026-10-15, then added list-row spacing
and removal of the legacy theme API to its scope. The user subsequently approved
cutting 0.2.0 with the exact merged SwiftTUI #57 revision, followed by a 0.2.1
dependency patch after SwiftTUI publishes a release containing the correction.
The user also requires EngineeringRules 0.1.5 and its documentation gate before
publication. [PR #19](https://github.com/echoz/Chio/pull/19) targets the release
branch and is merged at `af6cb366`; its local developer gates and separate review
pass. The combined candidate `bdd9fcd93f7e44d058bcb7075a8bf0ee1e3c8cab`
passes the complete hosted macOS/Linux gate, compiler and documentation checks,
external-consumer installation and independent review. Its unchanged application
code also passes the complete local gate, refreshed captures and browser checks.
The earlier Linux run reached its one-hour job limit during an active map probe.
The passing combined run uses a 90-minute Linux limit, with unchanged assertions
and interaction deadlines. Final changes reconcile documentation only; tag and
published-site verification follow merge.
[PR #18](https://github.com/echoz/Chio/pull/18) carries
the release preparation. The [release record](Releases/0.2.0.md)
owns scope, migration and evidence. Publication requires reviewed implementation,
applicable checks, consumer installation and showcase verification, followed by
verification of the immutable tag and published release.

Marquee, Blackbox and Pitwall are the confirmed application consumers. Their
owning tasks are preparing focused upgrades and will use the published 0.2.0
commit with its exact SwiftTUI dependency. Dispatch is not completed adoption; each
project retains its own checks and merge approval.

<a id="latest-slice-online-maps"></a>

## Delivered map scope

World and street maps use explicit offline or opt-in online sources. Markers,
routes, adjustable detail and outline presentation compose with native Canvas.
Persistent raw-tile caching, programmatic read-only packs, forward/reverse place
lookup and routing adapters are implemented. Their owning decisions appear in
[Design](Design.md); provider comparisons remain shelved and archive downloads
remain paused. The release adds no further map feature.

<a id="current-slice-responsive-instrumentation"></a>
<a id="current-slice-unified-styles-and-appearance-comparison"></a>

## Completed implementation: unified styles and appearance comparison

**Status:** Public API consolidation implemented and verified in
[PR #10](https://github.com/echoz/Chio/pull/10), included in the 0.2.0 scope.
The Pages workflow publishes the showcase after merge to `main`.

Responsive instrumentation and target dials merged in
[PR #8](https://github.com/echoz/Chio/pull/8) and
[PR #9](https://github.com/echoz/Chio/pull/9), also included in the 0.2.0 scope.

Themes and example recipes use immutable `ChioStyle` values applied
with inherited `View.style(_:)` and one environment key. The release slice removes
the former `ChioTheme`/`.chioTheme(...)` forwarding by explicit user request.
Static default/light/btop/opencode values
compose colors, spacing, treatments and surfaces. Leading edges and input
surfaces/padding are public style values; applications retain breakpoints,
column widths, data and navigation. [Styles](Decisions/Themes.md) owns
the accepted contract; [Usage](Usage.md#styles) owns customization recipes.

Verification passes: compatibility and checked-value tests, public raster/hosted
state and focus checks, independent API review, pinned SwiftRules, and refreshed
terminal captures at 100 × 30 and 36 × 64 with interactive 36 × 18 checks.
Browser verification covers all six comparison clips, matching commands,
playback, navigation, 390-pixel layout and asset fallbacks. The main catalog
retains default/light/btop previews; the comparison adds opencode.

At `4ea9e9411cf058a870ae535ca500274458ec9322`, the full hosted
[macOS and Linux gates](https://github.com/echoz/Chio/actions/runs/38192949634)
and [site build](https://github.com/echoz/Chio/actions/runs/38192949637) pass.
The final status refresh changes documentation only. Earlier intermittent
tab/FilePicker failures are not claimed fixed; individual assertions and
deadlines remain unchanged. Native list and teardown limitations remain explicit
in [native integration](Decisions/NativeIntegration.md).

**List spacing follow-up:** per-row density controls were excluded from this
slice's public API. The current pin includes SwiftTUI's merged per-axis reveal
correction in [#46](https://github.com/SwiftTUI/swift-tui/pull/46) and
measured-height navigation/builder correction in
[#47](https://github.com/SwiftTUI/swift-tui/pull/47).
[Native integration](Decisions/NativeIntegration.md#tall-list-rows) owns the
remaining qualification conditions; the current list-spacing slice below
must establish Chio's padded and multiline row contracts before releasing the token.

Provider archive acquisition remains on hold at the user's request. No archive
reader or downloader has been adopted; existing local pack APIs remain available.

<a id="native-runtime-follow-up"></a>

## Delivered: native runtime and CI corrections

**Status:** [PR #16](https://github.com/echoz/Chio/pull/16) merged on 2026-10-14
at `b79f0096fbc19872bd91cc887b03048e7e9d2a47`, with the same tree as the verified
`0d42bfd41a0316c85c95fbb520641df3785f6eb5` candidate. The complete hosted
[macOS/Linux gates](https://github.com/echoz/Chio/actions/runs/38546312684) pass.
The approved immutable SwiftTUI revision contains the merged disclosure, Spacer
and measured-row corrections. All sixteen retained layout failures are resolved;
accepted map results now publish desired native focus together, and the example's
functional periodic clock continues under CI's reduced-motion policy.
[Verification](Verification.md#merged-layout-corrections) owns exact evidence and
limits; [Dependencies](Decisions/Dependencies.md#merged-layout-corrections)
owns the pin and future published-release qualification. Historical intermittent
tab failures passed the final gate, but their cause remains unproved.

SwiftRules 0.1.4 is adopted on `main` through
[PR #15](https://github.com/echoz/Chio/pull/15). The final #16 candidate passes the
compiler-backed gate with 351 files and 398 retained baseline findings, without
baseline expansion. [Verification](Verification.md#014-adoption-candidate)
retains the adoption evidence. These merged changes are not a new tagged Chio
release or proof of completed downstream adoption.

## Approved map expansion

**Status:** Scope approved on 2026-10-09. Persistent caching is implemented;
programmatic local packs are implemented.
Forward/reverse geocoding and the routing service slice are merged.
Provider downloads remain paused. The following order keeps
one testable slice at a time; current contracts live in the owning decisions.

The preceding robustness slice fixes the two reproduced audit defects:
[overflow-safe keyboard-hint spacing](Decisions/KeyboardHelp.md) and
[conservative polygon admission](Decisions/GeographicMaps.md#detail-and-geographic-limits).
Focused regressions cover constructed/decoded extreme gaps, accepted uncontained
rings, ordinary contained holes, native rendering and bounded topology checks.
The opt-in persistent cache preserves the raw
tile pipeline; [its storage contract](Decisions/OnlineMaps.md#persistent-raw-tile-cache)
defines identity, freshness, bounds and recovery. Before delivery, its
[verification gates](Verification.md) require independent review, unit and real
process checks on macOS/Linux, and the updated showcase. Programmatic offline
packs now provide durable read-only backing with separate retention; provider
downloads remain the next acquisition slice.
The [provider recommendation](Decisions/OnlineMaps.md#explicit-effects-and-source-configuration)
uses the existing explicit OpenFreeMap discovery API; it adds no provider registry
or implicit network behavior.

| Order | Capability | First useful outcome and acceptance evidence |
| --- | --- | --- |
| 1 | Persistent tile cache | Reuse acquired raw tiles across launches through the existing decode/preparation pipeline. Prove source isolation, bounded disk use, freshness rules, eviction, corrupt-entry handling and interrupted-write recovery. |
| 2 | Programmatic offline tile packs | Prepare or supply a checked pack in application code, then use its durable read-only tiles through the shared loader and memory cache without network access. Preserve coverage, attribution, identity and checksums. Follow with bounded programmatic acquisition from a download-permitted source; incomplete preparation must not appear complete. |
| 3 | Geocoding | Forward place/address search and reverse coordinate lookup through an explicit provider adapter. Return bounded results that applications can turn into markers and camera changes; prove no-result/failure distinctions, cancellation and stale-result rejection. |
| 4 | Routing | Explicit route requests between supplied locations through a provider adapter, returning checked geometry and available distance/duration metadata. Compose with existing route overlays; prove no-route/failure distinctions, cancellation, stale-result rejection and route work limits. |

<a id="next-slice-place-search"></a>

### Delivered: place search

**Status:** [PR #11](https://github.com/echoz/Chio/pull/11) merged on 2026-10-13
at `ec41b3f`. This is merged source, not a new versioned release. The
[place-search decision](Decisions/PlaceSearch.md) owns the explicit Photon endpoint,
immutable matches and attribution, and example-owned native search/list
composition. Camera and marker activation reuse the existing map API. There is
no new public search view, automatic type-ahead request or provider registry.

The candidate includes checked values, bounded shared HTTP transport, Photon
decoding and an opt-in live endpoint. The example defaults to synthetic local
search fixtures independently of its map source. At `b4b406e`, before the
SwiftTUI upgrade, the required local and hosted macOS/Linux gates passed, with
focused debug/release and terminal checks repeated after the row-color and
deferred-focus corrections. The pinned engineering gate and independent review
passed for that candidate. A bounded
live Photon search returned attributed results and opened a marker with zoom
retained. This proves adapter integration, not service availability or search
quality. Refreshed default/light/btop terminal previews and the search recording
pass visual inspection. Safari checks cover matching commands, playback and
seeking, navigation/history, a 390-pixel viewport and script-free/missing-player
fallbacks. Those captures and browser checks qualify the earlier dependency pin.

On 2026-10-13, the place-search branch incorporates merged main `a6c881c` and
released SwiftTUI 0.17.0 without changing map production, example or test code.
Fresh focused debug and release checks each pass 42 tests across checked values,
Photon decoding, real HTTP transport, submitted search and online map interactions.
The pinned engineering gate, site assembly and independent integration review pass.
The release map PTY workflow passes submitted search, activation, attribution,
compact resize recovery and exact terminal restoration, with no runtime warnings
or logs. These are focused local checks; earlier complete gates do not qualify
this combination. The [accepted native layout limitations](Decisions/Dependencies.md#0170-adoption-candidate)
remain explicit. At `00462d5`, the [site build](https://github.com/echoz/Chio/actions/runs/38464226914)
passes. The [macOS/Linux gate](https://github.com/echoz/Chio/actions/runs/38464227036)
reports the same 16 accepted debug issues on both platforms: disclosure placement
(3), compact inbox dimensions (3), tree contents (9) and nested expansion (1).
All 154 map tests pass on both platforms. The debug failure prevents the script's
release and terminal stages from running; focused local release evidence above
is separate. The merge retains those accepted native limitations.

Reverse lookup is delivered below; routing follows and provider downloads remain paused.

### Delivered: reverse lookup

**Status:** Separate capability and Photon client approved on 2026-10-13;
implemented on top of place-search PR #11 and merged in
[PR #13](https://github.com/echoz/Chio/pull/13) at `d940d56` on 2026-10-13.
This is merged source, not a new versioned release.

`MapPlaceLookup` composes a checked coordinate and bounded limit;
`MapReverseGeocodingProvider` keeps forward-only providers compatible.
`PhotonReverseGeocoder` requires its own complete endpoint and reuses the existing
attributed matches and bounded transport. The example adds explicit **Look up
centre** through the same cancellation owner and native result list, with local
fixtures by default. [Place search](Decisions/PlaceSearch.md#separate-reverse-lookup)
owns the accepted contract; [Verification](Verification.md) owns the checks.

Focused debug and release checks each pass 51 tests on macOS and Linux arm64,
covering values, real HTTP, mixed-direction cancellation and native interactions.
The final presentation refinement also passes its 13 release interaction tests.
The full local debug run passes all 157 map tests and retains the same 16 accepted
disclosure/inbox/tree issues as the forward candidate; the script stops before its
release/terminal stages. The separate standalone release build and three-theme
PTY workflows pass, including lookup, compact recovery, exact terminal restoration
and no runtime logs. Pinned SwiftRules and independent API/concurrency review pass.

A single live public-landmark lookup returned an attributed Photon match and
opened it with zoom retained; this establishes integration, not availability or
geographic accuracy. Refreshed default/light/btop previews and the complete local
Safari recording pass visual inspection, including seeking, the clean final frame,
matching theme commands and the new API link. Existing unaffected mobile/fallback
evidence is reused; no fresh mobile browser run is claimed. No tile acquisition or
routing is added by those geocoding changes.

### Delivered: submitted routing

**Status:** [PR #14](https://github.com/echoz/Chio/pull/14) merged on 2026-10-13
at `6f3c630`, after the SwiftRules upgrade in #15. This is merged source, not a
new versioned release. The first service slice provides an explicit OSRM endpoint,
checked two-point route requests and attributed geometry/estimates, composed through existing overlays.
[Routing](Decisions/Routing.md) owns the API, limits and example behavior.

The example remains fixture-backed by default and owns submission, cancellation,
latest-pending replacement and stale-result rejection. No default live service,
automatic rerouting, turn-by-turn navigation or renderer changes are included.
Focused macOS/Linux checks and browser review pass; terminal captures are refreshed.
The routing showcase is deployed. Its original SwiftTUI 0.17.0 failures and
intermittent place-search focus timeout preceded the completed
[native and CI corrections](Verification.md#merged-layout-corrections).
Provider downloads stay paused.

<a id="current-slice-restore-ci-and-diagnose-interaction-timeouts"></a>

<a id="current-slice-list-row-spacing"></a>

### Current slice: list row spacing and style migration

[PR #17](https://github.com/echoz/Chio/pull/17) merged SwiftTUI 0.18.0 adoption at
`7d44bd6bd85290f2c6e3526cf19e6647d551797c`. It contains the native measured-height
retention fix from [SwiftTUI #56](https://github.com/SwiftTUI/swift-tui/pull/56).
All eighteen unchanged list qualification cases pass in debug and release on
macOS and Linux, alongside the complete consumer gates and independent review.
The first macOS attempt hit the documented tab timeout; the unchanged retry
passed, without establishing that intermittent issue's cause.

The user approved this slice before 0.2.0 publication. `listRowVerticalInset`
adds 0...32 terminal cells above and below each complete Chio searchable-list or
checklist row, including its marker and selected surface. It defaults to zero;
the OpenCode preset and roomy example override use one. File picking inherits
the token through its searchable list. Native `ListStyle` has no per-row padding
hook, so application-authored native `List` rows use ordinary padding with the
same value. There is no new renderer, row wrapper or focus/scroll system.

The user also approved a breaking style migration: remove `ChioTheme`,
`.chioTheme(...)`, the old environment accessor and style compatibility overloads.
Current code and examples use `ChioStyle`, `.style(...)` and `\.chioStyle`.
Persisted spacing keeps absent optional keys at zero; malformed values still fail.

Local debug and release checks pass the eighteen retained regressions and fifteen
of seventeen new row-spacing cases. The two mixed-height style-change cases expose
a native focus-recovery gap: increasing row padding at the same viewport size
moves focus from ID 7 to ID 6. These are historical results on 0.18.0. The native
correction in [SwiftTUI #57](https://github.com/SwiftTUI/swift-tui/pull/57) is merged;
the approved 0.2.0 candidate uses its exact merged revision below.
[Verification](Verification.md#dynamic-row-spacing-candidate) owns the evidence.

An isolated copy passes the unchanged dynamic style-change, retained list and
appearance checks in debug and release against the native candidate. That
candidate passes the complete local gate and all hosted checks. Expanded focus
regressions at native `0d39074a` pass focused checks, the full local gate, all
hosted checks and independent review. The user approved expanding #57 after broader
tests found eager-table row overlap and missing focus in direct outline-list
initializers. Candidate `ab0c305d` fixes both and adds hidden-row update journeys
across lists, tables, outlines and both lazy stack directions. Focused checks,
independent review and isolated Chio debug/release requalification pass. Its
complete local gate passes all 85 steps, and all 24 hosted checks pass across six
workflows. #57 merged on 2026-10-15 Pacific (2026-10-16 UTC) at
`7e62e95c913508f4fef42db36fde6fd60acb541c`. The latest published SwiftTUI release
checked for this slice is 0.18.0, which lacks #57. Final Chio qualification of the
merged pin passes on macOS and Linux, with installation, terminal and review
evidence recorded in [Verification](Verification.md#020-merged-pin-qualification).
SwiftTUI #58 and #59 were separate upstream follow-ups outside 0.2.0 adoption.
Their later merged adoption is tracked in the [current slice](#current-slice-merged-palette-and-scroll-focus-fixes).
The historical external-consumer probe passes the canonical API on SwiftTUI
0.18.0. Refreshed terminal recordings,
preview inspection, site assembly and focused Safari checks pass. Capture-only
cleanup removes native startup announcements from published clips while retaining
full raw logs. [Verification](Verification.md#demo-site) owns the showcase workflow.

After a SwiftTUI release includes #57, prepare the approved Chio 0.2.1 patch.
Align the exact SwiftTUI requirement and lockfile, run the complete consumer and
installation checks, obtain separate review, and publish through a focused PR.
The future release contents and any adoption of #58/#59 require explicit assessment;
neither follow-up is part of the current 0.2.0 pin.

Provider downloads remain paused. No automatic release monitoring is requested.

<a id="next-slice-offline-pack-acquisition"></a>

### Paused: offline pack acquisition

**Status:** Provider acquisition paused. Programmatic local preparation and
read-only loading implemented.
Delivery requires the platform, process and review gates in [Verification](Verification.md). [Offline packs](Decisions/OfflineTilePacks.md)
owns the format, limits and lifetime contracts. [Usage](Usage.md#offline-tile-packs)
and [Examples](Examples.md#maps) contain the public API and runnable commands.

`MapTilePackPlan`, `MapTilePack.create/open` and `MapTileLoader(pack:)` implement
the local path with supplied raw bytes and no network fallback. Pack memory is
bounded; the durable file is retained independently of online cache freshness.
The example creates a pack from retained world fixtures and reopens it explicitly.

Programmatic provider downloads remain follow-up scope. Prove a permitted source,
bounded planning and progress/cancellation before adding acquisition. Published
archives such as OpenFreeMap's PMTiles remain candidates, not supported formats.
Resumable preparation and combined pack/network fallback remain separate decisions.

### Boundaries and open choices

- Keep `MapView` free of network and disk effects. Add explicit, opt-in services
  beside acquisition; applications choose when to call them, where to store data,
  which providers to use and how to present results. SwiftTUI retains native state,
  focus, input and rendering ownership.
- Reuse one raw-tile acquisition/decoding path for online responses, persistent
  cache entries and packaged copies. A pack can supply bundled tiles through that
  path. Source selection remains explicit: no automatic switch to unrelated bundled
  geography. Cache freshness and intentional offline-pack retention are distinct
  policies; an evictable cache is not a completeness guarantee for a pack.
- Scope persisted identity to the source and tile scheme/address, retain provenance
  and attribution, and check imported bytes and metadata before use. A provider's
  revision string alone does not establish immutable bytes or an atomic snapshot.
  Choose pack format, schema/versioning and migration behavior during storage design;
  PMTiles/MBTiles support is not decided by approving downloadable packs.
- Photon is the first explicit geocoding adapter; OSRM is the first routing
  adapter. Applications supply their service endpoints and credits. No public
  service is enabled by default; permission, quotas and privacy depend on the
  selected operator. Neither adapter adds a dependency.
  Keep tile, geocoding and routing capabilities independently replaceable; changing
  a provider must not redefine visual detail. Provider credentials, when needed,
  are explicitly supplied by the application; no credential store is implied.
- Tile-pack acquisition needs a source that permits the planned downloads and
  explicit request/byte/concurrency limits. Approval of packs does not authorize
  bulk downloading from the current interactive endpoint. Offline tile packs do
  not imply an offline routing graph or offline geocoding database.
- Prove each service with deterministic fixtures and real adapter boundary tests,
  then macOS/Linux checks and a bounded live-provider probe where applicable.
  Extend `chio-maps` and its showcase for each visible slice. Service integration
  is in scope; implementing a routing engine, live navigation or a geocoder index
  is not implied by this roadmap.

## Remaining scope audit

The Braille map comparison is resolved: the existing fill toggle supplies outline
presentation, route clearance and dot markers are integrated, and the texture
experiment is removed. [Geographic maps](Decisions/GeographicMaps.md) owns the
resulting presentation contract. Pitwall integration remains separate.

The 2026-10-09 global-guidance audit found two tile-admission defects (path-budget
classification and wrong-typed names), plus incomplete exhaustive switches. The
focused corrections preserve native state ownership and valid public inputs.
Meaningful optional selections/loading states and raw/projected/source models
retain their distinct contracts; no broad consolidation was justified.

The follow-up applies exhaustive owned-enum policies, concrete constructors,
internal Boolean names and dedicated conformances across production and examples,
with affected tests updated alongside their owners. Public labels, persisted keys,
native state identity and rendering remain compatibility constraints.

The user approved clearing the remaining constructor debt after 0.2.0 publication.
[PR #20](https://github.com/echoz/Chio/pull/20) carries 395 spelling-only test
constructor changes for the next patch. Its baseline retains only the documented
private geometry work-budget exception. The
[pinned local lint gate](Verification.md#shared-engineering-rules) rejects new
findings and stale entries. Intentional single-case filters, extensible
upstream/raw-input switches, native wrappers and private nested conformances
retain their documented roles.

The map expansion above remains approved. Provider archive acquisition remains
paused at the user's request; list row spacing is included in the 0.2.0 scope.
Real application use of the public map remains useful validation. Other component
additions remain possible directions, not delivery promises.

Prioritize demonstrated regressions in shipped behavior: focus, selection,
editing, narrow layout, presentation, responsiveness and supported-platform
execution. Resolve defects at their owning layer. Changing the SwiftTUI pin or
shipping a fork requires a reproducible dependency decision and native/Chio
integration evidence; an ignored local patch is not a distribution strategy.

Public additions require a concrete consumer need and reusable UX value:

- Promote the diff prototype only after resolving source wrapping, large-input
  behavior and split-width policy with real usage evidence.
- Extract a general list/detail layout only if another consumer establishes a
  shared contract.
- Completion/history, async choices, wizards, broader file selection, tree
  adapters, status queues and more themes remain possible gaps, not tasks.
- Keep monitoring, clocks, workflow engines, annotation content, general application
  persistence and repository operations with applications. Map storage and service
  adapters follow the explicit boundaries in the approved expansion above.

Prove an accepted addition in a small runnable example, document actual public
APIs, retain relevant model/raster/hosted regressions, and run a release terminal
workflow. Visible changes also follow the [showcase workflow](Verification.md#demo-site).

## Moved references

Earlier deep links remain here; follow the owning document for current details.

- <a id="current-release"></a><a id="component-coverage"></a>[0.2.0 scope and delivered coverage](Releases/0.2.0.md#component-coverage)
- <a id="running-checks"></a><a id="demo-site"></a><a id="linux-and-ci"></a>[Current verification and showcase requirements](Verification.md)
- <a id="release-verification"></a><a id="platform-verification"></a><a id="showcase-verification"></a><a id="responsiveness-baseline"></a><a id="verified-on-macos"></a>[0.2.0 verification evidence](Releases/0.2.0.md#release-verification)
- <a id="macos-toolchain-findings"></a><a id="static-linux-blocker"></a>[Dependencies, toolchains and static Linux](Decisions/Dependencies.md)
- <a id="remaining-boundaries"></a>[Native integration boundaries](Decisions/NativeIntegration.md)
- <a id="btop-inspired-ui-inventory"></a>[Instrumentation decision and btop inventory](Decisions/Instrumentation.md#btop-inspired-ui-inventory)
- <a id="gh-dash-and-hunk-ui-inventory"></a>[Review composition and reference inventory](Decisions/ReviewInbox.md#gh-dash-and-hunk-ui-inventory)
- <a id="proposed-connected-table-grid-correction"></a>[Unapplied table-grid proposal](Decisions/TableRendering.md)
- <a id="proposed-ansi-256-conversion-correction"></a>[Shelved color-conversion investigation](Decisions/TerminalColors.md)
- <a id="markdown-syntax-highlighting"></a>[Markdown highlighting decision](Decisions/Markdown.md#markdown-syntax-highlighting)
- <a id="1-prove-the-terminal-rendering"></a><a id="2-build-the-reusable-offline-component"></a><a id="3-verify-and-publish-the-first-slice"></a><a id="later-proposal-vector-tile-loading"></a><a id="evidence-and-dependency-decisions"></a>[Detailed map proposal and delivery gates](Decisions/GeographicMaps.md)
