/// A positive display interval measured from an application-owned time origin.
///
/// Both endpoints are between zero and `Duration.seconds(Int64.max)`. This
/// bound keeps subtraction representable; Chio neither reads nor owns a clock.
public struct HistoryInterval {
    public let range: ClosedRange<Duration>

    public enum ValidationError {
        case startOutOfRange
        case endOutOfRange
        case nonIncreasingBounds
    }

    public init(start: Duration, end: Duration) throws(ValidationError) {
        let isStartNonnegative = start >= .zero
        let isStartWithinLimit = start <= .seconds(Int64.max)
        guard isStartNonnegative && isStartWithinLimit else { throw .startOutOfRange }
        let isEndNonnegative = end >= .zero
        let isEndWithinLimit = end <= .seconds(Int64.max)
        guard isEndNonnegative && isEndWithinLimit else { throw .endOutOfRange }
        guard start < end else { throw .nonIncreasingBounds }
        range = start...end
    }
}

extension HistoryInterval: Hashable {}
extension HistoryInterval: Sendable {}
extension HistoryInterval.ValidationError: Error {}
extension HistoryInterval.ValidationError: Hashable {}
extension HistoryInterval.ValidationError: Sendable {}
