import Chio
import SwiftTUIRuntime
import Testing

@MainActor
struct ChioStepperStyleTests {
    @Test("Stepper retains native slots and distinguishes exhausted pointer actions")
    func endpointsAndTheme() throws {
        let custom = ChioTheme.light.replacing(
            colors: ChioTheme.light.colors.replacing(accent: Color(hexRGB: 0x123456)))
        for theme in [ChioTheme.default, .light, .btop, custom] {
            for value in [1, 2, 4] {
                let result = DefaultRenderer().render(
                    Stepper("Speed", value: Binding<Int>.constant(value), in: 1...4)
                        .stepperStyle(ChioStepperStyle()).environment(\.chioTheme, theme),
                    proposal: ProposedSize(width: 24, height: 1))
                let left = value == 1 ? "◁" : "◀"
                let right = value == 4 ? "▷" : "▶"
                #expect(result.rasterSurface.lines[0].contains("Speed \(left) \(value) \(right)"))
                let enabledArrow = value == 4 ? "◀" : "▶"
                let arrow = try #require(result.rasterSurface.cells[0].first { String($0.character) == enabledArrow })
                #expect(arrow.style?.foregroundColor == theme.colors.accent)
                #expect(result.semanticSnapshot.focusRegions.count == 1)
                let nodes = result.semanticSnapshot.accessibilityNodes.filter { $0.role == .stepper }
                #expect(nodes.count == 1)
                #expect(nodes.first?.label == "Speed")
            }
        }
        let disabled = DefaultRenderer().render(
            Stepper("Speed", value: Binding<Int>.constant(2), in: 1...4)
                .disabled(true).chioTheme(.btop), proposal: ProposedSize(width: 24, height: 1))
        #expect(disabled.semanticSnapshot.focusRegions.isEmpty)
        #expect(disabled.semanticSnapshot.accessibilityNodes.first { $0.role == .stepper }?.isEnabled == false)
    }
}
