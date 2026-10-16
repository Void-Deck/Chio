import Chio
import SwiftTUIRuntime
import Testing

@MainActor
@Suite(.serialized)
struct ChioSliderStyleTests {
    @Test("Slider preserves native label, formatted value, endpoint geometry and theme inheritance")
    func rasterAndSemantics() throws {
        let custom = ChioStyle.default.replacing(
            colors: ChioStyle.default.colors.replacing(accent: Color(hexRGB: 0x123456)))
        for theme in [ChioStyle.default, .light, .btop, custom] {
            for value in [0, 3, 7] {
                let result = DefaultRenderer().render(
                    Slider("Sample", value: Binding<Int>.constant(value), in: 0...7)
                        .sliderStyle(ChioSliderStyle()).environment(\.chioStyle, theme),
                    proposal: ProposedSize(width: 32, height: 1))
                let expectedTrack = String(repeating: "━", count: value) + "●"
                    + String(repeating: "─", count: 7 - value)
                #expect(result.rasterSurface.lines[0].contains("Sample \(expectedTrack) \(value)"))
                let marker = try #require(result.rasterSurface.cells[0].first { $0.character == "●" })
                #expect(marker.style?.foregroundColor == theme.colors.accent)
                let node = try #require(result.semanticSnapshot.accessibilityNodes.first { $0.role == .slider })
                #expect(node.label == "Sample")
                #expect(result.semanticSnapshot.accessibilityNodes.filter { $0.role == .slider }.count == 1)
                #expect(result.semanticSnapshot.focusRegions.count == 1)
            }
        }
        let disabled = DefaultRenderer().render(
            Slider("Sample", value: Binding<Int>.constant(0), in: 0...7)
                .disabled(true).style(.btop), proposal: ProposedSize(width: 32, height: 1))
        #expect(disabled.semanticSnapshot.focusRegions.isEmpty)
        #expect(disabled.semanticSnapshot.accessibilityNodes.first { $0.role == .slider }?.isEnabled == false)
    }

    @Test("Themed numeric controls retain single native routes, focus, bounds and state across theme/resize",
          arguments: [false, true])
    func nativeInteraction(suppressed: Bool) async throws {
        let recorder = HostedFrameRecorder()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 40, height: 8), appearance: .fallback,
                                          onFrame: { recorder.receive($0) })
        let session = try HostedSceneSession(for: NumericStyleApp(suppressed: suppressed), sceneID: "numeric-styles", surface: surface)
        let run = Task { try await session.start() }
        do {
            let initial = try await recorder.wait(description: "native slider focus") { $0.numericFocused("Sample") }
            #expect(initial.semantics.focusRegions.count == 2)
            session.requestSurfaceRefresh()
            let focused = try await recorder.wait(after: initial.sequence, description: "native focus appears in slider chrome") {
                $0.numericFocused("Sample") && $0.raster.lines[0].hasPrefix(suppressed ? " " : "▌")
            }
            session.send(.key(.arrowRight))
            let adjusted = try await recorder.wait(after: focused.sequence, description: "one native slider increment") {
                $0.numericStatus("Index=1 Speed=1")
            }
            let trackRow = try #require(adjusted.raster.cells.firstIndex { $0.contains { $0.character == "●" } })
            let trackStart = try #require(adjusted.raster.cells[trackRow].firstIndex { $0.character == "━" })
            let trackPoint = CellPoint(x: trackStart + 3, y: trackRow)
            session.send([
                .mouse(MouseEvent(kind: .down(.primary), location: .cellFallback(trackPoint))),
                .mouse(MouseEvent(kind: .up(.primary), location: .cellFallback(trackPoint))),
            ])
            let clicked = try await recorder.wait(after: adjusted.sequence, description: "routed slider track selects its native fraction") {
                $0.numericStatus("Index=3 Speed=1")
            }
            session.send(.key(.tab))
            let stepper = try await recorder.wait(after: clicked.sequence, description: "Tab skips disabled control") {
                $0.numericFocused("Speed")
            }
            let speedRow = try #require(stepper.raster.cells.firstIndex { $0.contains { $0.character == "▶" } })
            let incrementX = try #require(stepper.raster.cells[speedRow].firstIndex { $0.character == "▶" })
            let incrementPoint = CellPoint(x: incrementX, y: speedRow)
            session.send([
                .mouse(MouseEvent(kind: .down(.primary), location: .cellFallback(incrementPoint))),
                .mouse(MouseEvent(kind: .up(.primary), location: .cellFallback(incrementPoint))),
            ])
            let incremented = try await recorder.wait(after: stepper.sequence, description: "one routed stepper increment") {
                $0.numericStatus("Index=3 Speed=2")
            }
            let decrementX = try #require(incremented.raster.cells[speedRow].firstIndex { $0.character == "◀" })
            let decrementPoint = CellPoint(x: decrementX, y: speedRow)
            session.send([
                .mouse(MouseEvent(kind: .down(.primary), location: .cellFallback(decrementPoint))),
                .mouse(MouseEvent(kind: .up(.primary), location: .cellFallback(decrementPoint))),
            ])
            let decremented = try await recorder.wait(after: incremented.sequence, description: "one routed stepper decrement") {
                $0.numericStatus("Index=3 Speed=1")
            }
            session.send([.key(.arrowRight), .key(.arrowRight), .key(.arrowRight), .key(.arrowRight)])
            let bounded = try await recorder.wait(after: decremented.sequence, description: "batched native input clamps at upper bound") {
                $0.numericStatus("Index=3 Speed=4")
            }
            session.send(.key(.character("t"), modifiers: .ctrl))
            let themed = try await recorder.wait(after: bounded.sequence, description: "theme keeps native focus and values") {
                $0.numericFocused("Speed") && $0.numericStatus("Theme=light") && $0.numericStatus("Index=3 Speed=4")
            }
            let labelCell = try #require(themed.raster.cells[speedRow].first { $0.character == "S" })
            #expect(labelCell.style?.foregroundColor == ChioStyle.light.colors.secondaryText)
            surface.updateSurfaceSize(CellSize(width: 26, height: 8))
            session.requestSurfaceRefresh()
            let resized = try await recorder.wait(after: themed.sequence, description: "resize keeps native control identity") {
                $0.raster.size.width == 26 && $0.numericFocused("Speed")
            }
            #expect(resized.focusedIdentity == stepper.focusedIdentity)
            session.send(.key(.arrowLeft))
            let edited = try await recorder.wait(after: resized.sequence, description: "editing continues after resize") {
                $0.numericStatus("Index=3 Speed=3")
            }
            let speedTarget = try #require(edited.semantics.accessibilityNodes.first { $0.role == .stepper }?.actionTarget)
            session.send(.accessibility(AccessibilityActionRequest(target: speedTarget, action: .decrement)))
            let accessible = try await recorder.wait(after: edited.sequence, description: "native accessibility stepper action changes the value once") {
                $0.numericStatus("Index=3 Speed=2")
            }
            let sampleTarget = try #require(accessible.semantics.accessibilityNodes.first { $0.label == "Sample" }?.actionTarget)
            session.send(.accessibility(AccessibilityActionRequest(target: sampleTarget, action: .increment)))
            _ = try await recorder.wait(after: accessible.sequence, description: "native accessibility slider action changes the value once") {
                $0.numericStatus("Index=4 Speed=2")
            }
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }
}

private struct NumericStyleApp {
    let suppressed: Bool
    nonisolated init() { suppressed = false }
    nonisolated init(suppressed: Bool) { self.suppressed = suppressed }
}

extension NumericStyleApp: App {
    var body: some Scene {
        WindowGroup(id: "numeric-styles") { NumericStyleView(suppressed: suppressed) }.exitOnKeys([])
    }
}

@MainActor
private struct NumericStyleView {
    let suppressed: Bool
    @State private var index = 0
    @State private var speed = 1
    @State private var isLight = false
}

extension NumericStyleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Slider("Sample", value: $index, in: 0...7).focusEffectDisabled(suppressed)
            Slider("Unavailable", value: Binding<Int>.constant(0), in: 0...7).disabled(true)
            Stepper("Speed", value: $speed, in: 1...4).focusEffectDisabled(suppressed)
            Text("Index=\(index) Speed=\(speed)")
            Text(isLight ? "Theme=light" : "Theme=default")
        }
        .style(isLight ? .light : .default)
        .onKeyPress { press in
            switch press {
            case KeyPress(.character("t"), modifiers: .ctrl): isLight.toggle(); return .handled
            default: return .ignored
            }
        }
    }
}

private extension SemanticHostFrame {
    func numericFocused(_ label: String) -> Bool {
        semantics.accessibilityNodes.contains { $0.identity == focusedIdentity && $0.label == label }
    }

    func numericStatus(_ text: String) -> Bool { raster.lines.contains { $0.contains(text) } }
}
