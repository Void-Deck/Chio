import SwiftTUI

struct InstrumentsApplication {
    let theme: ExampleTheme

    nonisolated init() { theme = .default }
    nonisolated init(theme: ExampleTheme) { self.theme = theme }
}

extension InstrumentsApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Chio instruments") { InstrumentsExampleView(theme: theme) }
    }
}
