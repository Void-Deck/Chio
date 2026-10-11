@testable import ChioDashboard
import SwiftTUIRuntime
import Testing

@MainActor
@Suite(.serialized)
struct InstrumentsExampleTests {
    @Test("Instrument composition keeps current facts and native controls visible",
          arguments: [CellSize(width: 100, height: 30), CellSize(width: 76, height: 30), CellSize(width: 70, height: 30),
                      CellSize(width: 36, height: 18)], ExampleTheme.allCases)
    func layout(size: CellSize, appearance: ExampleTheme) {
        let rendered = DefaultRenderer().render(
            InstrumentsExampleView(theme: appearance).environment(\.terminalSize, size),
            proposal: ProposedSize(width: size.width, height: size.height))
        let text = rendered.rasterSurface.lines.joined(separator: "\n")
        #expect(rendered.rasterSurface.size == size)
        for expected in ["instruments", "Temperature", "21.4 °C", "Reservoir", "58%", "Response time",
                         "Play", "Next", "Sample", "Step", "^Q quit"] {
            #expect(text.contains(expected))
        }
        let isExpanded = size.width >= 70 && size.height >= 30
        #expect(text.contains("Mean 20.8 °C") == isExpanded)
        #expect(text.contains("Maximum 24.8 °C") == isExpanded)
        let nodes = rendered.semanticSnapshot.accessibilityNodes
        #expect(nodes.contains { $0.role == .button && $0.label == "Play" })
        #expect(nodes.contains { $0.role == .slider && $0.label == "Sample" })
        #expect(nodes.contains { $0.role == .stepper && $0.label == "Step" })
    }

    @Test("Missing readings, source facts, history and native control focus survive layout changes")
    func workflow() async throws {
        let recorder = HostedFrameRecorder()
        let surface = HostedRasterSurface(surfaceSize: CellSize(width: 100, height: 30), appearance: .fallback,
                                          onFrame: { recorder.receive($0) })
        let session = try HostedSceneSession(for: InstrumentsTestApp(), sceneID: "instruments-tests", surface: surface)
        let run = Task { try await session.start() }
        do {
            let initial = try await recorder.wait(description: "native play is initially focused") {
                $0.instrumentFocused("Play") && $0.instrumentContains("Mean 20.8 °C")
            }
            session.send(.key(.tab))
            let focused = try await recorder.wait(after: initial.sequence, description: "native next takes focus") {
                $0.instrumentFocused("Next")
            }
            session.send(.key(.return))
            let next = try await recorder.wait(after: focused.sequence, description: "native action selects the next supplied observation") {
                $0.instrumentContains("22.0 °C") && $0.instrumentFocused("Next")
            }
            session.send(.key(.character("m")))
            let missing = try await recorder.wait(after: next.sequence, description: "missing current retains independent reference captions") {
                $0.instrumentContains("Unavailable") && $0.instrumentContains("Mean 20.8 °C")
                    && $0.instrumentContains("Maximum 24.8 °C")
            }
            session.send(.key(.character("g")))
            let empty = try await recorder.wait(after: missing.sequence, description: "history clears independently of gauge facts") {
                $0.instrumentContains("Response time · empty") && $0.instrumentContains("Mean 20.8 °C")
            }
            session.send(.key(.character("v")))
            session.send(.key(.character("t"), modifiers: .ctrl))
            let themed = try await recorder.wait(after: empty.sequence, description: "theme and dial retain native focus") {
                $0.raster.cells != empty.raster.cells && $0.instrumentFocused("Next")
                    && $0.focusedIdentity == focused.focusedIdentity && $0.instrumentContains("Maximum 24.8 °C")
            }
            surface.updateSurfaceSize(CellSize(width: 36, height: 18))
            session.requestSurfaceRefresh()
            let compact = try await recorder.wait(after: themed.sequence, description: "compact policy omits the whole reference group while retaining controls") {
                $0.raster.size == CellSize(width: 36, height: 18) && $0.instrumentFocused("Next")
                    && $0.focusedIdentity == focused.focusedIdentity && $0.instrumentContains("^Q quit")
                    && !$0.instrumentContains("Mean 20.8 °C")
            }
            session.send(.key(.character("m")))
            let restored = try await recorder.wait(after: compact.sequence, description: "current observation restores without recomputing source facts") {
                $0.instrumentContains("22.0 °C") && $0.instrumentFocused("Next")
            }
            surface.updateSurfaceSize(CellSize(width: 100, height: 30))
            session.requestSurfaceRefresh()
            _ = try await recorder.wait(after: restored.sequence, description: "expanded reference group returns intact") {
                $0.instrumentContains("Mean 20.8 °C") && $0.instrumentContains("Maximum 24.8 °C")
                    && $0.instrumentContains("22.0 °C") && $0.instrumentFocused("Next")
            }
            session.stop()
            #expect(try await run.value == .inputEnded)
        } catch {
            session.stop()
            _ = try? await run.value
            throw error
        }
    }
}

private struct InstrumentsTestApp {
    nonisolated init() {}
}

extension InstrumentsTestApp: App {
    var body: some Scene {
        WindowGroup(id: "instruments-tests") { InstrumentsExampleView() }.exitOnKeys([])
    }
}

private extension SemanticHostFrame {
    func instrumentContains(_ text: String) -> Bool {
        raster.lines.joined(separator: "\n").contains(text)
    }

    func instrumentFocused(_ label: String) -> Bool {
        semantics.accessibilityNodes.contains { $0.identity == focusedIdentity && $0.label == label }
    }
}
