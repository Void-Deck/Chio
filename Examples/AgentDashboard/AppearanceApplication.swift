import SwiftTUI

struct AppearanceApplication {
    private let agents: [Agent]?
    let recipe: AppearanceRecipe
    let density: AppearanceDensity

    nonisolated init() { agents = nil; recipe = .chio; density = .recipe }
    nonisolated init(recipe: AppearanceRecipe, density: AppearanceDensity) throws {
        agents = try Agent.examples
        self.recipe = recipe
        self.density = density
    }
}

extension AppearanceApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Chio appearance") {
            if let agents {
                AppearanceExampleView(agents: agents, recipe: recipe, density: density)
            } else {
                Text("Run chio-dashboard to load the examples.")
            }
        }
    }
}
