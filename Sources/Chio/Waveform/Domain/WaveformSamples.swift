/// A checked immutable fixed-rate signal. Nil values represent gaps.
public struct WaveformSamples {
    public static let maximumCount = 2_097_152
    public let start: Duration
    public let rate: Double
    public let values: [Double?]

    public enum ValidationError {
        case startOutOfRange, endOutOfRange, invalidRate, empty, tooManySamples
        case nonFiniteValue(index: Int)
    }

    public init(start: Duration, rate: Double, values: [Double?]) throws(ValidationError) {
        guard start >= .zero, start <= .seconds(Int64.max) else { throw .startOutOfRange }
        guard rate.isFinite, rate > 0 else { throw .invalidRate }
        guard !values.isEmpty else { throw .empty }
        guard values.count <= Self.maximumCount else { throw .tooManySamples }
        let elapsed = Double(values.count - 1) / rate
        let remaining = Duration.seconds(Int64.max) - start
        guard elapsed.isFinite, elapsed < Double(Int64.max) else { throw .endOutOfRange }
        guard (elapsed == 0 || remaining > .zero), Duration.seconds(elapsed) <= remaining else { throw .endOutOfRange }
        for (index, value) in values.enumerated() {
            if let value, !value.isFinite { throw .nonFiniteValue(index: index) }
        }
        self.start = start
        self.rate = rate
        self.values = values
    }
}

extension WaveformSamples: Hashable {}
extension WaveformSamples: Sendable {}
extension WaveformSamples.ValidationError: Error {}
extension WaveformSamples.ValidationError: Hashable {}
extension WaveformSamples.ValidationError: Sendable {}
