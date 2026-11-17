import SwiftTUI

struct WaveformApplication {
    private let content: WaveformExampleView?
    nonisolated init() { content = nil }
    nonisolated init(content: WaveformExampleView) { self.content = content }
}

extension WaveformApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Waveform example") {
            if let content { content }
            else { Text("Run chio-waveform from the repository root.") }
        }
    }
}
