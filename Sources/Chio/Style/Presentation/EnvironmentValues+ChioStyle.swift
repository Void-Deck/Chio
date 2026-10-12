import SwiftTUIViews

private enum ChioStyleKey {}

extension ChioStyleKey: EnvironmentKey {
    static let defaultValue = ChioStyle.default
}

extension EnvironmentValues {
    /// Inherited presentation for Chio views. Use `.style(...)` to also install
    /// matching native control styles at the same subtree boundary.
    public var chioStyle: ChioStyle {
        get { self[ChioStyleKey.self] }
        set { self[ChioStyleKey.self] = newValue }
    }
}
