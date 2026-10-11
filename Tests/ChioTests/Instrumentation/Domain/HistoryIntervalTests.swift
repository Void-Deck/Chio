import Chio
import Testing

struct HistoryIntervalTests {
    @Test("Intervals retain exact bounds, including the admitted duration limits")
    func validBounds() throws {
        let interval = try HistoryInterval(start: .zero, end: .seconds(Int64.max))
        #expect(interval.range == .zero...Duration.seconds(Int64.max))
        let first = Duration(secondsComponent: 0, attosecondsComponent: 1)
        let second = Duration(secondsComponent: 0, attosecondsComponent: 2)
        let fractional = try HistoryInterval(start: first, end: second)
        #expect(fractional.range == first...second)
        #expect(Set([interval, interval]).count == 1)
    }

    @Test("Every interval endpoint and ordering failure has a typed diagnostic")
    func invalidBounds() {
        #expect(throws: HistoryInterval.ValidationError.startOutOfRange) {
            try HistoryInterval(start: Duration(secondsComponent: 0, attosecondsComponent: -1), end: .seconds(1))
        }
        #expect(throws: HistoryInterval.ValidationError.endOutOfRange) {
            try HistoryInterval(start: .zero, end: Duration(secondsComponent: 0, attosecondsComponent: -1))
        }
        #expect(throws: HistoryInterval.ValidationError.startOutOfRange) {
            try HistoryInterval(start: Duration(secondsComponent: Int64.max, attosecondsComponent: 1),
                                end: .seconds(Int64.max))
        }
        #expect(throws: HistoryInterval.ValidationError.endOutOfRange) {
            try HistoryInterval(start: .zero, end: Duration(secondsComponent: Int64.max, attosecondsComponent: 1))
        }
        for end in [Duration.zero, .seconds(1)] {
            #expect(throws: HistoryInterval.ValidationError.nonIncreasingBounds) {
                try HistoryInterval(start: .seconds(1), end: end)
            }
        }
    }
}
