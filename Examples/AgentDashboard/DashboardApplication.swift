import SwiftTUI

struct DashboardApplication {
    private let agents: [Agent]?
    let scenario: DashboardScenario
    let theme: ExampleTheme
    let isPaused: Bool

    nonisolated init() {
        agents = nil
        scenario = .normal
        theme = .default
        isPaused = false
    }

    nonisolated init(scenario: DashboardScenario, theme: ExampleTheme, isPaused: Bool) throws {
        agents = try Agent.examples
        self.scenario = scenario
        self.theme = theme
        self.isPaused = isPaused
    }
}

extension DashboardApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Chio") {
            if let agents {
                DashboardView(agents: agents, scenario: scenario, theme: theme, shouldAnimate: true, isPaused: isPaused)
            } else {
                Text("Run chio-dashboard to load the examples.")
            }
        }
    }
}
