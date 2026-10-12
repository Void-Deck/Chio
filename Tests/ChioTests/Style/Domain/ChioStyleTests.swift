import Chio
import Foundation
import SwiftTUIRuntime
import Testing

struct ChioStyleTests {
    @Test("Legacy callable signatures preserve new presentation properties during replacement")
    func compatibility() {
        let construct: (ChioTheme.Colors, ChioTheme.Spacing, ChioTheme.Treatments,
                        ChioTheme.SyntaxColors, ChioTheme.MapColors, ChioTheme.GaugeColors) -> ChioTheme = ChioTheme.init
        let base = ChioStyle.opencode
        let constructed = construct(base.colors, base.spacing, base.treatments, base.syntax, base.map, base.gauge)
        #expect(constructed.surfaces == ChioStyle.Surfaces())
        #expect(constructed.colors == base.colors)
        #expect(constructed.treatments.groupBoxBorder == .leading)

        let replace: (ChioTheme.Colors?, ChioTheme.Spacing?, ChioTheme.Treatments?,
                      ChioTheme.SyntaxColors?, ChioTheme.MapColors?, ChioTheme.GaugeColors?) -> ChioTheme = base.replacing
        let changed = replace(nil, nil, nil, nil, nil, ChioStyle.GaugeColors(target: .red))
        #expect(changed.surfaces == base.surfaces)
        #expect(changed.gauge.target == .red)
        #expect(base.gauge.target != .red)

        let five: (ChioTheme.Colors?, ChioTheme.Spacing?, ChioTheme.Treatments?,
                   ChioTheme.SyntaxColors?, ChioTheme.MapColors?) -> ChioTheme = base.replacing
        #expect(five(nil, nil, nil, nil, nil).surfaces == base.surfaces)

        let treatments: (StrokeStyle, String, String, String) -> ChioTheme.Treatments = ChioTheme.Treatments.init
        #expect(treatments(.single, ">", "#", ".").groupBoxTitlePlacement == .content)
        let replaceTreatments: (StrokeStyle?, String?, String?, String?) -> ChioTheme.Treatments = base.treatments.replacing
        let changedTreatments = replaceTreatments(nil, ">", nil, nil)
        #expect(changedTreatments.groupBoxBorder == .leading)
        #expect(changedTreatments.textFieldBorder == .leading)
        #expect(changedTreatments.selectionMarker == ">")

        let button: (ChioTheme) -> ChioButtonStyle = ChioButtonStyle.init
        let group: (ChioTheme, ChioGroupBoxStyle.TitlePlacement) -> ChioGroupBoxStyle = ChioGroupBoxStyle.init
        #expect(button(base).theme == base)
        #expect(group(base, .border).titlePlacement == .border)
    }

    @Test("Custom surfaces can inherit the base palette or remain independent across replacements")
    func surfaceInheritance() throws {
        let inherited = ChioStyle.default.replacing(colors: ChioStyle.default.colors.replacing(surface: .blue))
        #expect(inherited.surfaces.canvas.resolve(base: inherited.colors.surface) == .blue)
        #expect(inherited.surfaces.input.resolve(base: inherited.colors.surface) == .blue)
        let explicit = inherited.replacing(surfaces: ChioStyle.Surfaces(canvas: .color(.red), input: .color(.green)))
        let changed = explicit.replacing(colors: explicit.colors.replacing(surface: .yellow))
        #expect(changed.surfaces.canvas.resolve(base: changed.colors.surface) == .red)
        #expect(changed.surfaces.input.resolve(base: changed.colors.surface) == .green)
        let restored = changed.replacing(surfaces: changed.surfaces.replacing(input: .base))
        #expect(restored.surfaces.input.resolve(base: restored.colors.surface) == .yellow)
        #expect(explicit.colors.surface == .blue)
        #expect(try JSONDecoder().decode(ChioStyle.Surfaces.self,
                                        from: JSONEncoder().encode(restored.surfaces)) == restored.surfaces)
    }

    @Test("Presets are ordinary composable values with independent presentation choices")
    func customPresentation() {
        let base = ChioStyle.btop
        let custom = base.replacing(
            colors: ChioStyle.light.colors,
            treatments: base.treatments.replacing(groupBoxBorder: .leading,
                                                   groupBoxTitlePlacement: .content, textFieldBorder: [])
        )
        #expect(custom.colors == ChioStyle.light.colors)
        #expect(custom.treatments.groupBoxBorder == .leading)
        #expect(custom.treatments.groupBoxTitlePlacement == .content)
        #expect(custom.treatments.textFieldBorder.isEmpty)
        #expect(base.treatments.groupBoxBorder == .all)
        #expect(base.treatments.groupBoxTitlePlacement == .border)
    }

    @Test("Historical spacing and callable signatures preserve input defaults and new custom values")
    func spacingCompatibility() throws {
        let historical = Data(#"{"horizontalInset":1,"verticalInset":0,"sectionGap":1,"hintGap":2}"#.utf8)
        let decoded = try JSONDecoder().decode(ChioStyle.Spacing.self, from: historical)
        #expect(decoded.inputVerticalInset == 0)
        let construct: (Int, Int, Int, Int) -> ChioTheme.Spacing = ChioTheme.Spacing.init
        #expect(construct(1, 0, 1, 2) == decoded)
        let custom = decoded.replacing(inputVerticalInset: 32)
        let replace: (Int?, Int?, Int?, Int?) -> ChioTheme.Spacing = custom.replacing
        let replaced = replace(0, nil, nil, nil)
        #expect(replaced.horizontalInset == 0)
        #expect(replaced.inputVerticalInset == 32)
        #expect(try JSONDecoder().decode(ChioStyle.Spacing.self,
                                        from: JSONEncoder().encode(custom)) == custom)
    }

    @Test("New spacing roles reject out-of-bounds or null persisted values",
          arguments: ["inputVerticalInset"])
    func spacingDecodingBounds(field: String) throws {
        for invalid in ["-1", "33", "null"] {
            let source = "{\"horizontalInset\":1,\"verticalInset\":0,\"sectionGap\":1,\"hintGap\":2,\"\(field)\":\(invalid)}"
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(ChioStyle.Spacing.self, from: Data(source.utf8))
            }
        }
    }

    @Test("New spacing bounds apply to construction and immutable replacement", arguments: [-1, 33])
    func spacingConstructionBounds(distance: Int) async {
        await #expect(processExitsWith: .failure) { [distance] in
            _ = ChioStyle.Spacing(inputVerticalInset: distance)
        }
        await #expect(processExitsWith: .failure) { [distance] in
            _ = ChioStyle.default.spacing.replacing(inputVerticalInset: distance)
        }
    }
}
