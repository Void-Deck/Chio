import SwiftTUI

struct AppearanceApplication {
    let recipe: AppearanceRecipe
    let density: AppearanceDensity

    nonisolated init() { recipe = .chio; density = .recipe }
    nonisolated init(recipe: AppearanceRecipe, density: AppearanceDensity) {
        self.recipe = recipe
        self.density = density
    }
}

extension AppearanceApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Chio appearance") { AppearanceExampleView(recipe: recipe, density: density) }
    }
}
