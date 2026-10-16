# Map example

`chio-maps` composes the public `MapView` with bundled world/street geography,
application-authored locations and synthetic routing/search workflows.
The [package overview](../../README.md) records prerequisites, dependency limits
and the project's personal-software and Codex-assisted development status.

## Run from the repository root

```sh
swift run -c release chio-maps --map world
swift run -c release chio-maps --map street --route-demo --theme btop
```

Start at 100 × 30 cells. Arrows pan, `+`/`-` zoom, `n`/`p` select locations,
Return activates the selected location, and Tab leaves through native focus.
Space switches world/street, `t` cycles themes, `[`/`]` adjust detail, `f` switches
fills/outlines, `l` toggles labels, `r` resets the camera and `q` quits.
The [complete map guide](../../Docs/Examples.md#maps) describes remaining controls,
place lookup, routing and source options.

The default is offline. Fixtures include Natural Earth and OpenStreetMap-derived
sources; [provenance and licenses](Fixtures/Provenance.md) remain authoritative.
Bundled coverage is finite. Synthetic routes are demonstrations, not validated
navigation instructions, and local place results do not prove provider behavior.

## Explicit effects and inspection

```sh
swift run -c release chio-maps --online --map street
swift run -c release chio-maps --write-tile-pack .build/world.chiomap
swift run -c release chio-maps --tile-pack .build/world.chiomap
```

`--online` opts into tile acquisition. `--tile-source` supplies explicit source
configuration; `--tile-cache` opts into a dedicated disk cache. Pack preparation
writes a file and exits; pack viewing explicitly reopens it. Cache freshness and
coverage differ from a retained offline pack. Live forward/reverse geocoding and
routing each require their own explicit endpoint options, independently of tiles.
See the [example guide](../../Docs/Examples.md#maps) for supported combinations,
provider attribution and the local HTTP fixture replay.

`--snapshot`, `--snapshot-json` and `--benchmark` use bundled data; the command
rejects online/live-provider inspection combinations. Text and raster exports
are inspection artifacts. Benchmark results measure hosted frame delivery at
selected allocations, not SSH latency or navigation accuracy.

## Source and ownership

`MapExampleCommand.swift` validates launch options and configures effects.
`MapExampleApplication.swift` composes the native scene; `Presentation` holds the
example view and search pane. `Execution` owns fixture loading, pack operations,
acquisition configuration and example search/routing requests. `Domain` and
`Serialization` hold local values and fixture metadata.

The example owns camera/selection workflow, provider submission and cancellation,
feedback and storage choices. Chio owns its reusable map rendering/acquisition
contracts, while SwiftTUI owns native focus, input and layout. Consult the
[MapView source guide](../../Sources/Chio/Maps/README.md) and
[design decisions](../../Docs/Design.md) before changing those boundaries.

## Verification

`Tests/ChioMapTests` exercises the example and its integration boundaries;
`Tests/ChioTests/Maps` covers library contracts. Follow
[repository verification](../../Docs/Verification.md#running-checks): the normal
script includes fixture reproduction, release execution and map terminal probes.
Separate cache, pack and provider checks are documented in
[Verification](../../Docs/Verification.md). Visible changes also follow the
[showcase workflow](../../Docs/Verification.md#demo-site). Fixture, raster and PTY
evidence does not establish live-provider availability or real-world route safety.
