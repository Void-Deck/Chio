import SwiftTUI

struct MatrixStudyApplication {
    private let scene: MatrixScene?

    nonisolated init() { scene = nil }
    nonisolated init(scene: MatrixScene) { self.scene = scene }
}

extension MatrixStudyApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Dot matrix study") {
            if let scene { MatrixStudyView(scene: scene) }
            else { Text("Launch DotMatrixPreview from the repository.") }
        }
    }
}
