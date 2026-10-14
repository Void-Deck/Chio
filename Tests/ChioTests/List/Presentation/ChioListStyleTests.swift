import Chio
import SwiftTUIRuntime
import Testing

@MainActor
@Suite(.serialized)
struct ChioListStyleTests {
    @Test("Indexed and builder lists place every padded label at its measured line", arguments: [false, true])
    func paddedIntrinsicPlacement(builder: Bool) {
        let rows = Array(ListQualificationRow.fixtures.prefix(3))
        let surface = DefaultRenderer().render(
            Group {
                if builder {
                    List {
                        ForEach(rows) { row in
                            Text(row.title).padding(.vertical, 1)
                        }
                    }
                } else {
                    List(rows) { row in Text(row.title).padding(.vertical, 1) }
                }
            }.listStyle(ChioListStyle()),
            proposal: ProposedViewSize(width: 32, height: nil)
        ).rasterSurface
        #expect(surface.size.height == 9)
        #expect(surface.lines.indices.filter { surface.lines[$0].contains("Row 00") } == [1])
        #expect(surface.lines.indices.filter { surface.lines[$0].contains("Row 01") } == [4])
        #expect(surface.lines.indices.filter { surface.lines[$0].contains("Row 02") } == [7])
    }

    @Test("Native single and multiple selection reveal every row down and back, then activate or toggle the focused ID",
          arguments: ListQualificationCase.fixtures)
    fileprivate func nativeNavigation(fixture: ListQualificationCase) async throws {
        let style = fixture.style
        let multiple = fixture.multiple
        let shape = fixture.shape
        try await withListQualification(style: style, multiple: multiple, shape: shape) { session, _, recorder in
            var previous = try await recorder.wait(description: "first native row before navigation") {
                $0.qualificationRowFocused(0)
            }
            for id in 1..<12 {
                session.send(.key(.arrowDown))
                previous = try await recorder.wait(after: previous.sequence, description: "reveal row \(id) moving down") {
                    $0.qualificationRowFocused(id)
                }
                #expect(multiple ? previous.qualificationContains("Checked=-") : previous.qualificationHasToken("Selected=\(id)"))
            }
            #expect(!previous.qualificationContains("Row 00"))
            session.send(.key(.return))
            previous = try await recorder.wait(after: previous.sequence, description: "activate or toggle stable ID 11") {
                multiple ? $0.qualificationHasToken("Checked=11") : $0.qualificationContains("Activated=11 Count=1")
            }
            #expect(previous.qualificationRowFocused(11))
            #expect(previous.qualificationContains(multiple ? "Activated=- Count=0" : "Checked=-"))
            for id in (0..<11).reversed() {
                session.send(.key(.arrowUp))
                previous = try await recorder.wait(after: previous.sequence, description: "reveal row \(id) moving back up") {
                    $0.qualificationRowFocused(id)
                }
                #expect(multiple ? previous.qualificationHasToken("Checked=11") : previous.qualificationHasToken("Selected=\(id)"))
            }
            session.send(.key(.return))
            let activated = try await recorder.wait(after: previous.sequence, description: "activate or toggle stable ID 0 after reversal") {
                multiple ? $0.qualificationHasToken("Checked=0,11") : $0.qualificationContains("Activated=0 Count=2")
            }
            #expect(activated.qualificationRowFocused(0))
        }
    }

    @Test("Compact and tall searchable checklists retain native focus and membership through overflow and reversal",
          arguments: [ListQualificationShape.compact, .padded, .mixed])
    fileprivate func checklistNavigation(shape: ListQualificationShape) async throws {
        try await withListQualification(checklist: true, shape: shape) { session, _, recorder in
            let search = try await recorder.wait(description: "native checklist editor initially focused") {
                $0.qualificationSearchFocused
            }
            session.send(.key(.return))
            var previous = try await recorder.wait(after: search.sequence, description: "checklist handoff to first native row") {
                $0.qualificationRowFocused(0)
            }
            for id in 1..<12 {
                session.send(.key(.arrowDown))
                previous = try await recorder.wait(after: previous.sequence, description: "checklist reveal row \(id)") {
                    $0.qualificationRowFocused(id)
                }
                #expect(previous.qualificationContains("Checked=-"))
            }
            #expect(!previous.qualificationContains("Row 00"))
            session.send(.key(.space))
            previous = try await recorder.wait(after: previous.sequence, description: "Space checks visible ID 11 once") {
                $0.qualificationContains("Checked=11") && $0.qualificationRowFocused(11)
            }
            #expect(previous.qualificationFocusedRowContains("[x]"))
            for id in (0..<11).reversed() {
                session.send(.key(.arrowUp))
                previous = try await recorder.wait(after: previous.sequence, description: "checklist reverse reveal row \(id)") {
                    $0.qualificationRowFocused(id)
                }
                #expect(previous.qualificationContains("Checked=11"))
            }
            session.send(.key(.return))
            previous = try await recorder.wait(after: previous.sequence, description: "Return checks ID 0 and retains offscreen ID 11") {
                $0.qualificationContains("Checked=0,11") && $0.qualificationRowFocused(0)
            }
            #expect(previous.qualificationFocusedRowContains("[x]"))
            session.send(.key(.character("/")))
            previous = try await recorder.wait(after: previous.sequence, description: "slash returns to native editor") {
                $0.qualificationSearchFocused
            }
            session.sendInput(Array("11".utf8))
            previous = try await recorder.wait(after: previous.sequence, description: "filter retains checked stable IDs") {
                $0.qualificationContains("1 of 12 items") && $0.qualificationContains("Checked=0,11")
            }
            session.send(.key(.return))
            previous = try await recorder.wait(after: previous.sequence, description: "filtered checked row receives native focus") {
                $0.qualificationRowFocused(11)
            }
            session.send(.key(.return))
            let unchecked = try await recorder.wait(after: previous.sequence, description: "Return unchecks filtered ID 11 once") {
                $0.qualificationContains("Checked=0") && !$0.qualificationContains("Checked=0,11")
            }
            #expect(unchecked.qualificationRowFocused(11))
            #expect(unchecked.qualificationFocusedRowContains("[ ]"))
        }
    }

    @Test("Same-ID wrapped rows preserve focus and activation across narrow and wide surfaces")
    func sameIDWidthChange() async throws {
        try await withListQualification(shape: .wrapped) { session, surface, recorder in
            var previous = try await recorder.wait(description: "initial wrapped row focus") {
                $0.qualificationRowFocused(0)
            }
            for id in 1...7 {
                session.send(.key(.arrowDown))
                previous = try await recorder.wait(after: previous.sequence, description: "wrapped navigation to \(id)") {
                    $0.qualificationRowFocused(id)
                }
            }
            let identity = previous.focusedIdentity
            for width in [18, 32] {
                surface.updateSurfaceSize(CellSize(width: width, height: 12))
                session.requestSurfaceRefresh()
                previous = try await recorder.wait(after: previous.sequence, description: "same ID 7 remains visible at width \(width)") {
                    $0.raster.size.width == width && $0.qualificationRowFocused(7)
                }
                #expect(previous.focusedIdentity == identity)
                #expect(previous.qualificationContains("Selected=7"))
            }
            session.send(.key(.return))
            let activated = try await recorder.wait(after: previous.sequence, description: "resized stable ID activates") {
                $0.qualificationContains("Activated=7 Count=1")
            }
            #expect(activated.qualificationRowFocused(7))
        }
    }
}

private struct ListQualificationCase {
    let style: ListQualificationStyle
    let multiple: Bool
    let shape: ListQualificationShape

    static let fixtures = [ListQualificationStyle.automatic, .chio].flatMap { style in
        [false, true].flatMap { multiple in
            [ListQualificationShape.compact, .padded, .mixed].map { shape in
                ListQualificationCase(style: style, multiple: multiple, shape: shape)
            }
        }
    }
}

private enum ListQualificationStyle {
    case automatic
    case chio
}

extension ListQualificationStyle: ListStyle {
    @MainActor
    func resolvePresentation(for configuration: ListStyleConfiguration) -> ListStylePresentation {
        switch self {
        case .automatic: AutomaticListStyle().resolvePresentation(for: configuration)
        case .chio: ChioListStyle().resolvePresentation(for: configuration)
        }
    }
}

extension ListQualificationStyle: Equatable {}

private enum ListQualificationShape {
    case compact
    case padded
    case mixed
    case wrapped
}

extension ListQualificationShape: Sendable {}

private struct ListQualificationRow {
    let id: Int
    var title: String { "Row \(id < 10 ? "0" : "")\(id)" }
    static let fixtures = (0..<12).map { ListQualificationRow(id: $0) }
}

extension ListQualificationRow: Identifiable {}
extension ListQualificationRow: Sendable {}

private struct ListQualificationApp {
    let style: ListQualificationStyle
    let multiple: Bool
    let checklist: Bool
    let shape: ListQualificationShape

    nonisolated init() {
        style = .chio
        multiple = false
        checklist = false
        shape = .compact
    }

    nonisolated init(style: ListQualificationStyle, multiple: Bool, checklist: Bool, shape: ListQualificationShape) {
        self.style = style
        self.multiple = multiple
        self.checklist = checklist
        self.shape = shape
    }
}

extension ListQualificationApp: App {
    var body: some Scene {
        WindowGroup(id: "list-qualification") {
            ListQualificationView(style: style, multiple: multiple, checklist: checklist, shape: shape)
        }.exitOnKeys([])
    }
}

@MainActor
private struct ListQualificationView {
    let style: ListQualificationStyle
    let multiple: Bool
    let checklist: Bool
    let shape: ListQualificationShape
    @State private var selected: Int? = 0
    @State private var checked: Set<Int> = []
    @State private var activated: Int?
    @State private var activationCount = 0
    @State private var query = ""

    private func activate(_ id: Int) {
        activated = id
        activationCount += 1
    }

    @ViewBuilder
    private func rowContent(_ row: ListQualificationRow) -> some View {
        switch shape {
        case .compact: Text(row.title)
        case .padded: Text(row.title).padding(.vertical, 1)
        case .mixed:
            VStack(alignment: .leading, spacing: 0) {
                Text(row.title)
                ForEach(0..<(row.id % 3), id: \.self) { line in Text("Detail \(row.id):\(line)") }
            }.padding(.vertical, row.id % 2)
        case .wrapped: Text("\(row.title) a longer authored label that wraps as width changes")
        }
    }
}

extension ListQualificationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if checklist {
                    SearchableChecklist(ListQualificationRow.fixtures, selection: $checked, query: $query,
                                        searchText: \.title) { row in rowContent(row) }
                        .style(.default)
                } else if multiple {
                    List(ListQualificationRow.fixtures, selection: $checked, onActivate: activate) { row in rowContent(row) }
                        .listStyle(style)
                        .focusable(false)
                } else {
                    List(ListQualificationRow.fixtures, selection: $selected, onActivate: activate) { row in rowContent(row) }
                        .listStyle(style)
                        .focusable(false)
                }
            }.frame(height: checklist ? 14 : 8, alignment: .topLeading)
            Text("Selected=\(selected.map { String($0) } ?? "-")")
            Text("Checked=\(checked.isEmpty ? "-" : checked.sorted().map { String($0) }.joined(separator: ","))")
            Text("Activated=\(activated.map { String($0) } ?? "-") Count=\(activationCount)")
        }
    }
}

@MainActor
private func withListQualification(
    style: ListQualificationStyle = .chio, multiple: Bool = false, checklist: Bool = false,
    shape: ListQualificationShape = .compact,
    perform: @MainActor (HostedSceneSession, HostedRasterSurface, HostedFrameRecorder) async throws -> Void
) async throws {
    let recorder = HostedFrameRecorder()
    let surface = HostedRasterSurface(surfaceSize: CellSize(width: 32, height: checklist ? 18 : 12), appearance: .fallback,
                                      onFrame: { recorder.receive($0) })
    let app = ListQualificationApp(style: style, multiple: multiple, checklist: checklist, shape: shape)
    let session = try HostedSceneSession(for: app, sceneID: "list-qualification", surface: surface)
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

private extension SemanticHostFrame {
    var qualificationSearchFocused: Bool {
        semantics.accessibilityNodes.contains { $0.identity == focusedIdentity && $0.role == .textField }
    }

    func qualificationContains(_ text: String) -> Bool { raster.lines.contains { $0.contains(text) } }

    func qualificationHasToken(_ text: String) -> Bool {
        raster.lines.contains { $0.split(separator: " ").contains(Substring(text)) }
    }

    func qualificationFocusedRowContains(_ text: String) -> Bool {
        guard let region = semantics.focusRegions.first(where: { $0.identity == focusedIdentity }) else { return false }
        let visibleLines = max(0, region.rect.origin.y)..<min(raster.lines.count, region.rect.maxY)
        return visibleLines.contains { raster.lines[$0].contains(text) }
    }

    func qualificationRowFocused(_ id: Int) -> Bool {
        let title = ListQualificationRow(id: id).title
        guard let line = raster.lines.firstIndex(where: { $0.contains(title) }),
              let region = semantics.focusRegions.first(where: { $0.identity == focusedIdentity }) else { return false }
        let labelIsInsideFocusedRegion = line >= region.rect.origin.y && line < region.rect.maxY
        let regionAcceptsActivation = region.focusInteractions == .activate
        return labelIsInsideFocusedRegion && regionAcceptsActivation
    }
}
