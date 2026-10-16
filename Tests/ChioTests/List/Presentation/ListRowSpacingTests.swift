import Chio
import SwiftTUIRuntime
import Testing

@MainActor
@Suite(.serialized)
struct ListRowSpacingTests {
    @Test("Authored native rows place labels at independent compact and padded lines", arguments: [0, 1, 32])
    func nativeIntrinsicGeometry(inset: Int) {
        let theme = rowSpacingStyle(inset)
        let surface = DefaultRenderer().render(
            List(Array(RowSpacingItem.fixtures.prefix(3))) { item in
                Text(item.title).padding(.vertical, theme.spacing.listRowVerticalInset)
            }.style(theme),
            proposal: ProposedViewSize(width: 32, height: nil)
        ).rasterSurface
        let expectedLines: [Int]
        let expectedHeight: Int
        switch inset {
        case 0: expectedLines = [0, 1, 2]; expectedHeight = 3
        case 1: expectedLines = [1, 4, 7]; expectedHeight = 9
        case 32: expectedLines = [32, 97, 162]; expectedHeight = 195
        default: preconditionFailure("Unspecified geometry fixture")
        }
        #expect(surface.size.height == expectedHeight)
        for (id, expectedLine) in expectedLines.enumerated() {
            #expect(surface.lines.indices.filter { surface.lines[$0].contains(RowSpacingItem(id: id).title) } == [expectedLine])
        }
    }

    @Test("Maximum row inset remains clipped to the composed list allocation", arguments: [false, true])
    func maximumInsetClipping(checklist: Bool) {
        let surface = DefaultRenderer().render(
            RowSpacingView(checklist: checklist, shape: .compact, initialInset: 32, pointerFixture: true),
            proposal: ProposedViewSize(width: 32, height: 18)
        ).rasterSurface
        #expect(surface.size.height == 18)
        #expect(!surface.lines.contains { $0.contains("Entry 00") || $0.contains("Entry 01") })
        #expect(surface.lines.contains { $0.contains("2 of 2 items") })
        #expect(surface.lines.contains { $0.contains("Inset=32") })
    }

    @Test("Composed lists pad each complete authored row including its marker", arguments: [false, true], [0, 1])
    func composedGeometry(checklist: Bool, inset: Int) throws {
        let rendered = DefaultRenderer().render(
            RowSpacingView(checklist: checklist, shape: .compact, initialInset: inset, pointerFixture: true),
            proposal: ProposedViewSize(width: 32, height: 18)
        )
        let lines = rendered.rasterSurface.lines
        let first = try #require(lines.firstIndex { $0.contains("Entry 00") })
        // The bordered editor and section gap consume four lines before the list.
        #expect(first == (inset == 0 ? 4 : 5))
        #expect(lines.indices.filter { lines[$0].contains("Entry 01") } == [inset == 0 ? 5 : 8])
        if checklist {
            #expect(lines[first].contains("[x]"))
        } else {
            #expect(lines[first].contains(ChioStyle.default.treatments.selectionMarker))
        }
        if inset == 1 {
            let cells = rendered.rasterSurface.cells
            let labelX = try #require(cells[first].firstIndex { $0.character == "E" })
            #expect(cells[first - 1][labelX].style?.backgroundColor == ChioStyle.default.colors.selectedSurface)
            #expect(cells[first + 1][labelX].style?.backgroundColor == ChioStyle.default.colors.selectedSurface)
        }
    }

    @Test("Scrolled mixed and wrapped rows retain identity, selection and membership through inherited spacing changes",
          arguments: [false, true], [RowSpacingShape.mixed, .wrapped])
    fileprivate func scrolledStyleChange(checklist: Bool, shape: RowSpacingShape) async throws {
        try await withRowSpacingScene(checklist: checklist, shape: shape) { session, recorder in
            var previous = try await enterRowSpacingResults(checklist: checklist, session: session, recorder: recorder)
            for id in 1...7 {
                session.send(.key(.arrowDown))
                previous = try await recorder.wait(after: previous.sequence, description: "scroll to stable row \(id)") {
                    $0.spacingRowFocused(id)
                }
            }
            #expect(!previous.spacingContains("Entry 00"))
            if checklist {
                session.send(.key(.space))
                previous = try await recorder.wait(after: previous.sequence, description: "check visible ID 7 while retaining offscreen ID 0") {
                    $0.spacingContains("Checked=0,7") && $0.spacingRowFocused(7)
                }
            }
            let identity = previous.focusedIdentity
            for inset in [1, 0] {
                session.send(.key(.character("t"), modifiers: .ctrl))
                previous = try await recorder.wait(after: previous.sequence, description: "root spacing \(inset) retains scrolled ID 7") {
                    $0.spacingContains("Inset=\(inset)") && $0.spacingRowFocused(7)
                }
                #expect(previous.focusedIdentity == identity)
                #expect(previous.spacingContains(checklist ? "Checked=0,7" : "Selected=7"))
                #expect(previous.spacingContains("Query=-"))
            }
            session.send(.key(.return))
            previous = try await recorder.wait(after: previous.sequence, description: "Return acts on retained ID 7 exactly once") {
                $0.spacingContains(checklist ? "Checked=0 " : "Activated=7 Count=1")
            }
            #expect(previous.spacingRowFocused(7))
            session.send(.key(.character("/")))
            previous = try await recorder.wait(after: previous.sequence, description: "slash transfers to native search after spacing changes") {
                $0.spacingSearchFocused
            }
            session.sendInput(Array("11".utf8))
            previous = try await recorder.wait(after: previous.sequence, description: "filter after spacing changes retains bound state") {
                $0.spacingContains("Query=11") && $0.spacingContains("1 of 12 items")
            }
            #expect(previous.spacingContains(checklist ? "Checked=0 " : "Activated=7 Count=1"))
            session.send(.key(.return))
            previous = try await recorder.wait(after: previous.sequence, description: "native search Return hands off to filtered results") {
                $0.spacingResultsFocused
            }
            if !previous.spacingRowFocused(11) {
                session.send(.key(.tab))
                previous = try await recorder.wait(after: previous.sequence, description: "native Tab enters filtered stable row 11") {
                    $0.spacingRowFocused(11)
                }
            }
            session.send(.key(.return))
            let activated = try await recorder.wait(after: previous.sequence, description: "filtered Return acts once on ID 11") {
                $0.spacingContains(checklist ? "Checked=0,11" : "Activated=11 Count=2")
            }
            #expect(activated.spacingRowFocused(11))
        }
    }

    @Test("Native pointer routing includes row padding and rejects disabled checklist membership", arguments: [false, true])
    func paddedPointer(checklist: Bool) async throws {
        try await withRowSpacingScene(checklist: checklist, initialInset: 1, pointerFixture: true) { session, recorder in
            var previous = try await enterRowSpacingResults(checklist: checklist, session: session, recorder: recorder)
            let firstLine = try #require(previous.raster.lines.firstIndex { $0.contains("Entry 00") })
            let focused = try #require(previous.semantics.focusRegions.first { $0.identity == previous.focusedIdentity })
            #expect(focused.rect.origin.y == firstLine - 1)
            let targetLine: Int
            if checklist {
                targetLine = firstLine
            } else {
                targetLine = try #require(previous.raster.lines.firstIndex { $0.contains("Entry 01") })
            }
            let point = CellPoint(x: focused.rect.origin.x + 4, y: targetLine - 1)
            session.send([
                .mouse(MouseEvent(kind: .down(.primary), location: .cellFallback(point))),
                .mouse(MouseEvent(kind: .up(.primary), location: .cellFallback(point))),
                .key(.character("b"), modifiers: .ctrl),
            ])
            previous = try await recorder.wait(after: previous.sequence, description: "native padding click is processed") {
                $0.spacingContains("Barrier=1")
            }
            #expect(previous.spacingRowFocused(checklist ? 0 : 1))
            if checklist {
                #expect(previous.spacingContains("Checked=-"))
                let disabledLine = try #require(previous.raster.lines.firstIndex { $0.contains("Entry 01") })
                let disabledPoint = CellPoint(x: point.x, y: disabledLine - 1)
                session.send([
                    .mouse(MouseEvent(kind: .down(.primary), location: .cellFallback(disabledPoint))),
                    .mouse(MouseEvent(kind: .up(.primary), location: .cellFallback(disabledPoint))),
                    .key(.return),
                    .key(.character("b"), modifiers: .ctrl),
                ])
                let rejected = try await recorder.wait(after: previous.sequence, description: "disabled padded row rejects pointer and Return membership") {
                    $0.spacingContains("Barrier=2")
                }
                #expect(rejected.spacingContains("Checked=-"))
                #expect(rejected.spacingContains("Unavailable"))
                #expect(rejected.spacingRowFocused(1))
            } else {
                #expect(previous.spacingContains("Selected=1"))
                #expect(previous.spacingContains("Activated=1 Count=1"))
                session.send(.key(.return))
                let activated = try await recorder.wait(after: previous.sequence, description: "Return activates the row reached through its padding") {
                    $0.spacingContains("Activated=1 Count=2")
                }
                #expect(activated.spacingRowFocused(1))
            }
        }
    }

    @Test("Adjacent padded bands keep their native row targets after scrolling", arguments: [false, true])
    func scrolledPaddingPointer(checklist: Bool) async throws {
        try await withRowSpacingScene(checklist: checklist, initialInset: 1) { session, recorder in
            var previous = try await enterRowSpacingResults(checklist: checklist, session: session, recorder: recorder)
            for id in 1...8 {
                session.send(.key(.arrowDown))
                previous = try await recorder.wait(after: previous.sequence, description: "padded native scroll to ID \(id)") {
                    $0.spacingRowFocused(id)
                }
            }
            #expect(!previous.spacingContains("Entry 00"))
            let adjacentIDs = try #require([(7, 8), (8, 9)].first { first, second in
                previous.spacingContains(RowSpacingItem(id: first).title) && previous.spacingContains(RowSpacingItem(id: second).title)
            }, "\(previous.raster.lines.joined(separator: "\n"))")
            let precedingLabel = try #require(previous.raster.lines.firstIndex { $0.contains(RowSpacingItem(id: adjacentIDs.0).title) })
            let targetLabel = try #require(previous.raster.lines.firstIndex { $0.contains(RowSpacingItem(id: adjacentIDs.1).title) })
            #expect(targetLabel - precedingLabel == 3)
            let focused = try #require(previous.semantics.focusRegions.first { $0.identity == previous.focusedIdentity })
            let x = focused.rect.origin.x + 4
            for (id, y, barrier) in [(adjacentIDs.0, precedingLabel + 1, 1), (adjacentIDs.1, targetLabel - 1, 2)] {
                session.send([
                    .mouse(MouseEvent(kind: .down(.primary), location: .cellFallback(CellPoint(x: x, y: y)))),
                    .mouse(MouseEvent(kind: .up(.primary), location: .cellFallback(CellPoint(x: x, y: y)))),
                    .key(.character("b"), modifiers: .ctrl),
                ])
                previous = try await recorder.wait(after: previous.sequence, description: "adjacent padding band dispatches to stable ID \(id)") {
                    $0.spacingContains("Barrier=\(barrier)")
                }
                #expect(previous.spacingRowFocused(id))
                if checklist {
                    let expectedMembership = barrier == 1 ? "Checked=0,\(adjacentIDs.0) " : "Checked=0,\(adjacentIDs.0),\(adjacentIDs.1) "
                    #expect(previous.spacingContains(expectedMembership))
                } else {
                    #expect(previous.spacingContains("Selected=\(id)"))
                    #expect(previous.spacingContains("Activated=\(id) Count=\(barrier)"))
                }
            }
        }
    }
}

private func rowSpacingStyle(_ inset: Int) -> ChioStyle {
    ChioStyle.default.replacing(spacing: ChioStyle.default.spacing.replacing(listRowVerticalInset: inset))
}

private enum RowSpacingShape {
    case compact
    case mixed
    case wrapped
}

extension RowSpacingShape: Sendable {}

private struct RowSpacingItem {
    let id: Int
    var title: String { "Entry \(id < 10 ? "0" : "")\(id)" }
    static let fixtures = (0..<12).map { RowSpacingItem(id: $0) }
}

extension RowSpacingItem: Identifiable {}
extension RowSpacingItem: Sendable {}

private struct RowSpacingApp {
    let checklist: Bool
    let shape: RowSpacingShape
    let initialInset: Int
    let pointerFixture: Bool

    nonisolated init() {
        checklist = false
        shape = .compact
        initialInset = 0
        pointerFixture = false
    }

    nonisolated init(checklist: Bool, shape: RowSpacingShape, initialInset: Int, pointerFixture: Bool) {
        self.checklist = checklist
        self.shape = shape
        self.initialInset = initialInset
        self.pointerFixture = pointerFixture
    }
}

extension RowSpacingApp: App {
    var body: some Scene {
        WindowGroup(id: "row-spacing") {
            RowSpacingView(checklist: checklist, shape: shape, initialInset: initialInset, pointerFixture: pointerFixture)
        }.exitOnKeys([])
    }
}

@MainActor
private struct RowSpacingView {
    let checklist: Bool
    let shape: RowSpacingShape
    let initialInset: Int
    let pointerFixture: Bool
    @State private var usesAlternateInset = false
    @State private var selected: Int? = 0
    @State private var checked: Set<Int> = [0]
    @State private var query = ""
    @State private var activated: Int?
    @State private var activationCount = 0
    @State private var barrier = 0

    private var inset: Int { usesAlternateInset ? 1 - initialInset : initialInset }
    private var rows: [RowSpacingItem] { pointerFixture ? Array(RowSpacingItem.fixtures.prefix(2)) : RowSpacingItem.fixtures }

    @ViewBuilder
    private func content(_ item: RowSpacingItem) -> some View {
        switch shape {
        case .compact: Text(item.title)
        case .mixed:
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                ForEach(0..<(item.id % 3), id: \.self) { line in Text("Detail \(item.id):\(line)") }
            }
        case .wrapped: Text("\(item.title) a longer authored label that wraps inside the list")
        }
    }
}

extension RowSpacingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if checklist {
                    SearchableChecklist(rows, selection: $checked, query: $query, searchText: \.title,
                                        isEnabled: { !pointerFixture || $0.id != 1 }) { item in content(item) }
                } else {
                    SearchableList(rows, selection: $selected, query: $query, searchText: \.title) { item in content(item) }
                        .onActivate { item in activated = item.id; activationCount += 1 }
                }
            }.frame(height: 14, alignment: .topLeading)
            Text("Selected=\(selected.map { String($0) } ?? "-") Checked=\(checked.isEmpty ? "-" : checked.sorted().map { String($0) }.joined(separator: ",")) ")
            Text("Activated=\(activated.map { String($0) } ?? "-") Count=\(activationCount)")
            Text("Inset=\(inset) Query=\(query.isEmpty ? "-" : query) Barrier=\(barrier)")
        }
        .style(rowSpacingStyle(inset))
        .onKeyPress { press in
            switch press {
            case KeyPress(.character("t"), modifiers: .ctrl): usesAlternateInset.toggle(); return .handled
            case KeyPress(.character("b"), modifiers: .ctrl): barrier += 1; return .handled
            default: return .ignored
            }
        }
    }
}

@MainActor
private func withRowSpacingScene(
    checklist: Bool, shape: RowSpacingShape = .compact, initialInset: Int = 0, pointerFixture: Bool = false,
    perform: @MainActor (HostedSceneSession, HostedFrameRecorder) async throws -> Void
) async throws {
    let recorder = HostedFrameRecorder()
    let surface = HostedRasterSurface(surfaceSize: CellSize(width: 32, height: 18), appearance: .fallback,
                                      onFrame: { recorder.receive($0) })
    let app = RowSpacingApp(checklist: checklist, shape: shape, initialInset: initialInset, pointerFixture: pointerFixture)
    let session = try HostedSceneSession(for: app, sceneID: "row-spacing", surface: surface)
    let run = Task { try await session.start() }
    do {
        try await perform(session, recorder)
        session.stop()
        #expect(try await run.value == .inputEnded)
    } catch {
        session.stop()
        _ = await run.result
        throw error
    }
}

@MainActor
private func enterRowSpacingResults(
    checklist: Bool, session: HostedSceneSession, recorder: HostedFrameRecorder
) async throws -> SemanticHostFrame {
    if checklist {
        let search = try await recorder.wait(description: "initial native checklist search focus") { $0.spacingSearchFocused }
        session.send(.key(.return))
        return try await recorder.wait(after: search.sequence, description: "native Return hands off to first padded or compact row") {
            $0.spacingRowFocused(0)
        }
    }
    let results = try await recorder.wait(description: "initial native searchable list results focus") { $0.spacingResultsFocused }
    if results.spacingRowFocused(0) { return results }
    session.send(.key(.tab))
    return try await recorder.wait(after: results.sequence, description: "native Tab enters first searchable list row") {
        $0.spacingRowFocused(0)
    }
}

private extension SemanticHostFrame {
    var spacingSearchFocused: Bool {
        semantics.accessibilityNodes.contains { $0.identity == focusedIdentity && $0.role == .textField }
    }

    var spacingResultsFocused: Bool {
        !spacingSearchFocused && semantics.focusRegions.contains { $0.identity == focusedIdentity }
    }

    func spacingContains(_ text: String) -> Bool { raster.lines.contains { $0.contains(text) } }

    func spacingRowFocused(_ id: Int) -> Bool {
        let title = RowSpacingItem(id: id).title
        guard let line = raster.lines.firstIndex(where: { $0.contains(title) }),
              let region = semantics.focusRegions.first(where: { $0.identity == focusedIdentity }) else { return false }
        let labelIsInsideFocusedRegion = line >= region.rect.origin.y && line < region.rect.maxY
        return labelIsInsideFocusedRegion && region.focusInteractions == .activate
    }
}
