# Themes and native control styling

**Status:** Accepted; shipped in 0.1.0. These contracts remain current.

Use semantic themes and native styles to give controls coherent paint while retaining SwiftTUI behavior.

## Theme

`ChioTheme` contains semantic colors, syntax/map/gauge palettes, spacing and treatments;
`.chioTheme(...)` applies it through the environment and installs native styles.
Use `replacing(...)` on the theme and nested values to customize presentation.
Construction and replacement preserve nonnegative spacing and printable
single-cell glyph preconditions. Options own component behavior; application
composition owns content and layout.

`GaugeColors` defines `arc`, `target` and `needle` for target-band dials. Customize
it with `theme.replacing(gauge: theme.gauge.replacing(target: ...))`. These roles
are independent of status colors and do not recolor ordinary bars or plain dials.
The palette is immutable, hashable, codable and sendable; theme equality includes
it. The overall theme retains its existing native-type conformance limitations.

The default, light and btop presets share the same interaction policy. The
executable's `ExampleTheme` is an internal comparison choice, not a public theme
registry or restriction on custom values. Theme changes preserve query, stable
selection, focus, entered values and relevant native scroll positions.

Native groups, lists, tables, buttons, links, text fields/editors, pickers, toggles,
tabs, scroll/disclosure views, progress, spinners and prompts share semantic roles.
Bordered buttons inherit their surface and use an accent outline for focus/enabled
press, or error for destructive actions. Idle borders use the ordinary border
color; disabled controls retain native dimming. Focus-effect suppression removes
the focused outline. Authored labels remain native content. Outlines avoid a
whole-cell rectangular fill behind rounded border glyphs.

## Implementation and verification

- [ChioTheme.swift](../../Sources/Chio/Theme/Domain/ChioTheme.swift)
- [View+ChioTheme.swift](../../Sources/Chio/Theme/Presentation/View+ChioTheme.swift)
- [ChioThemeTests.swift](../../Tests/ChioTests/Theme/Domain/ChioThemeTests.swift)

## Appearance study

**Status:** Example-only comparison; public API promotion awaits visual review.

`chio-dashboard --appearance` compares identical local list, form and instrument
content using Chio, OpenCode-inspired and btop-inspired recipes. Palette, cell
spacing and framing are separate presentation choices. Existing `ChioTheme`
values provide colors and spacing; two pure native styles in the example explore
leading-edge groups/editors and compact border headings. No new public preset,
style protocol, renderer, focus system or theme registry is introduced.

`--density compact|roomy` overrides spacing while retaining the recipe's palette
and framing. Narrow padding, three-column versus stacked composition, section
navigation and form state remain application-owned. Styles consume supplied
configuration without effects; recipe changes must preserve native editor and
selection identity, query and entered values. Actual terminal recordings and
the same-width comparisons are the acceptance material for a later decision
about shared surface roles and component treatments.

OpenCode's component-authored padding, background surfaces and leading edges
inspire the roomy recipe; its theme files are primarily semantic color roles.
btop separates color themes from layout presets and rounded-border configuration.
Neither reference implies encoding application pane sizes or breakpoints into
Chio's theme. The experimental colors are an interpretation, not a claim to
reproduce every upstream theme.

## References

- [SwiftTUI style system](https://github.com/SwiftTUI/swift-tui/blob/2d84ac7083993da2ef52e9d3d30255467efb9553/Sources/SwiftTUIViews/SwiftTUIViews.docc/Style-System.md)
- [SwiftTUI theme model](https://github.com/SwiftTUI/swift-tui/blob/2d84ac7083993da2ef52e9d3d30255467efb9553/Sources/SwiftTUIPrimitives/Styling/Theme.swift)
- [Huh themes](https://github.com/charmbracelet/huh/blob/main/theme.go)
- [Bubbles list](https://github.com/charmbracelet/bubbles/tree/main/list) and [help](https://github.com/charmbracelet/bubbles/tree/main/help)
- [OpenCode themes](https://opencode.ai/docs/themes/), [sidebar](https://github.com/anomalyco/opencode/blob/dev/packages/tui/src/routes/session/sidebar.tsx) and [prompt](https://github.com/anomalyco/opencode/blob/dev/packages/tui/src/component/prompt/index.tsx)
- [btop configuration and themes](https://github.com/aristocratos/btop)
