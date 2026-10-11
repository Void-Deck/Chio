import Chio
import SwiftTUI

/// Identical local content and native controls across three presentation recipes.
@MainActor
struct AppearanceExampleView {
    @Environment(\.terminalSize) private var terminalSize
    @Environment(\.requestTermination) private var requestTermination
    @State private var recipe: AppearanceRecipe
    @State private var density: AppearanceDensity
    @State private var selection: Agent.ID? = "build"
    @State private var query = ""
    @State private var workspace = "Field notes"
    @State private var isAutomatic = true
    @State private var retentionDays = 7
    @State private var savedMessage = "Local example · unsaved"
    @FocusState private var focus: Focus?
    private let fixture = InstrumentFixture.example

    private enum Focus: Hashable {
        case workspace
        case overview
    }

    init(recipe: AppearanceRecipe = .chio, density: AppearanceDensity = .recipe) {
        _recipe = State(wrappedValue: recipe)
        _density = State(wrappedValue: density)
    }

    private var isWide: Bool { terminalSize.width >= 90 }
    private var style: ChioStyle { recipe.style(density: density, isNarrow: terminalSize.width < 44) }
    private var panelWidth: Int {
        let usable = max(0, terminalSize.width - 3)
        return isWide ? max(0, (usable - 4) / 3) : usable
    }

    private var panelLayout: AnyLayout {
        if isWide { return AnyLayout(HStackLayout(alignment: .top, spacing: 2)) }
        return AnyLayout(VStackLayout(alignment: .leading, spacing: 1))
    }

    private var agents: some View {
        GroupBox("Agents") {
            SearchableList(Agent.examples, selection: $selection, query: $query,
                           prompt: "Filter agents", searchText: \.name) { agent in
                HStack(spacing: 1) {
                    Text(agent.name).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    Text(agent.phase.symbol).foregroundStyle(statusColor(agent.phase))
                }
                .lineLimit(1)
            }
            .frame(height: 9 + style.spacing.sectionGap * 2)
        }
        .frame(width: panelWidth, alignment: .topLeading)
        .id("agents")
    }

    private func statusColor(_ phase: Agent.Phase) -> Color {
        switch phase {
        case .running: style.colors.accent
        case .idle: style.colors.mutedText
        case .completed: style.colors.success
        case .failed: style.colors.error
        }
    }

    private var settings: some View {
        GroupBox("Run settings") {
            VStack(alignment: .leading, spacing: style.spacing.sectionGap) {
                FormField("Workspace", description: "A name for this run.") {
                    TextField("Workspace", text: $workspace)
                        .accessibilityLabel("Workspace")
                        .focused($focus, equals: .workspace)
                }
                FormField("Automatic runs") {
                    Toggle("Automatic runs", isOn: $isAutomatic)
                }
                Stepper("Keep days", value: $retentionDays, in: 1...30)
                Button("Save settings") {
                    savedMessage = "Saved: \(workspace)"
                }
                Text(savedMessage).foregroundStyle(style.colors.secondaryText)
            }
        }
        .frame(width: panelWidth, alignment: .topLeading)
        .id("settings")
    }

    private var instruments: some View {
        GroupBox("Instruments") {
            VStack(alignment: .leading, spacing: style.spacing.sectionGap) {
                VStack(alignment: .leading, spacing: 0) {
                    LabeledContent("Temperature", value: "21.4 °C").labeledContentStyle(.instrument)
                    MeasurementGauge(position: 0.535, targetBand: fixture.target).frame(height: 2)
                    Text("Target 18–24 °C").foregroundStyle(style.colors.secondaryText)
                }
                VStack(alignment: .leading, spacing: 0) {
                    LabeledContent("Reservoir", value: "58%").labeledContentStyle(.instrument)
                    MeasurementGauge(position: 0.58).frame(height: 1)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Response time").foregroundStyle(style.colors.heading)
                    HistoryChart(fixture.history, window: fixture.window, scale: .fixed(0...500))
                        .frame(height: 3)
                    Text("90 seconds · 0–500 ms").foregroundStyle(style.colors.mutedText)
                }
            }
        }
        .frame(width: panelWidth, alignment: .topLeading)
        .id("instruments")
    }

    private var hints: some View {
        KeyHints {
            KeyHint("^T", "look")
            KeyHint("^D", "spacing")
            KeyHint("^E", "edit")
            KeyHint("^G", "graphs")
            KeyHint("^L", "list")
            KeyHint("^Q", "quit")
        }
    }
}

extension AppearanceExampleView: View {
    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 1) {
                    Text("chio").bold().foregroundStyle(style.colors.accent)
                    Text("/ appearance").foregroundStyle(style.colors.secondaryText)
                    Spacer(minLength: 0)
                }
                Text("\(recipe.title) · spacing: \(density.rawValue)")
                    .foregroundStyle(style.colors.heading)
                ScrollView {
                    panelLayout { agents; settings; instruments }
                        .padding(.vertical, 1)
                }
                .focusable()
                .focused($focus, equals: .overview)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                hints
            }
            .padding(.horizontal, 1)
            .frame(width: terminalSize.width, height: terminalSize.height, alignment: .topLeading)
            .style(style)
            .onKeyPress { press in
                guard press.modifiers == .ctrl else { return .ignored }
                switch press.key {
                case .character("t"): recipe = recipe.next
                case .character("d"): density = density.next
                case .character("e"):
                    focus = .workspace
                    proxy.scrollTo("settings", anchor: .top)
                case .character("g"):
                    focus = .overview
                    proxy.scrollTo("instruments", anchor: .top)
                case .character("l"):
                    focus = .overview
                    proxy.scrollTo("agents", anchor: .top)
                case .character("q"): _ = requestTermination()
                default: return .ignored
                }
                return .handled
            }
        }
    }
}
