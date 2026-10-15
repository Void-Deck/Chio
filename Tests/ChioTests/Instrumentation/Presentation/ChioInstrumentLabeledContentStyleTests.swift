import Chio
import Foundation
import SwiftTUIRuntime
import Testing

@MainActor
@Suite(.serialized)
struct ChioInstrumentLabeledContentStyleTests {
    @Test("Instrument hierarchy inherits the nearest theme without formatting authored facts")
    func themeHierarchy() {
        let custom = ChioStyle.default.replacing(
            colors: ChioStyle.default.colors.replacing(accent: Color(hexRGB: 0x123456)))
        for theme in [ChioStyle.default, .light, .btop, custom] {
            let reading = LabeledContent("Temperature", value: "21.4 °C")
                .labeledContentStyle(.instrument).environment(\.chioStyle, theme)
            let result = DefaultRenderer().render(reading)
            #expect(DefaultRenderer().render(reading).rasterSurface == result.rasterSurface)
            #expect(result.rasterSurface.lines.map { $0.trimmingCharacters(in: .whitespaces) }
                    == ["Temperature", "21.4 °C"])
            let rows = result.rasterSurface.cells
            #expect(rows[0].filter { $0.character != " " }.allSatisfy {
                $0.style?.foregroundColor == theme.colors.mutedText
            })
            #expect(rows[1].filter { $0.character != " " }.allSatisfy {
                $0.style?.foregroundColor == theme.colors.accent
            })
            #expect(result.semanticSnapshot.focusRegions.isEmpty)
            let native = DefaultRenderer().render(
                LabeledContent("Temperature", value: "21.4 °C").labeledContentStyle(.stacked))
            #expect(result.semanticSnapshot.accessibilityNodes.compactMap(\.label)
                    == native.semanticSnapshot.accessibilityNodes.compactMap(\.label))
        }
    }

    @Test("Custom content, missing readings and Unicode survive bounded allocations")
    func contentAndAllocations() {
        for width in [0, 1, 6, 24, 48] {
            for height in [0, 1, 2, 5] {
                let result = DefaultRenderer().render(
                    LabeledContent("温度") {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Unavailable").foregroundStyle(.red)
                            Text("Recorded maximum: 0 °C")
                        }
                    }.labeledContentStyle(.instrument)
                        .frame(width: width, height: height, alignment: .topLeading).clipped(),
                    proposal: ProposedSize(width: width, height: height))
                let isEmptyAllocation = width == 0 || height == 0
                if isEmptyAllocation {
                    // Native raster surfaces canonicalize an empty axis to 0×0.
                    #expect(result.rasterSurface.size == CellSize(width: 0, height: 0))
                    #expect(result.rasterSurface.cells.flatMap { $0 }.isEmpty)
                } else {
                    #expect(result.rasterSurface.size == CellSize(width: width, height: height))
                }
                #expect(result.semanticSnapshot.focusRegions.isEmpty)
                if width == 48 && height == 5 {
                    #expect(result.rasterSurface.lines.joined().contains("Recorded maximum: 0 °C"))
                    let unavailable = result.rasterSurface.cells[1].filter { $0.character != " " }
                    #expect(unavailable.allSatisfy { $0.style?.foregroundColor == .red })
                }
            }
        }
    }

    @Test("Theme installation keeps ordinary labelled facts automatic and nearest styles scoped")
    func optIn() {
        let result = DefaultRenderer().render(
            VStack(alignment: .leading, spacing: 0) {
                LabeledContent("Name", value: "Ada")
                LabeledContent("Speed", value: "12").labeledContentStyle(.instrument)
                LabeledContent("Row", value: "3").labeledContentStyle(.automatic)
            }.style(.btop), proposal: ProposedSize(width: 30, height: 5))
        #expect(result.rasterSurface.lines.contains { $0.contains("Name") && $0.contains("Ada") })
        #expect(!result.rasterSurface.lines.contains { $0.contains("Speed") && $0.contains("12") })
        #expect(result.rasterSurface.lines.contains { $0.contains("Row") && $0.contains("3") })
    }

    @Test("Authored label and content each keep one native action and retained child state")
    func retainedSlots() async throws {
        let recorder = HostedFrameRecorder()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 40, height: 10), appearance: .fallback,
                                          onFrame: { recorder.receive($0) })
        let session = try HostedSceneSession(for: InstrumentSlotApp(), sceneID: "instrument-slots", surface: surface)
        let run = Task { try await session.start() }
        do {
            let initial = try await recorder.wait(description: "authored label focus") { $0.instrumentSlotFocused("Heading=0") }
            #expect(initial.semantics.focusRegions.count == 2)
            session.send(.key(.return))
            let heading = try await recorder.wait(after: initial.sequence, description: "one label activation") {
                $0.instrumentSlotFocused("Heading=1")
            }
            session.send(.key(.tab))
            let reading = try await recorder.wait(after: heading.sequence, description: "authored content focus") {
                $0.instrumentSlotFocused("Reading=0")
            }
            session.send(.key(.return))
            let activated = try await recorder.wait(after: reading.sequence, description: "one content activation") {
                $0.instrumentSlotFocused("Reading=1")
            }
            session.send(.key(.character("t"), modifiers: .ctrl))
            let themed = try await recorder.wait(after: activated.sequence, description: "theme preserves both slots") {
                $0.raster.lines.joined().contains("Theme=light") && $0.instrumentSlotFocused("Reading=1")
            }
            surface.updateSurfaceSize(CellSize(width: 20, height: 10))
            session.requestSurfaceRefresh()
            let resized = try await recorder.wait(after: themed.sequence, description: "resize preserves child state") {
                $0.raster.size.width == 20 && $0.instrumentSlotFocused("Reading=1")
            }
            #expect(resized.focusedIdentity == reading.focusedIdentity)
            #expect(resized.semantics.accessibilityNodes.filter { $0.isInstrumentSlotAction("Heading=1") }.count == 1)
            #expect(resized.semantics.accessibilityNodes.filter { $0.isInstrumentSlotAction("Reading=1") }.count == 1)
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = await run.result
            throw error
        }
    }
}

private struct InstrumentSlotApp {
    nonisolated init() {}
}

extension InstrumentSlotApp: App {
    var body: some Scene {
        WindowGroup(id: "instrument-slots") { InstrumentSlotView() }.exitOnKeys([])
    }
}

@MainActor
private struct InstrumentSlotView {
    @State private var isLight = false
}

extension InstrumentSlotView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LabeledContent {
                InstrumentSlotCounter(title: "Reading").id("reading")
            } label: {
                InstrumentSlotCounter(title: "Heading").id("heading")
            }
            .labeledContentStyle(.instrument)
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

@MainActor
private struct InstrumentSlotCounter {
    let title: String
    @State private var count = 0
}

extension InstrumentSlotCounter: View {
    var body: some View { Button("\(title)=\(count)") { count += 1 } }
}

private extension SemanticHostFrame {
    func instrumentSlotFocused(_ label: String) -> Bool {
        semantics.accessibilityNodes.contains { $0.identity == focusedIdentity && $0.isInstrumentSlotAction(label) }
    }
}

private extension AccessibilityNode {
    func isInstrumentSlotAction(_ title: String) -> Bool {
        let isAuthoredButton = role == .button && label == title
        let supportsActivation = control?.actions.contains(.activate) == true
        return isAuthoredButton && supportsActivation
    }
}
