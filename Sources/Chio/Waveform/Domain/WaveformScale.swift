/// Explicit vertical bounds or visible-window scaling.
public struct WaveformScale {
    enum Rule {
        case fixed(lower: Double, upper: Double)
        case automatic(padding: Double)
    }
    let rule: Rule

    public enum ValidationError {
        case nonFiniteBound, nonIncreasingBounds, invalidPadding
    }

    public static func fixed(lower: Double, upper: Double) throws(ValidationError) -> WaveformScale {
        guard lower.isFinite, upper.isFinite else { throw .nonFiniteBound }
        guard lower < upper else { throw .nonIncreasingBounds }
        return WaveformScale(rule: .fixed(lower: lower, upper: upper))
    }

    public static func automatic(padding: Double) throws(ValidationError) -> WaveformScale {
        guard padding.isFinite, padding >= 0 else { throw .invalidPadding }
        return WaveformScale(rule: .automatic(padding: padding))
    }
}

extension WaveformScale: Hashable {}
extension WaveformScale: Sendable {}
extension WaveformScale.ValidationError: Error {}
extension WaveformScale.ValidationError: Hashable {}
extension WaveformScale.ValidationError: Sendable {}

extension WaveformScale.Rule: Hashable {}
extension WaveformScale.Rule: Sendable {}
