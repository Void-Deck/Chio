import SwiftTUI

struct TabsApplication {
    private let agents: [Agent]?
    let theme: ExampleTheme

    nonisolated init() { agents = nil; theme = .default }
    nonisolated init(theme: ExampleTheme) throws {
        agents = try Agent.examples
        self.theme = theme
    }
}

extension TabsApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Chio workspace tabs") {
            if let agents {
                TabsExampleView(agents: agents, theme: theme)
            } else {
                Text("Run chio-dashboard to load the examples.")
            }
        }
    }
}
