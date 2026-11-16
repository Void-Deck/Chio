import SwiftTUI

struct HelpApplication {
    private let agents: [Agent]?
    let theme: ExampleTheme

    nonisolated init() { agents = nil; theme = .default }
    nonisolated init(theme: ExampleTheme) throws {
        agents = try Agent.examples
        self.theme = theme
    }
}

extension HelpApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Chio keyboard help") {
            if let agents {
                HelpExampleView(agents: agents, theme: theme)
            } else {
                Text("Run chio-dashboard to load the examples.")
            }
        }
    }
}
