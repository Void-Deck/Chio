/// Explicit vertical bounds or visible-window scaling.
public struct WaveformScale {
    enum Bounds {
        case fixed(lower: Double, upper: Double)
        case automatic(padding: Double)
    }
    let bounds: Bounds

    public enum ValidationError {
        case nonFiniteBound, nonIncreasingBounds, invalidPadding
    }

    public static func fixed(lower: Double, upper: Double) throws(ValidationError) -> WaveformScale {
        guard lower.isFinite, upper.isFinite else { throw .nonFiniteBound }
        guard lower < upper else { throw .nonIncreasingBounds }
        return WaveformScale(bounds: .fixed(lower: lower, upper: upper))
    }

    public static func automatic(padding: Double) throws(ValidationError) -> WaveformScale {
        guard padding.isFinite, padding >= 0 else { throw .invalidPadding }
        return WaveformScale(bounds: .automatic(padding: padding))
    }
}

extension WaveformScale: Hashable {}
extension WaveformScale: Sendable {}
extension WaveformScale.ValidationError: Error {}
extension WaveformScale.ValidationError: Hashable {}
extension WaveformScale.ValidationError: Sendable {}

extension WaveformScale.Bounds: Hashable {}
extension WaveformScale.Bounds: Sendable {}
