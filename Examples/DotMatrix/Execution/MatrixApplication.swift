import SwiftTUI

struct MatrixApplication {
    private let scene: MatrixScene?
    private let theme: MatrixTheme
    private let isViewport: Bool

    nonisolated init() {
        scene = nil
        theme = .default
        isViewport = false
    }

    nonisolated init(scene: MatrixScene, theme: MatrixTheme, isViewport: Bool) {
        self.scene = scene
        self.theme = theme
        self.isViewport = isViewport
    }
}

extension MatrixApplication: SwiftTUIRuntime.App {
    var body: some Scene {
        WindowGroup("Chio dot matrix") {
            if let scene {
                if isViewport { MatrixViewportView(frame: scene.gradient).style(theme.style) }
                else { MatrixExampleView(scene: scene).style(theme.style) }
            } else { Text("Launch chio-matrix from the repository.") }
        }
    }
}
