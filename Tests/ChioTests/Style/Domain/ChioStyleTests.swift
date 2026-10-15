import Chio
import Foundation
import SwiftTUIRuntime
import Testing

struct ChioStyleTests {
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

    @Test("Spacing defaults and immutable replacement preserve independent roles")
    func spacingValues() throws {
        let historical = Data(#"{"horizontalInset":1,"verticalInset":0,"sectionGap":1,"hintGap":2}"#.utf8)
        let decoded = try JSONDecoder().decode(ChioStyle.Spacing.self, from: historical)
        #expect(decoded.inputVerticalInset == 0)
        #expect(decoded.listRowVerticalInset == 0)
        let custom = decoded.replacing(inputVerticalInset: 32, listRowVerticalInset: 32)
        let replaced = custom.replacing(horizontalInset: 0, listRowVerticalInset: 1)
        #expect(replaced.horizontalInset == 0)
        #expect(replaced.inputVerticalInset == 32)
        #expect(replaced.listRowVerticalInset == 1)
        #expect(custom.horizontalInset == 1)
        #expect(custom.listRowVerticalInset == 32)
        #expect(decoded.listRowVerticalInset == 0)
        #expect(try JSONDecoder().decode(ChioStyle.Spacing.self,
                                        from: JSONEncoder().encode(custom)) == custom)
        #expect(Set([custom, replaced]).count == 2)
        #expect(ChioStyle.default.spacing.listRowVerticalInset == 0)
        #expect(ChioStyle.light.spacing.listRowVerticalInset == 0)
        #expect(ChioStyle.btop.spacing.listRowVerticalInset == 0)
        #expect(ChioStyle.opencode.spacing.listRowVerticalInset == 1)
    }

    @Test("New spacing roles reject out-of-bounds or null persisted values",
          arguments: ["inputVerticalInset", "listRowVerticalInset"])
    func spacingDecodingBounds(field: String) throws {
        for invalid in ["-1", "33", "null", "1.5", "\"1\""] {
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
        await #expect(processExitsWith: .failure) { [distance] in
            _ = ChioStyle.Spacing(listRowVerticalInset: distance)
        }
        await #expect(processExitsWith: .failure) { [distance] in
            _ = ChioStyle.default.spacing.replacing(listRowVerticalInset: distance)
        }
    }
}
