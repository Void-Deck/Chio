<a id="chio-plan-and-verification"></a>

# Chio plan

This document tracks active work, next steps and open questions. Current contracts
live in [Design](Design.md) and its decision index; implementation and showcase
checks live in [Verification](Verification.md). Completed release scope and results
live in [0.1.0](Releases/0.1.0.md).

## Latest slice: online maps

**Status:** Accepted implementation with explicit offline and online world/street modes.
Provider comparisons remain shelved.

The explicit loader and opt-in online example are implemented. Current contracts
live in [online tile acquisition](Decisions/OnlineMaps.md), with rendering owned by
[geographic maps](Decisions/GeographicMaps.md). Offline launches remain the default.

The source choice is explicit: bundled data or online tiles. Online world views
use the same pipeline as regions and streets, starting at source zoom 1; there is
no automatic bundled-world fallback. Initial loading has no geographic source;
subsequent loads retain the last online snapshot. Native focus, complete coverage
and existing geometry/rendering budgets remain in force. Bundled copies of online
tiles can later supply the same tile pipeline;
disk caches and tile archives are not part of this correction.

Required verification for this slice:

- Verify checked values, acquisition lifecycle and exact marker fixtures, plus
  required macOS/Linux CI. CI uses deterministic local data.
- Run a separate bounded live-provider probe and adjacent-tile inspection.
  These establish integration, not provider availability or universal coverage.
- Capture the verified release recording, theme previews and showcase checks;
  deploy and inspect the published result before declaring the slice complete.

Disk caches, tile packs and routing/geocoding were excluded from that delivered
slice and are now approved follow-up scope below. Arbitrary schemas and provider
parity remain outside it. Existing polygon cut-edge limitations remain explicit.
Keep revision-specific results in release records rather than expanding this
active plan with completed implementation history.

<a id="current-slice-responsive-instrumentation"></a>
<a id="current-slice-unified-styles-and-appearance-comparison"></a>

## Completed implementation: unified styles and appearance comparison

**Status:** Public API consolidation implemented and verified in
[PR #10](https://github.com/echoz/Chio/pull/10). It is not yet in a tagged release.
The Pages workflow publishes the showcase after merge to `main`.

Responsive instrumentation and target dials merged in
[PR #8](https://github.com/echoz/Chio/pull/8) and
[PR #9](https://github.com/echoz/Chio/pull/9); they are not yet in a tagged release.

Themes and example recipes now use immutable `ChioStyle` values applied
with inherited `View.style(_:)`, one environment key and compatible
`ChioTheme`/`.chioTheme(...)` forwarding. Static default/light/btop/opencode values
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

**Deferred list spacing:** all new per-row density controls remain excluded from
this slice's public API. SwiftTUI 0.17.0 includes the merged per-axis reveal
correction in [PR #46](https://github.com/SwiftTUI/swift-tui/pull/46), now pinned
in this dependency-upgrade candidate. The measured-height navigation and builder
placement correction in [PR #47](https://github.com/SwiftTUI/swift-tui/pull/47)
merged after 0.17.0 and remains excluded from this pin. Its upstream merge does
not establish Chio adoption or a release. [Native integration](Decisions/NativeIntegration.md#tall-list-rows)
owns the remaining findings and conditions for revisiting row density.

Provider archive acquisition remains on hold at the user's request. No archive
reader or downloader has been adopted; existing local pack APIs remain available.

## Native runtime follow-up

**Status:** Personal-client rollout of released SwiftTUI 0.17.0 is approved with
the known disclosure and compact-layout regressions. Publish the compatible Chio
revision and coordinate downstream upgrades through their owning tasks,
retaining failing regression coverage and requiring client-specific
verification. [Dependencies](Decisions/Dependencies.md#0170-adoption-candidate)
owns the accepted limits and qualification evidence.

Local native fixes restore both layouts and pass full native and consumer gates
on macOS and Linux arm64. Upstream PRs #49 and #50 remain open; their current heads
pass all hosted checks. Adopt their corrections separately once published and
verified. The measured-height correction in #47 has merged but is absent from
0.17.0; it is not part of this rollout.

The merged runtime correction in
[SwiftTUI PR #48](https://github.com/SwiftTUI/swift-tui/pull/48) supersedes
[PR #45](https://github.com/SwiftTUI/swift-tui/pull/45) and ships in 0.17.0.
This dependency-upgrade candidate pins the released revision
`ee572e38487284092f367ef5b095460a04374ba3`.
[Native integration](Decisions/NativeIntegration.md#cooperative-shutdown-follow-up)
owns its constraints and remaining startup/cancellation and performance follow-ups.
Run the [consumer gates](Verification.md), reporting known failures rather than
weakening them. Publishing a compatibility revision is distinct from a versioned
Chio release and from completed adoption by every consumer.

SwiftRules 0.1.4 adoption is deferred: its source-only gate exposes 75 conformance
placement/order diagnostics across 52 production files. The operational pin remains
0.1.3 with no baseline expansion. Chio's next conformance-maintenance owner must
classify and resolve those findings and verify/review the upgrade as described in
[Verification](Verification.md#deferred-014-adoption).

## Approved map expansion

**Status:** Scope approved on 2026-10-09. Persistent caching is implemented;
programmatic local packs are implemented.
Forward and reverse geocoding candidates are under verification; routing remains
planned and provider downloads remain paused. The following order keeps
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

### Current slice: place search

**Status:** Implemented in [PR #11](https://github.com/echoz/Chio/pull/11);
integration verification on SwiftTUI 0.17.0 is in progress. Not merged or released. The
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
is separate. Delivery still requires review/merge and published Pages verification.

Reverse lookup is the next approved slice below; routing remains later scope
and provider downloads remain paused. This candidate has not been merged, deployed or released.

### Current slice: reverse lookup

**Status:** Separate capability and Photon client approved on 2026-10-13;
implemented and locally verified on top of place-search PR #11.
Not merged, deployed or released.

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
evidence is reused; no fresh mobile browser run is claimed. Delivery still requires
current hosted checks, review/merge and published Pages verification. No tile
acquisition or routing is added.

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
- Photon is the first explicit geocoding adapter. Choose the first routing provider
  after evaluating its actual contracts, terms, attribution, rate limits and
  static-Linux dependency impact.
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

Older untouched test fixtures can adopt constructor spelling when their behavior
is next changed; the [pinned local lint gate](Verification.md#shared-engineering-rules)
tracks their reviewed baseline and rejects new findings. They do not justify a
separate rewrite. Intentional single-case
filters, extensible upstream/raw-input switches, native wrappers and private
nested conformances retain their documented roles.

The map expansion above remains approved. Provider archive acquisition remains
paused at the user's request; place search is the current implementation slice.
Real application use of the public map
remains useful validation. Other component additions and a
new stable release remain possible directions, not delivery promises.

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

- <a id="current-release"></a><a id="component-coverage"></a>[0.1.0 release and delivered coverage](Releases/0.1.0.md#component-coverage)
- <a id="running-checks"></a><a id="demo-site"></a><a id="linux-and-ci"></a>[Current verification and showcase requirements](Verification.md)
- <a id="release-verification"></a><a id="platform-verification"></a><a id="showcase-verification"></a><a id="responsiveness-baseline"></a><a id="verified-on-macos"></a>[0.1.0 verification evidence](Releases/0.1.0.md#release-verification)
- <a id="macos-toolchain-findings"></a><a id="static-linux-blocker"></a>[Dependencies, toolchains and static Linux](Decisions/Dependencies.md)
- <a id="remaining-boundaries"></a>[Native integration boundaries](Decisions/NativeIntegration.md)
- <a id="btop-inspired-ui-inventory"></a>[Instrumentation decision and btop inventory](Decisions/Instrumentation.md#btop-inspired-ui-inventory)
- <a id="gh-dash-and-hunk-ui-inventory"></a>[Review composition and reference inventory](Decisions/ReviewInbox.md#gh-dash-and-hunk-ui-inventory)
- <a id="proposed-connected-table-grid-correction"></a>[Unapplied table-grid proposal](Decisions/TableRendering.md)
- <a id="proposed-ansi-256-conversion-correction"></a>[Shelved color-conversion investigation](Decisions/TerminalColors.md)
- <a id="markdown-syntax-highlighting"></a>[Markdown highlighting decision](Decisions/Markdown.md#markdown-syntax-highlighting)
- <a id="1-prove-the-terminal-rendering"></a><a id="2-build-the-reusable-offline-component"></a><a id="3-verify-and-publish-the-first-slice"></a><a id="later-proposal-vector-tile-loading"></a><a id="evidence-and-dependency-decisions"></a>[Detailed map proposal and delivery gates](Decisions/GeographicMaps.md)
