# MapView

`MapView` presents a themed, north-up geographic map with supplied geometry and
overlays. The application owns the source, camera binding, selected marker ID,
loading policy and external operations. This root keeps the map implementation
and its supporting acquisition, storage, geocoding and routing APIs together.

## Use

Import `Chio` and `SwiftTUI`. Supply a `MapSource` and retained bindings:

```swift
MapView(source: source, camera: $camera, selection: $selectedID,
        overlays: overlays, detail: .minimal)
    .mapFills(true)
    .mapLabels(true)
    .onActivate { marker in openedID = marker.id }
    .frame(width: 80, height: 24)
    .style(.default)
```

`source:` also accepts nil while the application acquires data. Selection
defaults to a constant nil binding, overlays to `.empty`, and detail to `.minimal`.
`onViewportChange` reports the actual drawing allocation, or nil in compact
fallback; observing the viewport never requests tiles.

## Interaction, effects and limits

Arrows pan; plus/minus zoom; N/P select and center the next/previous marker;
Return explicitly activates selection. Tab leaves the single native focus target.
Bindings remain authoritative, including rejected writes and unknown selected IDs.
External selection changes do not implicitly move the camera.

The view owns a serial geometry preparation worker and native task cancellation.
Results must match the current request before painting. Loading tiles, geocoding
and route calculation require explicit application calls; the view does not
invoke them. `MapTileLoader`, `MapTileCache`, `MapTilePack`, Photon adapters and
`OSRMRouter` are supporting public APIs, not additional view deliverables.

The component uses its assigned allocation and inherited style. Small allocations
retain controls with summary/resize guidance; excessive preparation or drawing
work rejects the whole drawing. Source attribution remains part of presentation.
Drawing is capped at 240 × 100 cells. The accepted
[geographic map contract](../../../Docs/Decisions/GeographicMaps.md) owns exact
geometry, aspect, coverage, fallback and work bounds.

## Source and verification

- [MapView.swift](Presentation/MapView.swift) owns composition, bindings and preparation lifetime.
- [MapSource.swift](Domain/MapSource.swift) and [MapOverlays.swift](Domain/MapOverlays.swift) define supplied geographic inputs.
- [MapPreparationWorker.swift](Execution/MapPreparationWorker.swift) owns serial preparation.
- [Protocol](Protocol) contains source/provider substitution contracts; [Serialization](Serialization) contains supported codecs.
- [MapViewInteractionTests](../../../Tests/ChioTests/Maps/Presentation/MapViewInteractionTests.swift) covers readiness, allocation, bindings, input and focus.
- [MapOverlayRenderingTests](../../../Tests/ChioTests/Maps/Presentation/MapOverlayRenderingTests.swift) covers paint priority and combined drawing admission.
- [ChioMapTests](../../../Tests/ChioMapTests) covers map models, adapters, rendering and example integration.

Follow [online acquisition](../../../Docs/Decisions/OnlineMaps.md),
[offline packs](../../../Docs/Decisions/OfflineTilePacks.md),
[place search](../../../Docs/Decisions/PlaceSearch.md) and
[routing](../../../Docs/Decisions/Routing.md) for supporting API contracts.
[Usage](../../../Docs/Usage.md) supplies recipes; [Verification](../../../Docs/Verification.md)
distinguishes local, platform and terminal evidence. Tests do not establish live
provider availability or latency in every terminal/SSH environment.
