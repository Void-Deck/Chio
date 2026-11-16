import SwiftTUI

struct WaveformStudyApplication {
    private let content: WaveformStudyView?
    nonisolated init() { content = nil }
    nonisolated init(content: WaveformStudyView) { self.content = content }
}

extension WaveformStudyApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Waveform study") {
            if let content { content }
            else { Text("Run WaveformStudy from the repository root.") }
        }
    }
}
