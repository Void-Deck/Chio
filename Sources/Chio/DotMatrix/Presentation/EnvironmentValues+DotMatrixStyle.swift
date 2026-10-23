import SwiftTUIViews

private enum DotMatrixStyleKey {}

extension DotMatrixStyleKey: EnvironmentKey {
    static let defaultValue: DotMatrixStyle = {
        do { return try DotMatrixStyle() }
        catch { preconditionFailure("The default dot matrix gaps must remain valid.") }
    }()
}

extension EnvironmentValues {
    /// Inherited matrix presentation. The nearest complete value takes precedence.
    public var dotMatrixStyle: DotMatrixStyle {
        get { self[DotMatrixStyleKey.self] }
        set { self[DotMatrixStyleKey.self] = newValue }
    }
}
