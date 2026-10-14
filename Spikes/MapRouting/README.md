# Route readability spike

An isolated visual experiment using the public `MapView`, existing route halo,
markers, styles and native SwiftTUI renderer. No public API, routing client or
renderer behavior changes. Start from the repository root:

```sh
swift run -c release RouteReadability --route-case street --muted-roads
```

Arrow keys pan; `+`/`-` zoom; `n`/`p` select endpoints; `o` toggles fills;
`l` toggles labels; `r` restores the fixed camera; `q` exits.
Use `--route-case hairpin` or `--route-case crossing` for deliberately difficult geometry.
`--theme light` and `--theme btop` use existing themes. `--detail source` reveals
the dense background. `--outlines` removes area fills. `--endpoint none` and
`--no-markers` isolate the line itself. The muted presentation is a local style
override, not a new framework default. Both endpoint markers use current native
map presentation; only the selected endpoint receives the larger yellow ring.
The refined muted style uses luminous mint (`#7DFFF3`) on dark surfaces and dark
teal (`#00606B`) on light surfaces. Major roads/coastlines retain 55% of their
previous muted color difference from the canvas; area fills retain 45% of their
original difference. Credits keep their existing text color and selected endpoints
keep the theme's warning color. This does not add new semantic color roles.

The street fixture is 84 vertices copied from 55 connected, retained OpenStreetMap
road segments around Raffles Boulevard, Raffles Avenue and Bayfront Avenue.
It is **not a calculated or validated driving/walking route**: direction, access,
turn restrictions and snapping have not been checked. Hairpin and crossing paths
are synthetic stress cases, not streets. All modes explicitly say this is not
navigation. No provider request occurs.

Geometry and source provenance come from
[`Examples/Maps/Fixtures`](../../Examples/Maps/Fixtures/Provenance.md).
The original Singapore GeoJSON SHA-256 is
`a66ac5a0e2ab151382b4cef84739267ea2a9031a18b9edc0db9308795ca41772`.
The checked path and copied metadata are retained in `Fixtures`; the larger map
is reused via `--fixture-root`, not duplicated. OpenStreetMap contributors retain
the ODbL 1.0 credit shown by the view.

## Captures

Build the executable, then run the matrix with a Python interpreter containing
Pillow (the same optional dependency as the existing map snapshot renderer):

```sh
swift build -c release --product RouteReadability
python3 Scripts/maps/capture-routes.py
```

Outputs go to `.build/route-readability`. These PNGs render **actual hosted native
raster cells** with fixed Menlo/Apple Symbols fonts at 12×24 pixels per cell. They
are not screenshots of Blink/Ghostty, and do not establish SSH or font behavior.
The same camera, path and allocation are retained across style comparisons;
wide (100×34), narrow (60×24) and below-minimum (36×18) captures are explicit.
The existing map's bounded preparation, clipping, minimum allocation, route cell
color priority and one-dot halo are unchanged.

Provider integration follows this visual assessment. OSRM is a research candidate;
no endpoint, mode, snapping policy or public routing contract is selected here.

## Findings and evidence — 2026-10-13

- A bright route over muted roads is easier to follow than the existing bright
  road palette. This needs only a scoped style replacement; no new renderer is
  needed. The same geometry remains legible at 100×34 and 60×24 cells.
- Minimal geography retains enough context; source detail adds competing road
  and building edges. Outline-only retains route contrast but loses land/water
  context. The light and btop styles retain a distinct route color.
- The selected Start and Finish rings are readable in separate fixed-camera
  captures. Unselected endpoints remain too subtle, especially with the muted
  foreground; this is an unresolved presentation issue, not endpoint approval.
- Tight switchbacks collapse into bands at the narrow allocation, and
  self-crossings do not communicate travel direction or road level. A readable
  overview does not establish navigation readability. Avoid distorting or dropping
  route geometry merely to make these cases attractive.
- All dots within a route-occupied cell remain the same accent color; the existing
  halo removes competing geography there. It cannot separate two portions of the
  same route that occupy the same dot. Below the map minimum, preserve the native
  compact fallback instead of presenting a misleading partial route.

The release executable builds on macOS. All 14 native capture cases pass, including
selected Finish and no-marker comparisons; the matrix rejects an unexpected
compact fallback and checks route-colored Braille in every drawing case.
The existing overlay, map interaction and drawing-work release suites pass
28 tests. A real PTY check passes pan, zoom, endpoint selection, compact/wide
resizing, clean exit and exact terminal-mode restoration, with no runtime warnings.
Independent review checked the code, actual images and fixture provenance; its
endpoint-coverage and unintended-fallback findings were addressed in the matrix.

The pinned SwiftRules 0.1.3 check passes over 337 files with the existing 414-entry
baseline unchanged. Authenticated release metadata still resolves 0.1.4 to
`fc3de546794e7e4b0429b0b03e282ac7218bde8b`; its existing
[conformance-maintenance deferral](../../Docs/Verification.md#deferred-014-adoption)
remains. This spike does not qualify a checker upgrade, full CI, Linux, SSH or
actual terminal-emulator font appearance. No live route was requested.

After the requested stronger muting/brighter-route refinement, the macOS release
build, all 14 capture cases and pinned engineering check pass again. The native
before/after street rasters have identical dimensions and glyphs; only colors
change. The earlier unchanged interaction/geometry evidence is reused, not rerun.
