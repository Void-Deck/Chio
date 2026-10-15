import SwiftTUIViews

/// A compact frame around SwiftTUI's native multiline editing surface.
/// Apply through `style(_:)` to share the editor's foreground palette.
/// The frame fills a finite proposal; use `frame(height:)` to bound the viewport.
public struct ChioTextEditorStyle {
    public let theme: ChioStyle

    public init(theme: ChioStyle = .default) {
        self.theme = theme
    }
}

extension ChioTextEditorStyle: TextEditorStyle {
    @MainActor
    public func makeBody(configuration: TextEditorStyleConfiguration) -> some View {
        configuration.editorContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, theme.spacing.horizontalInset)
            .background(theme.colors.surface)
            .border(configuration.focusActive && configuration.isEnabled ? theme.colors.accent : theme.colors.border,
                    style: theme.treatments.borderStyle, placement: .outset)
            .minimumIntrinsicSize(height: 3)
    }
}

extension ChioTextEditorStyle: Equatable {}
