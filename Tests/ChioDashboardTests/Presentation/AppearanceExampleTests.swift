@testable import ChioDashboard
import SwiftTUIRuntime
import Testing

@MainActor
@Suite(.serialized)
struct AppearanceExampleTests {
    @Test("Identical comparison content keeps native controls and narrow navigation hints",
          arguments: [CellSize(width: 100, height: 30), CellSize(width: 36, height: 18),
                      CellSize(width: 36, height: 64)], AppearanceRecipe.allCases)
    func layout(size: CellSize, recipe: AppearanceRecipe) {
        let frame = DefaultRenderer().render(
            AppearanceExampleView(recipe: recipe).environment(\.terminalSize, size),
            proposal: ProposedSize(width: size.width, height: size.height), frameInstant: .zero
        )
        let text = frame.rasterSurface.lines.joined(separator: "\n")
        #expect(frame.rasterSurface.size == size)
        #expect(text.contains("/ appearance"))
        #expect(text.contains("\(recipe.title) · spacing: recipe"))
        for hint in ["^T look", "^D spacing", "^E edit", "^G graphs", "^L list", "^Q quit"] {
            #expect(text.contains(hint))
        }
        #expect(text.contains("Agents"))
        #expect(text.contains("Build Agent"))
        if size.width == 100 {
            for content in ["Run settings", "Instruments", "21.4 °C", "Target 18–24 °C",
                            "58%", "Response time", "Save settings", "Field notes"] {
                #expect(text.contains(content))
            }
            let nodes = frame.semanticSnapshot.accessibilityNodes
            #expect(nodes.contains { $0.role == .textField && $0.label == "Workspace" && $0.control?.value == .text("Field notes") })
            #expect(nodes.contains { $0.role == .toggle && $0.control?.value == .boolean(true) })
            #expect(nodes.contains { $0.role == .stepper && $0.label == "Keep days" })
            #expect(nodes.contains { $0.role == .button && $0.label == "Save settings" })
        }
    }

    @Test("Native search, selected agent and workspace focus survive recipes, spacing and responsive layout")
    func retainedWorkflow() async throws {
        try await withAppearance { session, surface, recorder in
            _ = try await recorder.wait(description: "initial comparison list") {
                $0.appearanceContains("Build Agent") && $0.appearanceContains("Chio · spacing: recipe")
            }
            try await focusAppearanceSearch(session: session, recorder: recorder)
            session.sendInput(Array("Review".utf8))
            let filtered = try await recorder.wait(description: "native search selects the matching review agent") {
                $0.appearanceQuery("Review") && $0.appearanceSelectedReview
            }
            session.send(.key(.return))
            _ = try await recorder.wait(after: filtered.sequence, description: "native search hands focus back to results") {
                $0.appearanceSelectedReview && !$0.appearanceSearchFocused
            }
            session.send(.key(.character("e"), modifiers: .ctrl))
            let editing = try await recorder.wait(description: "edit shortcut reveals and focuses the native workspace field") {
                $0.appearanceWorkspaceFocused && $0.appearanceWorkspace("Field notes")
            }
            session.send([.key(.end), .key(.character("A")), .key(.character("B"))])
            var retained = try await recorder.wait(after: editing.sequence, description: "batched native workspace edits remain in the draft") {
                $0.appearanceWorkspaceFocused && $0.appearanceWorkspace("Field notesAB")
            }
            let workspaceIdentity = retained.focusedIdentity
            for title in ["OpenCode", "btop", "Chio"] {
                session.send(.key(.character("t"), modifiers: .ctrl))
                let changed = try await recorder.wait(after: retained.sequence, description: "\(title) preserves the workspace and search") {
                    $0.appearanceContains("\(title) · spacing: recipe")
                        && $0.appearanceWorkspaceFocused && $0.appearanceWorkspace("Field notesAB")
                        && $0.appearanceQuery("Review")
                }
                #expect(changed.focusedIdentity == workspaceIdentity)
                #expect(changed.raster.cells != retained.raster.cells)
                retained = changed
            }
            for density in ["compact", "roomy", "recipe"] {
                session.send(.key(.character("d"), modifiers: .ctrl))
                retained = try await recorder.wait(after: retained.sequence, description: "\(density) spacing preserves native workspace focus") {
                    $0.appearanceContains("Chio · spacing: \(density)")
                        && $0.appearanceWorkspaceFocused && $0.appearanceWorkspace("Field notesAB")
                        && $0.appearanceQuery("Review")
                }
                #expect(retained.focusedIdentity == workspaceIdentity)
            }
            surface.updateSurfaceSize(CellSize(width: 36, height: 18))
            session.requestSurfaceRefresh()
            let narrow = try await recorder.wait(after: retained.sequence, description: "stacked narrow layout retains focused workspace and query") {
                $0.raster.size == CellSize(width: 36, height: 18)
                    && $0.appearanceWorkspaceFocused && $0.appearanceWorkspace("Field notesAB")
                    && $0.appearanceContains("Field notesAB")
                    && $0.appearanceQuery("Review") && $0.appearanceContains("^Q quit")
            }
            #expect(narrow.focusedIdentity == workspaceIdentity)
            session.send(.key(.character("C")))
            _ = try await recorder.wait(after: narrow.sequence, description: "native typing continues after changing layout") {
                $0.appearanceWorkspace("Field notesABC")
            }
            session.send(.key(.character("l"), modifiers: .ctrl))
            let restoredList = try await recorder.wait(description: "list shortcut reveals the retained matching selection") {
                $0.appearanceSelectedReview && $0.appearanceQuery("Review")
            }
            surface.updateSurfaceSize(CellSize(width: 100, height: 30))
            session.requestSurfaceRefresh()
            _ = try await recorder.wait(after: restoredList.sequence, description: "wide recovery retains both edited workspace and selected agent") {
                $0.raster.size == CellSize(width: 100, height: 30)
                    && $0.appearanceSelectedReview && $0.appearanceWorkspace("Field notesABC")
                    && $0.appearanceQuery("Review")
            }
        }
    }

    @Test("Every recipe exposes settings and instruments through native narrow scrolling", arguments: AppearanceRecipe.allCases)
    func narrowSections(recipe: AppearanceRecipe) async throws {
        try await withAppearance(recipe: recipe, size: CellSize(width: 36, height: 18)) { session, _, recorder in
            let initial = try await recorder.wait(description: "narrow agents and persistent hints") {
                $0.appearanceContains("Build Agent") && $0.appearanceContains("^G graphs")
            }
            session.send(.key(.character("e"), modifiers: .ctrl))
            let settings = try await recorder.wait(after: initial.sequence, description: "native edit shortcut reveals workspace") {
                $0.appearanceWorkspaceFocused && $0.appearanceContains("Field notes")
                    && $0.appearanceContains("^L list")
            }
            session.send(.key(.character("g"), modifiers: .ctrl))
            let graphs = try await recorder.wait(after: settings.sequence, description: "graph shortcut exposes instrument facts") {
                $0.appearanceContains("Instruments") && $0.appearanceContains("21.4 °C")
                    && $0.appearanceContains("Target 18–24 °C") && $0.appearanceContains("^Q quit")
            }
            session.send(.key(.character("l"), modifiers: .ctrl))
            _ = try await recorder.wait(after: graphs.sequence, description: "list shortcut restores agent content") {
                $0.appearanceContains("Agents") && $0.appearanceContains("Build Agent")
                    && $0.appearanceContains("^E edit")
            }
        }
    }
}

private struct AppearanceTestApp {
    let recipe: AppearanceRecipe
    nonisolated init() { recipe = .chio }
    nonisolated init(recipe: AppearanceRecipe) { self.recipe = recipe }
}

extension AppearanceTestApp: App {
    var body: some Scene {
        WindowGroup(id: "appearance-tests") { AppearanceExampleView(recipe: recipe) }.exitOnKeys([])
    }
}

@MainActor
private func withAppearance(
    recipe: AppearanceRecipe = .chio, size: CellSize = CellSize(width: 100, height: 30),
    perform: @MainActor (HostedSceneSession, HostedRasterSurface, HostedFrameRecorder) async throws -> Void
) async throws {
    let recorder = HostedFrameRecorder()
    let surface = HostedRasterSurface(surfaceSize: size, appearance: .fallback, onFrame: { recorder.receive($0) })
    let session = try HostedSceneSession(for: AppearanceTestApp(recipe: recipe), sceneID: "appearance-tests", surface: surface)
    let run = Task { try await session.start() }
    do {
        try await perform(session, surface, recorder)
        session.stop()
        #expect(try await run.value == .inputEnded)
    } catch {
        session.stop()
        _ = await run.result
        throw error
    }
}

@MainActor
private func focusAppearanceSearch(session: HostedSceneSession, recorder: HostedFrameRecorder) async throws {
    var frame = try await recorder.wait(description: "native comparison focus") { $0.focusedIdentity != nil }
    for _ in 0..<12 {
        if frame.appearanceSearchFocused { return }
        session.send(.key(.tab))
        frame = try await recorder.wait(after: frame.sequence, description: "Tab advances to native agent search") { $0.focusedIdentity != nil }
    }
    throw AppearanceFocusError.searchNotReached
}

private enum AppearanceFocusError: Error { case searchNotReached }

private extension SemanticHostFrame {
    func appearanceContains(_ value: String) -> Bool { raster.lines.contains { $0.contains(value) } }
    func appearanceWorkspace(_ value: String) -> Bool {
        semantics.accessibilityNodes.contains { $0.role == .textField && $0.label == "Workspace" && $0.control?.value == .text(value) }
    }
    func appearanceQuery(_ value: String) -> Bool {
        semantics.accessibilityNodes.contains { $0.role == .textField && $0.label != "Workspace" && $0.control?.value == .text(value) }
    }
    var appearanceWorkspaceFocused: Bool {
        semantics.accessibilityNodes.contains { $0.role == .textField && $0.label == "Workspace" && $0.identity == focusedIdentity }
    }
    var appearanceSearchFocused: Bool {
        semantics.accessibilityNodes.contains { $0.role == .textField && $0.label != "Workspace" && $0.identity == focusedIdentity }
    }
    var appearanceSelectedReview: Bool {
        raster.lines.contains { $0.contains("›") && $0.contains("Review Agent") }
    }
}
