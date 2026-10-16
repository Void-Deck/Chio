# Using Chio

[Back to Chio](../README.md) · [Runnable examples](Examples.md)

Chio supplies immutable styles and reusable interactions over SwiftTUI's
native controls. Apply `.style(...)` to your view hierarchy; SwiftTUI owns
rendering, layout, state, input, focus, and scrolling.

The package exports one `Chio` library. Applications also depend on SwiftTUI
for the native views and runtime. See [Package.swift](../Package.swift) for the
current dependency pins and [the design](Design.md) for interaction contracts.
The [0.2.0 release record](Releases/0.2.0.md) records dependency requirements,
migration and release evidence.
SwiftPM version requirements such as `from: "0.2.0"` cannot consume this revision-pinned graph.
See the [migration notes](Releases/0.2.0.md#migration-from-010) when upgrading from 0.1.0.

## Search and keyboard hints

Applications compose SwiftTUI views and import `SwiftTUI` and `Chio`:

```swift
import SwiftTUI
import Chio

struct AgentsView: View {
    let agents: [Agent] // Your Identifiable model, with stable IDs and a name.
    @State private var selection: Agent.ID?

    var body: some View {
        VStack {
            GroupBox("Agents") {
                SearchableList(agents, selection: $selection, searchText: \.name) {
                    Text($0.name).lineLimit(1).truncationMode(.tail)
                }
            }
            StatusBar {
                KeyHints {
                    KeyHint("↑↓", "Navigate")
                    KeyHint("/", "Search")
                }
            }
        }
        .style(.default)
    }
}
```

Rows are passive views; use `.onActivate` for opening an item
and `.onResultKeyPress` for application shortcuts that must not consume search
text. Native row focus chrome currently remains an upstream styling boundary;
see [the design](Design.md).

This recipe uses one-line rows for a compact presentation. Applications own
row content and available width; SwiftTUI owns measured-row navigation and focus.
See [native list contracts and evidence](Decisions/NativeIntegration.md#tall-list-rows)
for padded, mixed-height and wrapped rows.

## Expanded keyboard help

Share immutable descriptions between a compact footer and grouped help:

```swift
let navigation = [
    ShortcutHint("↑↓", "Navigate", detail: "Move through the visible results."),
    ShortcutHint("/", "Search", detail: "Filter results by name."),
]

// In the application's view body; showsHelp is application-owned @State.
content
    .fullScreenCover(isPresented: $showsHelp) {
        VStack {
            Text("Keyboard shortcuts")
            ScrollView {
                KeyboardHelp([ShortcutGroup("Navigation", shortcuts: navigation)])
            }
            Button("Close") { showsHelp = false }
        }
    }
    .style(.default)

// The same descriptions, without expanded details:
StatusBar { KeyHints(navigation) }
```

`detail` defaults to `""`; empty details add no expanded text row. The decoder
accepts historical missing or null details as empty, and encoding always emits
the detail string. Descriptions do not register key bindings. Derive their visibility
from your application's current context; keep actions in native handlers. `KeyboardHelp`
supplies content while native containers supply scrolling, dismissal and focus
restoration. Apply `.style` outside the presentation declaration and keep the
presenting controls mounted while help is open. Scope modal key handlers to the
whole authored cover so they work from both its viewport and its buttons.

For editor-safe `?` handling, use `.onResultKeyPress` on a searchable list and
scoped `.onKeyPress` on action controls. Avoid an ancestor handler that consumes
ordinary text. See [HelpExampleView](../Examples/AgentDashboard/Presentation/HelpExampleView.swift)
for F1 during editing, contextual descriptions, and protection against keys
arriving before presentation acquires focus.

<a id="themes"></a>

## Styles

Choose `ChioStyle.default`, `.light`, `.btop`, or `.opencode`, then apply
`.style(...)` to any view. Descendants inherit the complete value; the nearest
style replaces it. These static values combine colors, spacing, treatments and
surfaces, and each part can be customized.

```swift
let base = ChioStyle.opencode
let style = base.replacing(
    colors: base.colors.replacing(accent: Color(hexRGB: 0x02BF87)),
    spacing: base.spacing.replacing(inputVerticalInset: 1, listRowVerticalInset: 1),
    surfaces: base.surfaces.replacing(input: .color(Color(hexRGB: 0x282522)))
)

VStack {
    primaryContent
    secondaryContent.style(.light) // A complete style for this subtree.
}
.style(style)
```

`inputVerticalInset` and `listRowVerticalInset` each default to zero and accept
`0...32` terminal cells through construction, replacement and decoding. Historical
encoded spacing with either key missing decodes that distance as zero. The original
four spacing fields keep their existing nonnegative contract.

`SearchableList` and `SearchableChecklist` apply `listRowVerticalInset` above and
below each complete row, including checklist content and its checkbox. `FilePicker`
uses the same searchable-list presentation. Avoid adding the token again to those
row closures. Native `List` needs ordinary authored padding because its public
style API has no per-row content hook:

```swift
// In a View that declares @Environment(\.chioStyle) private var style:
List(agents, selection: $selection) { agent in
    Text(agent.name)
        .padding(.vertical, style.spacing.listRowVerticalInset)
}
```

The [release record](Releases/0.2.0.md#release-verification) owns qualification
evidence for spacing and dynamic style changes.

`surfaces.canvas` and `surfaces.input` use `.base` to inherit `colors.surface`,
or `.color(...)` for an explicit override. `.base` continues to follow later
palette replacements.

`.btop` now installs border headings on groups; `.opencode` supplies leading
panel/input edges, roomier inputs and one cell above and below each Chio searchable
row. Default, light and btop keep zero list-row inset. Application layout,
breakpoints, column widths, navigation and data remain application decisions. Native component style modifiers remain specific
overrides inside the `.style(...)` scope, and their `theme:` initializer labels
are retained and take `ChioStyle`. Migrate `ChioTheme` to `ChioStyle`, `.chioTheme(...)`
to `.style(...)`, and `@Environment(\.chioTheme)` to `@Environment(\.chioStyle)`.
The aliases and legacy initializer/replacement function-signature overloads are
removed. Rebind function references to the current signatures or use explicit
closures. See [the style decision](Decisions/Themes.md) and
[migration notes](Releases/0.2.0.md#migration-from-010).

## Compact metrics and history

Combine native groups and progress views with a passive history graph. For a
standalone measurement, supply a normalized position and keep units in an authored
label:

```swift
VStack(alignment: .leading) {
    InstrumentReadout("64") // Segmented numeric lettering by default.
    Text("CPU · 64%")
    MeasurementGauge(position: 0.64)
        .accessibilityLabel("CPU utilization: 64 percent, scale 0 to 100 percent")
}
.style(.btop)
```

`MeasurementGauge` defaults to `.bar`. The existing `.dial` option remains
available for unannotated readings: `MeasurementGauge(position: 0.64, style: .dial)`
draws only an arc and needle. Add an independent target to color its arc segment:

```swift
let target = try MeasurementGauge.TargetBand(lowerBound: 0.45, upperBound: 0.60)
VStack(alignment: .leading) {
    Text("Current 64%")
    MeasurementGauge(position: 0.64, targetBand: target, style: .dial)
    Text("Target 45–60% · Scale 0–100%")
}
.style(.btop)
```

`theme.gauge` owns arc, target and needle colors. All Braille dots in a cell share
one foreground; the needle wins overlapping paint and can hide a narrow target.
Keep numeric captions, especially for monochrome terminals. References stay
bar-only. Metrics demonstrates target dials; bars remain its default.
Supply a finite position in `0...1`, or `nil` for a missing reading. Normalize
measurements and decide how to handle out-of-range data in your application before
construction. The bar uses one row, with a one-column minimum, twenty-column
preferred width and 512-column limit. The dial plot stays 20 × 5 cells, centered
in surplus width. Four columns per row assumes cells are approximately twice as
tall as they are wide; actual fonts differ. Bars and plain dials remain accented at one. These
passive views have no sampling or input
behavior; replace the normalized accessibility summary with your scale and units.

`InstrumentReadout` accepts an already formatted string. Use `style: .plain` for
ordinary text. Segmented lettering uses three rows and supports digits, decimal
points, colons and signs, up to 32 characters. Unsupported, empty or longer strings,
and allocations too small for the complete lettering, use native text. Its
accessibility label is the original string. Keep units in surrounding labels and
supply a more descriptive accessibility label when needed.
Apply a replacement label directly to the readout before wrapping it in a theme
or container; labeling an outer container follows SwiftTUI's aggregate semantics.

A native progress view remains useful when its progress-bar semantics fit:

```swift
let theme = ChioStyle.btop
let samples: [Double?] = [0.2, 0.45, nil, 0.55, 0.64]

GroupBox("CPU") {
    VStack(alignment: .leading, spacing: 0) {
        ProgressView(value: 0.64, barWidth: 24) {
            Text("Utilization")
        } currentValueLabel: {
            Text("64%")
        }
        .progressViewStyle(ChioProgressViewStyle(theme: theme, treatment: .measurement))
        Sparkline(samples, scale: .fixed(0...1))
            .frame(width: 24, height: 4)
    }
}
.groupBoxStyle(ChioGroupBoxStyle(theme: theme, titlePlacement: .border))
.style(theme)
```

`.border` puts a display-only title in the top border. Text truncates to one row;
allocations below five columns hide title paint while keeping its subtree mounted.
Content controls retain native focus and input. The default `.content` placement
keeps the heading inside the group. Explicit style options stay independent of
the palette; pass the current theme when constructing those styles.

`.measurement` keeps a progress track accented even at 100%. The default
`.progress` treatment paints completion as success. Native `ProgressView` retains
its progress-bar accessibility role; authored labels supply metric names and units.
Applications own utilization thresholds and alert meaning.

`Sparkline` draws oldest-to-newest, equally spaced samples through SwiftTUI's
braille canvas. Supply only finite readings; use `nil` for gaps. Empty and
all-missing input draw nothing. `.automatic` scales to present values and puts
constant data at the midpoint; a single-entry series sits at the right edge.
`.fixed(...)` requires finite, strictly increasing bounds and clips outliers.
Set a frame to choose the graph's allocation. At narrow widths, each uninterrupted
run retains its first, last, minimum and maximum readings per drawing column.
Subcolumn gaps may be visually indistinguishable, but are never bridged by a line.
The graph supplies an accessible textual summary. Applications own sample
collection, retention, clocks and units.

See the [compact metrics example](Examples.md#compact-metrics) for local sample
updates, missing and empty history, theme changes and adaptive composition.

## Instruments and time-aware history

The 0.2.0 scope includes the instrumentation expansion from
[PR #8](https://github.com/echoz/Chio/pull/8) and unified `.style(...)` API from
[PR #10](https://github.com/echoz/Chio/pull/10).

Opt into native labelled-content hierarchy while retaining arbitrary content:

```swift
LabeledContent("Temperature", value: "21.4 °C")
    .labeledContentStyle(.instrument)
    .style(.btop)
```

The pure style reads the theme, puts a muted heading above accented content and
hosts each authored slot once. It supplies no formatting, sampling or missing
inference. Use native groups/stacks for paired or supporting facts and an authored
`Label` for trends. Recorded facts can remain visible when the current reading is
unavailable. An already-titled group can contain `InstrumentReadout` directly.

Checked gauge annotations are independent of the current reading:

```swift
let target = try MeasurementGauge.TargetBand(lowerBound: 0.45, upperBound: 0.60)
let references = try MeasurementGauge.ReferenceMarks([
    MeasurementGauge.ReferenceMark(id: "mean", label: "Mean 20.8 °C", position: 0.52),
    MeasurementGauge.ReferenceMark(id: "maximum", label: "Maximum 24.8 °C", position: 0.62)
])
MeasurementGauge(position: nil, referenceMarks: references,
                 targetBand: target)
```

Target bounds must be finite, in `0...1` and strictly increasing. References need
finite positions in `0...1`, nonempty complete captions and unique caller IDs;
at most two are accepted. Caller order supplies ordinals, without sorting positions
or deriving statistics. Shared reference cells show `*`; every numbered caption
remains below the plot. Annotated gauges use bars, adding one row each for a
target track and a reference track. Reference captions use the actual instrument
width and add their full wrapping height below the plot. Native fitting sees all
required tracks and captions, even under an inherited line limit. Use passive
`ViewThatFits` alternatives to choose a complete annotated bar or numeric reading
by available space. Default
two-axis fitting probes ideal width twenty. If the minimum plot width is already
met, `.vertical` fitting measures captions at the provided width. A forced
undersized frame or ancestor clip can still hide content. Compact
composition may omit a whole optional reference group. Pass
`targetBand: nil` or checked `ReferenceMarks([])` to remove annotations. The legacy
`MeasurementGauge(position:style:)` remains available.

Use checked segmented history when exact time spacing matters:

```swift
let series = try HistorySeries(segments: [
    [HistorySeries.Sample(offset: .seconds(0), value: 72),
     HistorySeries.Sample(offset: .seconds(7), value: 94),
     HistorySeries.Sample(offset: .seconds(7), value: 118),
     HistorySeries.Sample(offset: .seconds(19), value: nil),
     HistorySeries.Sample(offset: .seconds(26), value: 81)],
    [HistorySeries.Sample(offset: .seconds(61), value: 310),
     HistorySeries.Sample(offset: .seconds(83), value: 88)]
])
let window = try HistoryInterval(start: .seconds(0), end: .seconds(90))
VStack(alignment: .leading, spacing: 0) {
    Text("Response time · milliseconds")
    HistoryChart(series, window: window, scale: .fixed(0...500))
        .frame(width: 48, height: 8)
    Text("0–90 seconds · 0–500 ms")
}
```

The outer `try` covers nested constructors. Offsets are exact source `Duration`
values in `0...Duration.seconds(Int64.max)`, nondecreasing inside each nonempty
segment; equal timestamps can connect vertically. Separate segments may restart,
backtrack or overlap and are never connected. A segment boundary asserts no outage
duration. `nil` breaks both neighboring connections; zero is valid. A blank series
uses `HistorySeries(samples: [])` or `HistorySeries(segments: [])`; supplied empty
segments are rejected. Limits are 16,384 samples total and 4,096 segments.
`HistoryInterval` supplies only the window, with strictly increasing checked bounds.
There is no `missingIntervals` API. These checked values have no Codable contract.

`HistoryChart` is passive and defaults to `.automatic`, using visible clipped
geometry; fixed bounds reuse `Sparkline.Scale` and must be finite/increasing.
It clips real connections without extrapolation. A singleton stays at its timestamp,
while `Sparkline` retains equally spaced slots. Whole-plot unavailable output replaces
allocations over 512 × 64 or native drawing work over 262,144 grid samples. No
partial history is shown as complete. Applications own collection, retention,
windows, units and captions; reserve the complete plot and caption height.

`.style` installs pure `ChioSliderStyle()` and `ChioStepperStyle()` in its
scope. Use native bindings and controls:

```swift
Slider("Sample", value: $selectedIndex, in: 0...119)
Stepper("Step", value: $step, in: 1...3)
```

SwiftTUI retains keyboard/pointer behavior, focus, accessibility, the routed slider
track and increment/decrement actions. Applications own valid bounds, play/pause,
seeks and clocks. Local native style overrides remain available. No playback
framework is added. See [the instruments example](Examples.md#instruments) and
[the owning decision](Decisions/Instrumentation.md) for contracts and pending gates.

## Maps

`MapView` draws a north-up world or street map from a retained `MapSource`.
Supply application-owned camera and marker-selection bindings, plus optional
location and route overlays:

```swift
import SwiftTUI
import Chio

struct PlacesView: View {
    let source: MapSource
    let overlays: MapOverlays
    @Binding var camera: MapCamera
    @Binding var selection: String?
    let activate: (MapMarker) -> Void

    var body: some View {
        MapView(source: source, camera: $camera, selection: $selection,
                overlays: overlays, detail: .minimal)
            .mapFills(true)
            .mapLabels(true)
            .onActivate { marker in activate(marker) }
            .frame(width: 100, height: 26)
            .style(.default)
    }
}
```

Construct and retain checked geography and overlays at the application boundary:

```swift
let start = try MapCoordinate(latitude: 1.289, longitude: 103.866)
let end = try MapCoordinate(latitude: 1.292, longitude: 103.870)
let camera = try MapCamera(center: start, longitudeSpan: 0.030)
let marker = try MapMarker(id: "meeting-place", coordinate: start, title: "Meet here")
let route = try MapRoute(id: "walk", title: "Our walk",
                         path: MapPolyline(coordinates: [start, end]))
let overlays = try MapOverlays(markers: [marker], routes: [route])
```

Coordinates, cameras, source geometry, metadata and overlays are immutable.
Checked constructors and decoding reject invalid values. Marker IDs and route
IDs are separate namespaces; IDs must be unique within their own collection.
Overlays accept at most 256 markers, 64 routes and 200,000 route vertices.
Use `.empty` when no annotations are needed. An empty marker or route title omits
its supporting label. Chio paints supplied paths; applications calculate routes.

While the map has native focus, arrows pan and `+`/`-` zoom around the center.
`n`/`p` cycle through markers in authored order and center the selected location;
Return calls `onActivate` for the selected marker. The map is one focus stop;
Tab/Shift-Tab continue native traversal. Camera and selection bindings remain
authoritative. Unknown selected IDs are retained, and external selection changes
do not implicitly move the camera or activate a location. `.mapLabels(false)`
hides background, route and unselected-marker labels; selected-marker labels remain
enabled and take priority where they fit. Overlapping unselected markers may be
omitted from the drawing, while remaining keyboard-selectable.

Customize water and park fills through `theme.replacing(map:
theme.map.replacing(water: color))`. These colors are independent of syntax
highlighting. Routes use `theme.colors.accent`; selected Braille rings and their
labels use `theme.colors.warning`. Ordinary markers use `theme.colors.foreground`.
Use `.mapFills(false)` for outlines at any detail level. Routes clear nearby
linework and own the dots in each touched cell, avoiding shared-cell colour bleed.

Detail is `.silhouette`, `.minimal` (the default), `.abstract`, or `.source`.
It controls geographic classes, boundary simplification and background labels;
markers and routes remain independent. A themed native Canvas paints geometry,
with native text for labels. Preparation runs asynchronously with bounded work;
obsolete results cannot replace the current request. Overload and compact layouts
show explicit summaries instead of presenting incomplete geography as complete.

Allow at least 32 × 16 drawing cells at longitude spans of 60 degrees or more,
or 58 × 16 for closer views, plus the component’s two source-credit rows.
Smaller layouts retain camera and selection for expansion. Source coverage is a
separate fact from feature bounds: geometry may extend outside the covered area.

Applications load bytes and construct sources before presentation. For normalized
GeoJSON, use `MapDataset.decodeGeoJSON(data)` for the supported subset, then
`MapSource(dataset: dataset, metadata: metadata, coverage: coverage)`. Source
metadata requires attribution, license and source URLs, and a source revision;
`attributionURL` is optional. `MapView` displays source credits in two rows.

`NormalizedGeoJSONMapAdapter(metadata:coverage:)` adapts normalized GeoJSON bytes.
`OpenMapTilesAdapter(tile:metadata:)` adapts MVT bytes with an explicit
`MapTileCoordinate`. Both return the same checked `MapSource` representation;
neither adapter loads files, makes requests, stitches tiles or chooses provider
resolution. Applications choose when to acquire sources and retain responsibility
for provider choice and data licenses.
See the [runnable example](Examples.md#maps) and its
[fixture provenance](../Examples/Maps/Fixtures/Provenance.md).

### Online vectors

OpenFreeMap is Chio's recommended online provider and the default for
`chio-maps --online`. It supplies compatible vectors without an API key; Chio
supplies the terminal styling. Opt into networking at the application boundary.
The view itself never loads data:

```swift
let endpoint = try await OpenMapTilesSource.fetchOpenFreeMap()
let loader = MapTileLoader(source: endpoint) // Retain one loader per map consumer.
let request = MapTileRequest(camera: camera, viewport: viewport)
let snapshot = try await loader.load(request)
// Publish snapshot.source only if request still matches the current camera/allocation.
```

Get the actual drawable allocation with `.onViewportChange { viewport = $0 }`.
Nil means the compact fallback is visible. Use SwiftTUI's `.task(id:)` to load
when the camera/allocation changes, retain the previous source during loading,
and check cancellation before publication. Start with `MapView(source: nil, ...)`
when nothing has loaded; its controls and allocation reporting remain available. See the complete
[tile example composition](../Examples/Maps/Presentation/TiledMapContent.swift).
Changing theme or `MapDetail` does not change a tile request.

For another OpenMapTiles-compatible service, construct
`OpenMapTilesSource(template:zoomRange:metadata:)` with a path such as
`https://your-host.example/tiles/{z}/{x}/{y}.pbf`. Placeholders must occur exactly
once in the path; source metadata and zoom limits are required. URL construction
is pure. Discovery and `load` are explicit async operations.

The loader acquires the whole viewport with at most two concurrent requests and
16 tiles. It retains a bounded memory cache, cancels superseded work, and fails
instead of returning partial coverage. It validates selected source parts and
retains complete parts whose bounds could intersect the viewport; coverage describes
that retained region, even when whole raw tiles are cached. Geometry-budget failures may retry two
lower source zooms; compare `requestedZoom` and `attainedZoom` to disclose that
fallback. Empty successful tiles remain empty; HTTP failures remain errors.
Source zoom 1 is the online minimum; four tiles cover the world through the same
loader used for regions and streets. Online mode never substitutes bundled geography.
Buffered/clipped polygon seams are still possible. See
[online acquisition contracts](Decisions/OnlineMaps.md) for limits and lifecycle.

To reuse fresh raw tiles across launches, opt into an application-selected cache:

```swift
let cache = try MapTileCache.open(directory: cacheDirectory, source: endpoint)
let loader = MapTileLoader(cache: cache)
// Retain both while the map consumer is active; cancel and await its loads first.
// When the consumer has stopped:
await cache.close()
```

The directory belongs to that exact source and permits one owner at a time.
Opening a different source in it fails without wiping its contents. Defaults
bound encoded tiles to 128 MiB and 256 entries; `maximumBytes` and
`maximumEntries` can select smaller limits. HTTP freshness still applies, up to
thirty minutes. Expired/corrupt entries are misses, ordinary storage failures
propagate, and closing the cache prevents later loads through attached loaders.
This is an evictable cache, not an offline tile pack. See the
[persistence contract](Decisions/OnlineMaps.md#persistent-raw-tile-cache) for file
bounds, ownership, clock assumptions and process-interruption recovery.

### Place search

`MapGeocodingProvider` is an explicit effect boundary beside `MapView`. The first
adapter accepts an application-selected Photon **API endpoint**, including `/api`:

```swift
let geocoder = try PhotonGeocoder(
    endpoint: URL(string: "https://photon.komoot.io/api")!,
    userAgent: "MyMapApp/1.0 (contact@example.com)"
)
let query = try MapPlaceQuery(text: "Marina Bay", limit: 8)
let matches = try await geocoder.search(query)
```

The public Photon demo allows reasonable use without an availability guarantee;
read its [policy](https://github.com/komoot/photon#demo-server) before selecting it.
Use a self-hosted or contracted endpoint for workloads needing their own capacity
or privacy terms. Chio has no default host, key store or automatic requests.

`MapPlaceMatches.places` retains provider order and duplicate matches, with checked
names, details and coordinates. Empty matches are successful; transport, decoding,
throttling and cancellation are thrown as `PhotonGeocoder.SearchError`. The
`httpStatus` case retains a bounded `retryAfter` string when usable; it never
causes an automatic retry. Each call has a ten-second resource deadline, a 512 KiB
decompressed response bound and at most three same-origin redirects.

Render `matches.attributions` beside the results, and retain those credits with
any opened place/marker. Choose an application-owned selection ID; results have
no promised permanent provider identity. On explicit activation, construct a
`MapMarker` and new `MapCamera` using `place.coordinate`, retaining the current
longitude span. A valid geographic pole is outside the camera's Mercator range:
report that limitation and preserve the previous map rather than clamp it.

The application owns submission, cancellation, stale-result rejection, focus and
any network-use policy. The [map example](Examples.md#place-search) composes native
text input and a list without reranking remote matches through `SearchableList`.
Changing style or moving the map never invokes geocoding automatically. Search
and tile providers can be replaced independently.

### Reverse lookup

`MapReverseGeocodingProvider` is separate from forward search. Choose its complete
Photon reverse endpoint explicitly; it need not share a host with search or tiles:

```swift
let reverseGeocoder = try PhotonReverseGeocoder(
    endpoint: URL(string: "https://photon.komoot.io/reverse")!,
    userAgent: "MyMapApp/1.0 (contact@example.com)"
)
let lookup = try MapPlaceLookup(coordinate: camera.center, limit: 1)
let matches = try await reverseGeocoder.reverse(lookup)
```

The result is the same attributed `MapPlaceMatches`: retain its credits even when
empty, and explicitly decide whether to open a place. Provider ordering does not
promise that an address contains the coordinate. Limits are `1...10`, defaulting
to one; no network access occurs during construction or map movement. The adapter
shares the forward client's byte, deadline, redirect and validation bounds;
`PhotonReverseGeocoder.LookupError` aliases `PhotonGeocoder.SearchError`.

### Offline tile packs

Prepare a pack programmatically from application-supplied OpenMapTiles-compatible
raw MVT bytes. The producer receives each XYZ address in the checked plan:

```swift
let plan = try MapTilePackPlan(bounds: bounds, zoomRange: 10...12)
let pack = try await MapTilePack.create(at: packURL, plan: plan, metadata: metadata) { tile in
    let file = tileDirectory.appendingPathComponent("\(tile.zoom)-\(tile.x)-\(tile.y).pbf")
    let handle = try FileHandle(forReadingFrom: file)
    defer { try? handle.close() }
    return try handle.read(upToCount: 16 * 1_024 * 1_024 + 1) ?? Data()
}
let loader = MapTileLoader(pack: pack)
let snapshot = try await loader.load(request)
// Stop and await the consumer's loads before closing:
await pack.close()

// A later launch can open the same file, including from read-only storage:
let reopened = try MapTilePack.open(at: packURL)
let offlineLoader = MapTileLoader(pack: reopened)
```

The destination must not exist and its parent must exist. Preparation requires
every planned tile before publication. Plans accept nonwrapping bounds, source
zooms 1…22 and at most 1,024 tiles. The raw-byte budget defaults to 128 MiB, with
a 256 MiB ceiling and 16 MiB per tile; bounded framing is additional. An excessive
plan fails before invoking the producer. The producer owns its own I/O and
cancellation responsiveness. Empty successful tiles are permitted.

Packs feed the existing bounded memory cache on demand, without HTTP expiry,
writable cache copies, discovery or network fallback. Missing coverage throws
`MapTileLoader.LoadingError.outsidePackCoverage`; corrupt packs and malformed MVT
remain distinct failures. Replacing a pack requires a new reader/loader. Close
the reopened reader after its consumers stop, just as above. See the
[storage contract](Decisions/OfflineTilePacks.md) for integrity, publication and
process-interruption limits. Provider archive downloads are not implemented.

### Routing

Request explicitly, then give the accepted geometry an application-owned overlay ID:

```swift
let router = try OSRMRouter(
    endpoint: serviceEndpoint, // complete /route/v1/{profile} prefix
    userAgent: applicationIdentity,
    attributions: serviceCredits // [MapAttribution], required even for no route
)
let request = MapRouteRequest(origin: start, destination: finish)
let response = try await router.route(request)
if let route = response.route {
    let overlay = try MapRoute(id: "selected-route", title: "Route", path: route.path)
    // Supply overlay through MapOverlays and show response.attributions nearby.
    // route.distanceMeters and route.durationSeconds are optional estimates.
}
```

Implement `MapRoutingProvider` to use another service. An absent route is a
successful no-route response; network, decoding and snapping failures throw.
Geometry endpoints can differ from requested points after snapping. The server's
prepared graph determines travel mode. Chio does not add turn instructions,
automatic rerouting, a default endpoint or hidden requests from `MapView`.
See [routing contracts and bounds](Decisions/Routing.md) and the
[offline example](Examples.md#routing).


## Tabs

Use SwiftTUI's tab declarations with stable values; the theme supplies their style:

```swift
// selection is application-owned @State.
TabView(selection: $selection) {
    Tab("Overview", value: "overview") { OverviewView() }
    Tab("Notes", value: "notes") { NotesView() }
    Tab("Activity", badge: "4", value: "activity") { ActivityView() }
}
.style(.default)
```

Accent text and the rule show selection; a filled label shows keyboard focus.
Arrows choose a tab, Return or Space opens it, and Tab enters its controls.
Narrow layouts expose trailing tabs through More. Give the tab view a bounded
height with room for its content; the overflow menu needs at least three columns
and five rows including the strip and border. Stable native tab values retain
value state when switching away and back. Keep durable data in an application owner if it must
survive removing tabs or replacing the tab view's identity.

The [tabs example](Examples.md#tabs) demonstrates editing, scrolling and native
focus. See [the design](Decisions/Tabs.md#tabs) for the native lifecycle and overflow limits.

## Pagination

Bind an immutable pagination value to native page actions:

```swift
@State private var pagination = Pagination(totalCount: 23, pageSize: 5)

// In the view body, render items[pagination.itemRange] and then:
PageControl(pagination: $pagination)
    .style(.default)
```

The control displays the current page and item range. Tab focuses an available
arrow button; Return/Space activates it. Left/Right and Home/End navigate while
the page controls are focused. Empty results say “No pages”; empty and single-page
sets disable both actions.

When the data changes, choose the position policy explicitly:

```swift
pagination = pagination.updatingTotalCount(to: items.count) // Keep/clamp page.
pagination = pagination.resizingPages(to: 10) // Keep the old first item in view.
pagination = Pagination(totalCount: filtered.count, pageSize: 10) // Reset page.
```

Counts must be nonnegative and page sizes positive. `pageIndex` is zero-based and
nil for an empty set. `selectingPage(at:)` returns a replacement or nil for an
invalid page. Give `PageControl` at least 20 columns for ordinary summaries;
large numbers truncate within the available width. The application owns data and
loading. See the [history example](Examples.md#pagination) for filtering and sizing.

## Scrolling

Native scroll views acquire Chio's muted indicators and accent focus treatment:

```swift
@State private var position = ScrollCellOffset.zero

// In the view body:
ScrollView([.horizontal, .vertical], position: $position) {
    ActivityLog()
}
.frame(height: 16)
.style(.default)
```

Give the viewport a finite size along its scrolling axes. Use native
`.scrollIndicators(.hidden)` to hide tracks, or `.scrollViewStyle(...)` inside
the theme scope to override the style. Custom theme `mutedText` and `accent`
colors control idle and focused indicators. Content backgrounds remain authored.
Focus-effect suppression keeps the indicators muted without disabling scrolling.

The native runtime retains keyboard, wheel, drag and position ownership.
For a two-axis viewport, Home/End act vertically; focusing its horizontal track
lets Home/End act horizontally. The [viewport example](Examples.md#scrolling)
demonstrates this directly. Native Lists and Tables use their own styles.
The pinned runtime can nudge the horizontal position by one cell when focus
enters a viewport with reserved tracks. An oversized vertical target keeps its
first row visible. Left corrects the initial horizontal nudge; Home returns to
the first row after vertical scrolling. The automatic style behaves the same way.

## Expandable groups

Style native disclosure groups through the theme:

```swift
@State private var expanded = false

// In the view body:
DisclosureGroup("Details", isExpanded: $expanded) {
    Text("Build settings and notes go here.")
}
.style(.default)
```

Nest groups to build a hierarchy, or disclose ordinary controls and help text.
The theme supplies a compact header, focus highlight and indentation. Native
Tab/Shift-Tab moves focus; Return/Space or clicking the header toggles expansion.
Clicks on content leave the parent open. Theme colors customize this treatment,
and a nearer `.disclosureGroupStyle(...)` can override it.

Keep bindings for values that must survive collapse in an owner outside the
group. SwiftTUI removes collapsed content; it does not archive arbitrary child
state. Native arrows move focus geometrically, without tree-specific expand/
collapse commands. See the [project-tree example](Examples.md#expandable-tree)
for parent-owned expansion choices and native scrolling.

## Command palettes

`ChioPaletteStyle` styles SwiftTUI's native command palette. Apply `.style(...)`
after `.paletteSheet(...)` so the palette declaration receives the theme's style.
Keep command registration and presentation in native SwiftTUI APIs; the
[dashboard example](Examples.md#dashboard) demonstrates filtering and activation.

## Forms

Forms use the same native composition. `FormField` supplies consistent headings,
help, and inline errors; immutable `FormValidation<Field>` controls when current
errors become visible. Assign the value returned by `recordingExit(from:)` after
blur. `submitting(issues)` returns a tuple with the new `validation` value and
`firstInvalidField`; assign the former and use the latter for native focus.
Applications own the validation rules, bindings, and native focus requests. See
[CreateAgentView](../Examples/AgentDashboard/Presentation/CreateAgentView.swift) for
the complete workflow and [AgentDraft](../Examples/AgentDashboard/Domain/AgentDraft.swift)
for its pure validation rules.

`description` defaults to `""`; empty descriptions add no helper row. Errors retain
presence: `error: nil` means no visible issue, while a present message takes
precedence over the description, including an empty message.

For grouped editing, put explicit stacks of `FormField` controls inside native
`GroupBox` views, with Save/Cancel outside the scrolling fields. Keep conditional
field values in a parent-owned draft; validate the visible fields against the
current draft, including relationships between fields. Replace the saved snapshot
only on successful validation, and restore that snapshot on Cancel. The
[grouped settings example](Examples.md#grouped-forms) demonstrates these choices
without introducing a form coordinator or a separate focus system.

## Multiple choices

For multiple choices, bind a set of stable IDs:

```swift
SearchableChecklist(capabilities, selection: $selectedIDs,
                    searchText: \.name, isEnabled: \.isAvailable) { capability in
    Text(capability.name)
}
.filtering(.fuzzy)
```

Filtering changes the visible rows, never the checked set. Removed IDs and already
checked disabled choices remain in the application binding and are reported as
unavailable; disabled choices cannot be toggled. Applications explicitly validate,
clear, or replace them. Selection limits and submit/cancel behavior belong to the
form, as shown by [the choice example](../Examples/AgentDashboard/Presentation/ChoiceExampleView.swift).
Use `.onResultKeyPress` for ordinary-character shortcuts scoped to results.
Return into results completes at the next frame; additional keys in that same
input batch are consumed so they cannot toggle an old row.

## Text entry

Use native SwiftTUI controls inside Chio’s field presentation:

```swift
VStack {
    FormField("Password") {
        SecureField("Password", text: $password)
    }
    FormField("Notes") {
        TextEditor(text: $notes).frame(height: 8)
    }
}
.style(.default)
```

`SecureField` inherits `ChioTextFieldStyle`; `ChioTextEditorStyle` surrounds the
native editor with theme colors and a focus border. SwiftTUI owns masking,
editing, selection, wrapping, and scrolling. Give the editor a bounded height
when it should scroll. Native `.onSubmit` handles Return in a password field;
Return in a multiline editor always edits the text.

Apply `.style(...)` to customize enabled editor text along with its frame.
The pinned native editor supplies its own disabled text color and dimming, so
that inner disabled color is not currently a Chio theme token.

## Confirmation and feedback

`.style(...)` installs `ChioPromptStyle` for native alerts/confirmation dialogs
and `ChioSpinnerStyle` for native `Spinner` stages. Toast styles are passed explicitly:

```swift
content
    .toast("Saved", isPresented: $showsToast,
           style: ChioToastStyle(theme: theme, tone: .success))
    .style(theme)
```

Native prompts retain their header paint and modal focus behavior. Custom action
closures must clear their presentation binding; a button role alone does not
dismiss a prompt. Keep action labels short, or compose a `VStack` in the action
builder when a vertical arrangement fits better.

## File selection

```swift
FilePicker(directory: startingDirectory, selection: $selectedFile,
           allowedExtensions: .only(["swift", "md"]), onConfirm: { url in
    // Use the explicitly confirmed URL.
}, onCancel: {
    // Dismiss the picker; selectedFile keeps its previous value.
})
.style(.default)
```

Omit `allowedExtensions` or pass `.all` to allow every regular file; `.only([])`
allows none. `.only([""])` permits extensionless files. Matching ignores case,
and folders stay visible for navigation. Hidden files
are off by default; pass `showsHiddenFiles: true` to include them. File and folder
symlinks work, and the returned URL retains the chosen path. The starting folder
does not restrict navigation. Confirmation rechecks readability and file kind;
applications still handle errors when opening the file themselves.

For callers of the earlier optional APIs, replace `allowedExtensions: values`
with `allowedExtensions: .only(values)`, and replace `nil` with `.all` or omit the
argument. Pass `optionalDescription ?? ""` or `optionalDetail ?? ""` when adapting
external optional text to `FormField` or `ShortcutHint`. Selection, errors and
`replacing(...)` arguments retain their existing optional semantics.

## Markdown

Markdown also composes with native views. Parse when the source changes and pass
the retained value to `MarkdownView`; avoid reparsing inside a frequently updated
`body`:

```swift
struct ReportView: View {
    let document: MarkdownDocument // Created by the content owner when its source changes.

    var body: some View {
        ScrollView {
            MarkdownView(document)
        }
        .style(.default)
    }
}
```

The first Markdown slice supports headings, paragraphs, strong/emphasized text,
inline and fenced code, lists, quotes, rules, and aligned tables with native
horizontal scrolling. Table body cells retain rich text; native headers use plain
labels with themed colors. Passive links and images show readable labels and destinations;
HTML is literal. Native table border colors remain an upstream styling limitation.

Swift fences highlight automatically: the first word of the fence information
must be `swift` (case-insensitive). Unknown and unlabeled code stays plain. Code
parsing and token classification happen when `MarkdownDocument` is constructed,
so retain the document through theme and view updates. To read all code in plain
foreground paint:

```swift
MarkdownView(document).codeHighlighting(.plain)
```

The default is `.automatic`. This modifier also works on the interactive-link
initializer below and retains its opening action. Customize token colors through
the theme:

```swift
let theme = ChioStyle.default.replacing(
    syntax: ChioStyle.default.syntax.replacing(keyword: .cyan, comment: .white)
)
MarkdownView(document).style(theme)
```

`theme.syntax` has `keyword`, `type`, `string`, `number`, and `comment` roles;
plain identifiers, punctuation, and operators inherit the enclosing foreground,
normally `theme.colors.foreground` (secondary text inside a quote).
Code over 65,536 UTF-8 bytes remains plain. Parsing also has a deterministic
4,096-progress-checkpoint budget; cancellation displays the whole block plainly.
This is a work bound at parser callbacks, not a hard time or memory limit. The
Swift grammar may not recognize every latest language feature. Highlighting keeps
malformed and partially recognized code literal, and colors a complete string,
including interpolation, with one role. It retains parsed source text, blank rows,
and trailing newlines in one native rich `Text` within the existing horizontal
scroll view. Tab focuses the code; arrows and Home/End navigate its columns. Markdown parsing normalizes
CRLF to LF, and the pinned native renderer displays tabs as one cell without
tab-stop expansion.

To enable links, supply SwiftTUI's native action explicitly:

```swift
MarkdownView(document, openLink: OpenLinkAction { destination in
    selectedDestination = destination.rawValue
    return true // The application handled this destination.
})
```

Here `selectedDestination` is application state. The callback can route to another
view, show a destination, or apply the app's opening policy. Return `false` to
leave a destination unhandled; Chio does not then invoke an outer/system opener.
Relative paths and fragments are delivered unchanged. Rendering never invokes
the action, and the original initializer remains passive.

Use Tab/Shift-Tab and Return/Space for native link navigation and activation.
Traversal reaches visible native focus targets; focus the containing scroll view
and scroll to reveal links farther down a document or across a wide table.
Rich labels wrap with surrounding prose and remain one focus stop. Empty
Markdown destinations stay passive. Table body links can activate; native table
headers keep their plain readable fallback. `.disabled(true)` suppresses native
link interaction. `.style` also styles ordinary SwiftTUI `Link` values;
use a nearer `.linkStyle(...)` to customize their presentation. Active Markdown
code labels inherit link paint so focus remains visible.

See [AgentReport](../Examples/AgentDashboard/Domain/AgentReport.swift) for snapshot
ownership and [AgentReportView](../Examples/AgentDashboard/Presentation/AgentReportView.swift)
for the reader.

## Duration labels

Present durations from your application's state or a native timeline:

```swift
DurationText(elapsed: .seconds(83))             // 1:23
DurationText(remaining: .milliseconds(12_250))  // 0:13
DurationText(elapsed: .seconds(83), style: .segmented)
```

Apply `.style(...)` around the composition. Elapsed fractions round down;
positive remaining fractions round up. Formats are `m:ss` and `h:mm:ss`, with
hours continuing past 24. Inputs range from zero through
`Duration.seconds(Int64.max)`. Both labels use accent color and readable spoken
accessibility labels. Plain text is the default; `style: .segmented` shares
`InstrumentReadout`'s three-row lettering and native text fallback for small
allocations, while preserving the same rounding and spoken labels.

The application owns measurement, countdown limits, pause/resume and expiry
behavior; SwiftTUI's `TimelineView` can drive presentation updates. The
[focused example](Examples.md#timers-and-stopwatches) demonstrates one application
implementation. Its internal
[`ElapsedTime`](../Examples/AgentDashboard/Domain/ElapsedTime.swift) helper is no
longer exported by Chio. Code using that experimental API must move its timing
state into the application. Existing `DurationText` calls retain plain text and
their formatting behavior.
