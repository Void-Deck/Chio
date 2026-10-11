import SwiftTUIViews

extension EnvironmentValues {
    /// Compatibility access to the same value as `chioStyle`.
    public var chioTheme: ChioTheme {
        get { chioStyle }
        set { chioStyle = newValue }
    }
}
