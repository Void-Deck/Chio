import SwiftTUIViews

extension View {
    /// Compatibility spelling for `.style(...)`; both scope the same environment value.
    public func chioTheme(_ theme: ChioTheme) -> some View {
        style(theme)
    }
}
