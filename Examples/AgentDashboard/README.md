# Dashboard and focused examples

`chio-dashboard` is a runnable showcase of Chio composed with native SwiftTUI.
It simulates agents and offers focused interaction examples through one executable.
The [package overview](../../README.md) records prerequisites, dependency limits
and the project's personal-software and Codex-assisted development status.

## Run from the repository root

```sh
swift run -c release chio-dashboard
swift run -c release chio-dashboard --choices --theme btop
swift run -c release chio-dashboard --appearance --treatment opencode
```

Use arrows to navigate the dashboard, `/` to search, Enter to open a report,
Ctrl-K for the command palette and `q` to quit. Ctrl-T cycles the main example
themes; Ctrl-Q quits the appearance study. See the
[complete controls and launch options](../../Docs/Examples.md) for each mode.
For true-color terminals over SSH, set `COLORTERM=truecolor` when launching.

Choose one focused mode: `--choices`, `--text-entry`, `--feedback`, `--files`,
`--keyboard-help`, `--tabs`, `--pagination`, `--viewport`, `--tree`, `--forms`,
`--timers`, `--metrics`, `--instruments`, `--inbox`, `--diff` or `--appearance`.
Most accept `--theme default`, `light` or `btop`; appearance uses its own
`--treatment` and `--density` options. `--files --directory PATH` reads the real
filesystem. The other examples use local fixtures and application-owned state.

A deterministic text frame is useful for quick inspection:

```sh
swift run -c release chio-dashboard --snapshot --width 100 --height 30
```

`--files` does not support snapshots because directory loading is asynchronous.
Snapshots do not establish color quality, focus transitions or terminal cleanup.
The diff mode is a bounded read-only prototype, not a VCS client; the dashboard
does not connect to real agents. Release mode is preferred for interactive use.

## Source and state ownership

`ChioDashboardCommand.swift` validates options and selects one mode;
`Execution/ChioDashboardCommand+Execution.swift` launches its native application
or renders a snapshot. The `*Application.swift` files compose scenes,
`Presentation` owns example views, and `Domain` owns local models and fixtures.

Applications retain simulations, drafts, timers, navigation and review workflow.
Chio supplies presentation and interactions; SwiftTUI retains native state,
focus, input and layout. Styling uses `ChioStyle` through `.style(...)`.
These examples demonstrate compositions rather than additional public library APIs.
[Design](../../Docs/Design.md) owns those boundaries.

## Verification

`Tests/ChioDashboardTests` covers example values, raster output and hosted
interactions. Follow [the repository checks](../../Docs/Verification.md#running-checks),
including the release test suite and terminal probes in
`Scripts/ci/verify.sh`. Visible example changes also require the
[showcase workflow](../../Docs/Verification.md#demo-site). Passing a local fixture
workflow does not establish real-agent integration, every terminal or SSH behavior.
