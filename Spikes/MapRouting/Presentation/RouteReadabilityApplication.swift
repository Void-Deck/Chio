import SwiftTUI

struct RouteReadabilityApplication {
    private let content: RouteReadabilityView?

    nonisolated init() { content = nil }
    nonisolated init(content: RouteReadabilityView) { self.content = content }
}

extension RouteReadabilityApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Route readability") {
            if let content { content }
            else { Text("Run RouteReadability from the repository root.") }
        }
    }
}
