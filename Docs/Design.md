# Chio design

Chio is an opinionated, declarative presentation and interaction layer over
SwiftTUI: “Beautiful terminal interfaces for Swift.” This document owns current
cross-cutting architecture and indexes the detailed decisions.

[Plan](Plan.md) owns active work and open questions; [Verification](Verification.md)
owns current checks; [Usage](Usage.md) and [Examples](Examples.md) own public recipes
and launch workflows. Release records preserve [0.2.2](Releases/0.2.2.md) dependency
qualification and [0.2.0](Releases/0.2.0.md) scope
and evidence, with [0.1.0](Releases/0.1.0.md) retained as the earlier baseline.

## Ownership

SwiftTUI owns rendering, terminal lifecycle, layout, state, input, focus,
scrolling, scheduling and native presentation. Chio supplies immutable styles,
native control styles and composed views. One SwiftPM package exports the `Chio`
library and the `chio-dashboard`, `chio-maps` and `chio-matrix` examples; applications compose
SwiftTUI directly.
Experimental proofs stay under `Spikes/`, with separate executable/test targets;
their types are internal and do not expand the public Chio API.

A public addition must provide reusable presentation or interaction: readability,
focus/selection feedback, filtering, editing or navigation. Renaming a primitive
or making an example model immutable does not justify a library component.
Applications own clocks, monitoring, sorting policy, validation rules, review
state, persistence and external operations. Extract shared UI behavior only when
composition demonstrates a concrete missing contract. Showcase applications
validate the framework; their domain models do not define its product scope.
Coverage inventories describe gaps, without committing to catalog parity.

The [approved map expansion](Plan.md#approved-map-expansion) adds disk storage
and programmatic tile packs, geocoding and routing adapters at explicit
effect boundaries beside the view. Applications retain invocation, storage and
provider policy, credentials and workflow ownership. These capabilities are
delivered one slice at a time. Submitted place search has an explicit Photon
adapter; reverse lookup supplies a separate capability and Photon client
using the same attributed place values. [Routing](Decisions/Routing.md) provides
an explicit OSRM adapter beside the unchanged overlay view. Provider archive
downloads remain paused. The current
map renderer and acquisition contracts remain intact. Opt-in persistence is
defined in [online acquisition](Decisions/OnlineMaps.md#persistent-raw-tile-cache).
Its private `ChioFileSystem` target bridges native locking and
directory enumeration without adding another public product.

Offline packs are programmatically prepared or supplied immutable tile
data, serving the shared loader and bounded memory cache through a read-only
backing store. They retain their contents independently of the writable online
cache's expiry and eviction. Applications own distribution and any management UI;
[Offline packs](Decisions/OfflineTilePacks.md) owns storage and lifetime contracts;
[Plan](Plan.md#next-slice-offline-pack-acquisition) owns the delivery sequence.

## Styles and view contracts

The approved unified `ChioStyle` value holds colors, spacing, treatments and
surfaces. `View.style(_:)` installs native control styles and an inherited subtree
value through one `EnvironmentValues.chioStyle` key. The nearest complete style
overrides its ancestor. The current API uses `ChioStyle`, `.style(...)` and
`EnvironmentValues.chioStyle`; the former theme aliases and legacy function-signature
overloads are removed. Native component style modifiers remain specific overrides,
with descriptive `theme:` initializer labels taking `ChioStyle` values.
[Styles](Decisions/Themes.md) owns presets, surface inheritance, bounded input and
list-row padding, and migration; [Plan](Plan.md) records delivery and verification.

`Spacing.listRowVerticalInset` is a checked `0...32` cell distance, defaulting to
zero and set to one by `.opencode`. `SearchableList` and `SearchableChecklist`
apply it around complete authored rows; `FilePicker` inherits that presentation
through its searchable list. Native `List` content applies the token with ordinary
row padding because its public style hook cannot transform each row. SwiftTUI
retains focus, measurement, selection and scrolling.
[Plan](Plan.md#current-slice-list-row-spacing) and the [release record](Releases/0.2.0.md)
own delivery status and qualification evidence.
Applications retain layout, breakpoints, column widths and navigation.

Prefer a native style when an existing view already expresses the required
content and behavior. Use composition for grouping and application priorities.
Extend an existing view, or introduce a focused view, when reusable functionality
requires meaningful inputs, content roles or interaction that existing views do
not express. Configuration count alone does not establish that boundary.

Styles are pure presentation transformations: supplied configuration, immutable
style options, theme/environment values and layout inputs determine a view
description. Repeated evaluation with equivalent inputs must describe equivalent
presentation and leave the inputs and external state unchanged. Reading the
framework-supplied environment or layout proposal counts as consuming an input;
it does not authorize reading arbitrary global state.

A style may arrange authored content and respond to supplied focus, selection,
enabled state or progress. It must not own changing state, perform I/O, fetch
data, read clocks or randomness, or introduce tasks, timers or lifecycle effects
in the returned presentation. Keep effect and resource ownership in explicit
application or component boundaries. Rendering and native interaction remain
SwiftTUI's responsibility.

Preserve authored slots and native interaction routes. Passing through content
or wiring a supplied action preserves its existing owner; invoking that action
during style evaluation is a side effect. Authored content may have its own state
and effects, but the style must not add or take ownership of them. Changing a
style must preserve the supplied facts, action meanings and accessibility
contract even when their visual arrangement changes.

Do not pass samples, service clients or application models into a style to
compensate for missing view inputs. A target interval belongs to a gauge's input
contract; its visual treatment belongs to presentation. Data acquisition belongs
to an explicit loader/provider. Custom views may offer style choices when useful;
neither a new view nor many options require a new style protocol.

These are design and semantic review requirements, not proof that every existing
style has been audited. Verify repeatable presentation and unchanged inputs at
the relevant boundary; review effect ownership as well as direct function calls
so deferred effects in returned views do not evade the purity contract.

## Value contracts

Owned domain values and view configuration have `let` stored properties and pure
computed observations. Transformations return replacements and leave inputs
unchanged; local scratch mutation is permitted. Explicit mutable boundaries are
SwiftTUI state/binding/focus/namespace/environment wrappers, ArgumentParser command
options, filesystem resource owners, the serial map preparation actor, the online
tile loader actor and its locked URLSession delegate resource owner, the example
place-search and route-request task owners, and live
test-session recorders with frames, continuations and deadlines.

Prefer synthesized `Hashable`, `Codable` and `Sendable` where their contracts fit.
Enforce restricted-value invariants through construction, replacement and decoding;
malformed decoding must reject through the same validation as construction.
Validation flags cannot replace invariants or contextual runtime checks. Draft
bindings read current retained storage before replacing a field, preserving other
fields even when multiple input events arrive before a frame.

Field descriptions and shortcut details are nonoptional strings: empty means no
supporting row. Shortcut decoding accepts historical missing/null detail as empty;
encoding always includes a string, and missing/empty details compare equally.
Errors retain meaningful optional presence: a present empty error still suppresses
help. Selection and native state ownership retain meaningful absence. Omitted
replacement arguments preserve values; supplied empty values clear them. Markdown
normalizes missing language/destination text at parsing. Search callbacks have
neutral defaults; modifier copies retain callbacks and native state identity.

Native `StrokeStyle` is only `Equatable` and `Sendable`, including inaccessible
state. `ChioStyle` and `Treatments` retain those conformances; `Colors`,
`SyntaxColors`, `MapColors`, `GaugeColors` and `Spacing` also support hashing and coding. Do not
clone strokes or add lossy coding to gain conformance. Parsed Markdown and report/presentation
snapshots are immutable, hashable and sendable without a persistence schema:
native table alignment is not Codable, and reconstructing a report from its agent
would lose the captured document. Process-relative example timekeeping likewise
has no persistence representation. New checked instrumentation bands, references,
history samples/segments and display windows are hashable and sendable without a
Codable contract; they do not define application persistence.

Incomplete agent drafts are valid editable values; checked creation enforces form
rules. Running progress is a checked finite fraction in `0..<1`; completion is a
separate phase. Simulation takes its step explicitly and returns replacement agents.

## Investigation outcome

| Reference | Native foundation | Chio contribution |
| --- | --- | --- |
| Lip Gloss / Charmtone | Layout, borders, colors, environment | Semantic palette and coherent defaults |
| Bubbles | Lists, tables, editing, scrolling, progress, palettes | Search composition, empty states and contextual help |
| Huh | Bindings, controls, submission, focus | Field presentation and validation visibility |
| Glamour | Rich text and links | Parsed Markdown composed into themed native views |
| btop | Canvas, groups, progress and authored layout | Compact styles and passive history presentation |
| gh-dash / Hunk | Lists, previews and ID-based scroll reveal | Example inbox composition and bounded diff proof |

Charm supplies visual references, not a Go API port or ANSI-string/layout engine.
Huh's Charm palette and Bubbles' hierarchy/help inform the default appearance.
btop informs compact instrumentation; gh-dash and Hunk inform review composition.
GitHub/VCS operations, authentication, file watching and agent protocols remain
application work. These examples do not establish product parity.

## Source ownership

| Path | Responsibility |
| --- | --- |
| `Sources/Chio/<Component>/Domain` | Immutable values and pure rules belonging to that component or shared foundation |
| `Sources/Chio/<Component>/Protocol` | Component substitution contracts, such as map source adapters |
| `Sources/Chio/<Component>/Execution` | Explicit resource owners and effects, including file loading and map acquisition/preparation |
| `Sources/Chio/<Component>/Serialization` | Component codecs and source normalization |
| `Sources/Chio/<Component>/Presentation` | Views, native control styles and environment integration |
| `Examples/AgentDashboard` | Local models, workflows/views and thin entry point |
| `Examples/Maps`, `Tests/ChioMapTests` | Maps consuming the public API, offline fixtures, opt-in online acquisition and integration checks |
| `Tests/ChioTests/<Component>/<Responsibility>` | Focused library suites matching their source owner |
| `Tests/ChioTests/Integration`, `Tests/ChioDashboardTests` | Cross-component rendering/terminal checks and example domain/hosted interactions |
| `Examples/DotMatrix`, `Tests/ChioDotMatrixTests` | RGB/intensity display composition, fixture content, application-owned playback and native scrolling |
| `Docs/Site`, `Docs/Media`, `Scripts/docs` | Static showcase, shared terminal assets and assembly without Swift build |

Chio deliberately uses component-first organization inside its single library
target: `Sources/Chio/<Component>/<Responsibility>/<Type>.swift`. This project
override replaces the default responsibility-first order; it changes neither
Swift modules nor public names. Maps and Markdown keep their complete implementations
together. Style owns shared palette/environment integration; Search owns matching
used by several controls. KeyboardHelp owns expanded help and shared shortcut
values; KeyHint and KeyHints each own their directly usable view. DurationText,
HistoryChart, InstrumentReadout, MeasurementGauge and Sparkline have distinct
component roots. HistoryChart owns its checked history values; MeasurementGauge
owns its nested annotations. Instrumentation retains shared native control styles.
Forms, Composition and Feedback retain related styles and presentation. Only
populated responsibility groups exist. Examples keep their application structure.

The [library guide](../Sources/Chio/README.md) links all seventeen public views.
Each view has its own source-root README and a separate nested entry under Chio
in [.documentation-rules.json](../.documentation-rules.json). Forms owns FormField;
Composition owns StatusBar. Each is the sole public view at that source root, with
its related styles. The library, all three example applications and static showcase
also have source-root guides. Private implementation targets, native SwiftTUI
controls, supporting styles and internal spikes do not become public components.
These documentation boundaries add no SwiftPM products or modules.

Source links follow this organization. Inbox review payloads and recorded demos
retain their fixed synthetic file paths; those are displayed snapshot content,
not links or runtime lookups into this checkout.

Independently useful production types
have matching files and dedicated conformance extensions. Private nested helpers
retain inline conformances when extraction would widen access; raw enums keep
language-required placement. Shared frame recorders live in target `TestSupport`;
scenario fixtures/expectations remain beside suites. Global engineering/layout
rules remain in the working agreements rather than being duplicated here.

The dashboard command resolves its parser flags into one internal `DashboardExample`.
Validation, theme defaults, snapshot rendering and interactive launch share that
selection; exhaustive switches retain each native view/application pairing.
`Execution/ChioDashboardCommand+Execution.swift` owns rendering and live launch,
including the file example's current-directory lookup. Existing CLI spellings,
defaults, diagnostic order and unsupported combinations remain stable.

## Decision index

Read the relevant topic before changing its behavior. Accepted records remain
current authority after delivery; proposed and shelved records do not describe
shipped APIs. Each record keeps its scope, contracts, tradeoffs and useful evidence.
Update the owning record when a decision changes, marking superseded decisions
and linking their replacement. Keep execution status in Plan and release results
in Releases; avoid duplicating full contracts across documents.

| Topic | Status and responsibility |
| --- | --- |
| [Dot matrix display](Decisions/DotMatrix.md) | Accepted public RGB/intensity frames, inherited dot style and passive presentation |
| <a id="theme"></a>[Styles and native control styling](Decisions/Themes.md) | Accepted |
| <a id="compact-instrumentation"></a><a id="duration-presentation-and-example-owned-timekeeping"></a>[Compact instrumentation and duration display](Decisions/Instrumentation.md) | Accepted instrumentation and high-contrast target dials; tile deferred |
| <a id="searchable-selection"></a><a id="searchable-multiple-choice"></a>[Searchable selection and membership](Decisions/SearchableSelection.md) | Accepted |
| <a id="composition-and-layout"></a>[Responsive composition and status](Decisions/Composition.md) | Accepted |
| <a id="contextual-keyboard-help"></a>[Contextual keyboard help](Decisions/KeyboardHelp.md) | Accepted |
| <a id="tabs"></a>[Native tabs](Decisions/Tabs.md) | Accepted |
| <a id="pagination"></a>[Finite pagination](Decisions/Pagination.md) | Accepted |
| <a id="scrolling"></a>[Native scrolling](Decisions/Scrolling.md) | Accepted |
| <a id="expandable-groups-and-trees"></a>[Expandable groups and trees](Decisions/DisclosureGroups.md) | Accepted |
| <a id="command-palette"></a>[Native command palette](Decisions/CommandPalette.md) | Accepted |
| <a id="forms-and-agent-creation"></a><a id="password-and-multiline-input"></a>[Forms and native editing](Decisions/Forms.md) | Accepted |
| <a id="confirmation-and-transient-feedback"></a>[Confirmation and transient feedback](Decisions/Feedback.md) | Accepted |
| <a id="file-selection"></a>[File selection](Decisions/FileSelection.md) | Accepted |
| <a id="dense-review-inbox"></a>[Dense review inbox composition](Decisions/ReviewInbox.md) | Accepted example scope |
| <a id="read-only-diff-prototype"></a>[Read-only diff prototype](Decisions/DiffReader.md) | Accepted example scope |
| <a id="markdown-and-agent-reports"></a>[Markdown, code and interactive links](Decisions/Markdown.md) | Accepted |
| <a id="references-and-boundaries"></a>[Dependencies and distribution](Decisions/Dependencies.md) | Current pins, toolchain findings and static Linux blocker |
| [Online tile acquisition](Decisions/OnlineMaps.md) | Accepted explicit loader and opt-in online example |
| [Programmatic offline packs](Decisions/OfflineTilePacks.md) | Implemented immutable raw-tile backing |
| [Place search](Decisions/PlaceSearch.md) | Accepted explicit Photon adapter, immutable matches and example-owned submission |
| [Routing](Decisions/Routing.md) | Explicit OSRM adapter, checked attributed routes and example-owned requests |
| [Native integration](Decisions/NativeIntegration.md) | Current limitations and ownership |
| [Terminal colors](Decisions/TerminalColors.md) | Accepted native detection; conversion experiment shelved |
| [Table rendering](Decisions/TableRendering.md) | Proposed correction; patches unapplied |
| <a id="geographic-maps-proposed"></a>[Geographic maps](Decisions/GeographicMaps.md) | Accepted component; provider comparisons shelved |

Topic anchors above retain earlier deep links. Historical implementation details
and original investigations remain in [the v0.1.0 documents](https://github.com/echoz/Chio/tree/v0.1.0/Docs)
and Git history.
