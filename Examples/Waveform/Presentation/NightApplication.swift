import SwiftTUI

struct NightApplication {
    private let content: NightExampleView?
    nonisolated init() { content = nil }
    nonisolated init(content: NightExampleView) { self.content = content }
}

extension NightApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Waveform example") {
            if let content { content }
            else { Text("Run chio-waveform from the repository root.") }
        }
    }
}
