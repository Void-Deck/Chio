/// A bounded, immutable history whose segment boundaries prohibit connections.
///
/// Offsets are nondecreasing within each nonempty segment. Equal timestamps
/// preserve distinct observations and can produce vertical connections. Separate
/// segments may overlap or restart in time; their boundary asserts only that the
/// chart must not connect them, never a timed outage. A `nil` reading breaks both
/// adjacent connections, independently of the segment boundaries.
public struct HistorySeries {
    public static let maximumSampleCount = 16_384
    public static let maximumSegmentCount = 4_096

    public let segments: [[Sample]]

    public enum ValidationError {
        case segmentLimitExceeded(limit: Int)
        case sampleLimitExceeded(segmentIndex: Int, limit: Int)
        case emptySegment(segmentIndex: Int)
        case decreasingOffset(segmentIndex: Int, sampleIndex: Int)
    }

    /// One supplied observation; unavailable is distinct from a known zero.
    public struct Sample {
        public let offset: Duration
        public let value: Double?

        public enum ValidationError {
            case offsetOutOfRange
            case nonfiniteValue
        }

        public init(offset: Duration, value: Double?) throws(ValidationError) {
            let isNonnegative = offset >= .zero
            let isWithinLimit = offset <= .seconds(Int64.max)
            guard isNonnegative && isWithinLimit else { throw .offsetOutOfRange }
            if let value, !value.isFinite { throw .nonfiniteValue }
            self.offset = offset
            self.value = value
        }
    }

    /// Supplies one connected segment. Empty input is a valid blank history.
    public init(samples: [Sample]) throws(ValidationError) {
        if samples.isEmpty {
            try self.init(segments: [])
        } else {
            try self.init(segments: [samples])
        }
    }

    /// Supplies explicit disconnected segments without sorting or repairing them.
    public init(segments: [[Sample]]) throws(ValidationError) {
        guard segments.count <= Self.maximumSegmentCount else {
            throw .segmentLimitExceeded(limit: Self.maximumSegmentCount)
        }
        var sampleCount = 0
        for (segmentIndex, segment) in segments.enumerated() {
            guard !segment.isEmpty else { throw .emptySegment(segmentIndex: segmentIndex) }
            guard segment.count <= Self.maximumSampleCount - sampleCount else {
                throw .sampleLimitExceeded(segmentIndex: segmentIndex, limit: Self.maximumSampleCount)
            }
            sampleCount += segment.count
            for sampleIndex in segment.indices.dropFirst() {
                guard segment[sampleIndex - 1].offset <= segment[sampleIndex].offset else {
                    throw .decreasingOffset(segmentIndex: segmentIndex, sampleIndex: sampleIndex)
                }
            }
        }
        self.segments = segments
    }
}

extension HistorySeries: Hashable {}
extension HistorySeries: Sendable {}
extension HistorySeries.ValidationError: Error {}
extension HistorySeries.ValidationError: Hashable {}
extension HistorySeries.ValidationError: Sendable {}
extension HistorySeries.Sample: Hashable {}
extension HistorySeries.Sample: Sendable {}
extension HistorySeries.Sample.ValidationError: Error {}
extension HistorySeries.Sample.ValidationError: Hashable {}
extension HistorySeries.Sample.ValidationError: Sendable {}
