import SwiftTUIViews

extension View {
    /// Installs complete presentation for matrices in this subtree.
    public func dotMatrixStyle(_ style: DotMatrixStyle) -> some View {
        environment(\.dotMatrixStyle, style)
    }
}
