import Chio
import SwiftTUIRuntime
import Testing

@MainActor
struct ChioStylePresentationTests {
    @Test("A nested view overrides its complete style while sibling views inherit the root")
    func nestedStyleScope() {
        let root = ChioStyle.default.replacing(colors: ChioStyle.default.colors.replacing(
            accent: Color(hexRGB: 0xA12345), secondaryText: Color(hexRGB: 0x127845)
        ))
        let child = ChioStyle.default.replacing(colors: ChioStyle.default.colors.replacing(
            accent: Color(hexRGB: 0x2378AB)
        ))
        let surface = DefaultRenderer().render(
            VStack(alignment: .leading, spacing: 0) {
                KeyHint("R", "root")
                KeyHint("C", "child").style(child)
                KeyHint("S", "sibling")
            }.style(root),
            proposal: ProposedViewSize(width: 20, height: 3)
        ).rasterSurface
        let cells = surface.cells.flatMap { $0 }

        #expect(surface.lines.contains { $0.contains("R root") })
        #expect(surface.lines.contains { $0.contains("C child") })
        #expect(surface.lines.contains { $0.contains("S sibling") })
        #expect(cells.contains { $0.character == "R" && $0.style?.foregroundColor == root.colors.accent })
        #expect(cells.contains { $0.character == "C" && $0.style?.foregroundColor == child.colors.accent })
        #expect(cells.contains { $0.character == "S" && $0.style?.foregroundColor == root.colors.accent })
        #expect(cells.contains { $0.character == "c" && $0.style?.foregroundColor == child.colors.secondaryText })
    }

    @Test("The legacy theme modifier renders the same custom presentation as the style modifier")
    func legacyModifier() {
        let base = ChioStyle.default
        let custom = base.replacing(
            colors: base.colors.replacing(heading: .yellow, foreground: .cyan, surface: .black),
            treatments: base.treatments.replacing(groupBoxTitlePlacement: .border)
        )
        let canonical = DefaultRenderer().render(
            GroupBox("Heading") { Text("Content") }.style(custom),
            proposal: ProposedViewSize(width: 18, height: 6)
        ).rasterSurface
        let legacy = DefaultRenderer().render(
            GroupBox("Heading") { Text("Content") }.chioTheme(custom),
            proposal: ProposedViewSize(width: 18, height: 6)
        ).rasterSurface

        #expect(canonical.lines == legacy.lines)
        #expect(canonical.cells == legacy.cells)
        #expect(canonical.lines.contains { $0.contains("Heading") })
        #expect(canonical.lines.contains { $0.contains("Content") })
    }

    @Test("Both public environment spellings read and write one shared style value")
    func environmentAliases() {
        var environment = EnvironmentValues()
        #expect(environment.chioStyle == .default)
        #expect(environment.chioTheme == .default)
        let first = ChioStyle.light.replacing(colors: ChioStyle.light.colors.replacing(accent: .blue))
        let second = ChioStyle.default.replacing(spacing: ChioStyle.default.spacing.replacing(inputVerticalInset: 2))

        environment.chioTheme = first
        #expect(environment.chioStyle == first)
        environment.chioStyle = second
        #expect(environment.chioTheme == second)
    }

    @Test("Arbitrary custom values select leading group edges and bordered headings without preset identity")
    func customGroupFraming() {
        let base = ChioStyle.light
        let leading = base.replacing(
            colors: base.colors.replacing(accent: Color(hexRGB: 0xA12345)),
            treatments: base.treatments.replacing(borderStyle: .single, groupBoxBorder: .leading)
        )
        let edge = DefaultRenderer().render(
            GroupBox("Heading") { Text("Content") }.style(leading),
            proposal: ProposedViewSize(width: 18, height: 6)
        ).rasterSurface
        let edgeCells = edge.cells.flatMap { $0 }
        #expect(edge.lines.contains { $0.contains("Heading") })
        #expect(edge.lines.contains { $0.contains("Content") })
        #expect(edgeCells.contains { $0.character == "│" && $0.style?.foregroundColor == leading.colors.accent })
        #expect(!edgeCells.contains { "┌┐└┘─".contains($0.character) })

        let borderTitle = base.replacing(treatments: base.treatments.replacing(
            borderStyle: .single, groupBoxTitlePlacement: .border
        ))
        let titled = DefaultRenderer().render(
            GroupBox("Heading") { Text("Content") }.style(borderTitle),
            proposal: ProposedViewSize(width: 18, height: 6)
        ).rasterSurface
        #expect(titled.lines.first?.contains("Heading") == true)
        #expect(titled.lines.contains { $0.contains("Content") })
    }

    @Test("A border heading falls back to content flow when its top border is absent",
          arguments: [Edge.Set.leading, Edge.Set()])
    func borderHeadingWithoutTopBorder(sides: Edge.Set) {
        let base = ChioStyle.default
        let custom = base.replacing(treatments: base.treatments.replacing(
            groupBoxBorder: sides, groupBoxTitlePlacement: .border
        ))
        let surface = DefaultRenderer().render(
            GroupBox("Heading") { Text("First content row") }.style(custom),
            proposal: ProposedViewSize(width: 24, height: 6)
        ).rasterSurface
        #expect(surface.lines.contains { $0.contains("Heading") })
        #expect(surface.lines.contains { $0.contains("First content row") })
    }

    @Test("Custom text field surfaces and vertical padding reach the supplied native editor")
    func customInputSurface() {
        let base = ChioStyle.light
        let inputColor = Color(hexRGB: 0x203040)
        let compact = base.replacing(
            treatments: base.treatments.replacing(borderStyle: .single, textFieldBorder: .leading),
            surfaces: ChioStyle.Surfaces(input: .color(inputColor))
        )
        let roomy = compact.replacing(spacing: compact.spacing.replacing(inputVerticalInset: 2))
        let compactSurface = DefaultRenderer().render(
            TextField("Prompt", text: .constant("query")).style(compact),
            proposal: ProposedViewSize(width: 18, height: nil)
        ).rasterSurface
        let roomySurface = DefaultRenderer().render(
            TextField("Prompt", text: .constant("query")).style(roomy),
            proposal: ProposedViewSize(width: 18, height: nil)
        ).rasterSurface
        let cells = roomySurface.cells.flatMap { $0 }

        #expect(roomySurface.lines.contains { $0.contains("query") })
        #expect(roomySurface.size.height == compactSurface.size.height + 4)
        #expect(cells.contains { $0.character == "q" && $0.style?.backgroundColor == inputColor })
        #expect(cells.contains { $0.character == "│" && $0.style?.foregroundColor == roomy.colors.border })
        #expect(!cells.contains { "┌┐└┘─".contains($0.character) })
    }
}
