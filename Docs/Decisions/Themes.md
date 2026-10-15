# Styles and native control styling

**Status:** Accepted and implemented. The unified `ChioStyle` API and promotion of
the appearance recipes are verified in [PR #10](https://github.com/echoz/Chio/pull/10).
They are included in the [0.2.0 release preparation](../Releases/0.2.0.md), which records scope and evidence.
Ordinary calls to the theme API shipped in 0.1.0 remain supported. The
[release migration notes](../Releases/0.2.0.md#migration-from-010) describe a narrow
break for references to the former four-component initializer and replacement
signatures; explicit closures preserve those call sites.

Use an immutable style and native control styles to give a subtree coherent
presentation while retaining SwiftTUI behavior.

<a id="theme"></a>

## Style

`ChioStyle` contains semantic colors, syntax/map/gauge palettes, spacing,
treatments and surfaces. `View.style(_:)` applies one complete value through
`EnvironmentValues.chioStyle` and installs native styles. Descendants inherit
that value; the nearest complete style overrides the inherited value rather than
merging fields. Use `replacing(...)` on a style and its nested values for explicit
customization. Native modifiers such as `.groupBoxStyle(...)` remain specific
component overrides; place them inside the enclosing `.style(...)` scope.

`ChioTheme` is a typealias for `ChioStyle`. `.chioTheme(...)` forwards to
`.style(...)`, and the compatibility environment accessor forwards to the same
key. There is no parallel theme/style state. Existing native style initializers
retain their `theme:` labels for source compatibility.

Static `.default`, `.light`, `.btop` and `.opencode` values are starting points,
not a registry. Colors, spacing, treatments and surfaces are independently
customizable. Presets contain ordinary values; rendering never branches on a
preset name. The default and light appearance remain unchanged. Applying `.btop`
now gives native groups border headings through the global modifier: this is an
intentional visual change from the earlier palette-only preset. `.opencode`
combines warm accents, leading panel/input edges and roomier input padding;
its list rows remain compact.

`Surface` is `.base` or `.color(Color)`. `surfaces.canvas` and `surfaces.input`
default to `.base`, resolving from `colors.surface` even after palette replacement.
An explicit color overrides that role; replacing it with `.base` restores
inheritance. Ordinary panel content retains the base surface.

`Spacing` measures terminal cells. The new `inputVerticalInset` defaults to zero
and requires `0...32` through construction, replacement and decoding. A missing
key in historical encoded spacing decodes as zero. The original four spacing
fields retain their nonnegative contract and existing values.

All new per-row density controls are deferred and are not public style fields.
[Native integration](NativeIntegration.md#current-row-qualification) owns the
mixed-height reveal regression and its native measurement-retention correction.
SwiftTUI 0.18.0 adoption qualifies the retained list regressions before a new density
field; broader pointer and style-change qualification remains separate. This deferral
does not block the unified style API. Applications retain row content and width policy.

Construction and replacement preserve printable single-cell glyph preconditions.
Options own component behavior. Applications own content, data, breakpoints,
column widths, navigation and responsive composition. Style changes preserve
query, stable selection, focus, entered values and relevant native scroll positions
within the supported native layout contracts.

`GaugeColors` defines independent `arc`, `target` and `needle` roles for target-band
dials. Customize with `style.replacing(gauge: style.gauge.replacing(target: ...))`.
These roles do not recolor ordinary bars or plain dials. Native `StrokeStyle`
retains its conformance limits; `ChioStyle` and `Treatments` are equatable and
sendable, without lossy hashing or coding of strokes.

Native groups, lists, tables, buttons, links, text fields/editors, pickers, toggles,
tabs, scroll/disclosure views, progress, spinners and prompts share semantic roles.
When a border heading is requested without a top border, it returns to content
flow so it cannot cover the first authored row. Bordered buttons inherit their surface and use an accent outline for focus/enabled
press, or error for destructive actions. Idle borders use the ordinary border
color; disabled controls retain native dimming. Focus-effect suppression removes
the focused outline. Authored labels remain native content. Outlines avoid a
whole-cell rectangular fill behind rounded border glyphs.

## Implementation and verification

- [ChioStyle.swift](../../Sources/Chio/Style/Domain/ChioStyle.swift)
- [View+ChioStyle.swift](../../Sources/Chio/Style/Presentation/View+ChioStyle.swift)
- [ChioTheme.swift compatibility alias](../../Sources/Chio/Theme/Domain/ChioTheme.swift)
- [ChioThemeTests.swift](../../Tests/ChioTests/Theme/Domain/ChioThemeTests.swift)
- [Required checks](../Verification.md)

## Appearance study

The earlier example-only recipes are superseded by the approved public style
values. `chio-dashboard --appearance` compares identical local list, form and
instrument content using `.default`, `.opencode` and `.btop` through `.style(...)`.
The retained CLI spelling `--treatment chio|opencode|btop` selects those values;
`--density compact|roomy` replaces spacing only. Example layout and navigation
remain application-owned. The separate comparison page shows these three styles;
the main catalog currently has only default, light and btop captures.

OpenCode's authored padding, background surfaces and leading edges inspire the
roomy style; btop informs compact border headings. These are interpretations,
not integrations or claims of upstream parity. All six comparison captures and
the affected btop catalog previews were refreshed and inspected alongside
interactive narrow sessions and assembled-site browser checks. Future appearance
changes require the same [verification](../Verification.md); captures alone do
not establish native interaction or platform correctness. Pages publishes from
`main` after merge.

## References

- [SwiftTUI style system](https://github.com/SwiftTUI/swift-tui/blob/2d84ac7083993da2ef52e9d3d30255467efb9553/Sources/SwiftTUIViews/SwiftTUIViews.docc/Style-System.md)
- [SwiftTUI theme model](https://github.com/SwiftTUI/swift-tui/blob/2d84ac7083993da2ef52e9d3d30255467efb9553/Sources/SwiftTUIPrimitives/Styling/Theme.swift)
- [Huh themes](https://github.com/charmbracelet/huh/blob/main/theme.go)
- [Bubbles list](https://github.com/charmbracelet/bubbles/tree/main/list) and [help](https://github.com/charmbracelet/bubbles/tree/main/help)
- [OpenCode themes](https://opencode.ai/docs/themes/), [sidebar](https://github.com/anomalyco/opencode/blob/dev/packages/tui/src/routes/session/sidebar.tsx) and [prompt](https://github.com/anomalyco/opencode/blob/dev/packages/tui/src/component/prompt/index.tsx)
- [btop configuration and themes](https://github.com/aristocratos/btop)
