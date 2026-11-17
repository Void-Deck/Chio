import Chio
import Testing

struct WaveformSamplesSpecTests {
    private typealias Failure = WaveformSamples.ValidationError
    private static let limit = Duration.seconds(Int64.max)
    private static let attosecond = Duration(secondsComponent: 0, attosecondsComponent: 1)

    @Test("Checked samples retain their start, rate and values, including gaps")
    func storedValues() throws {
        let start = Duration.milliseconds(1_500)
        let values: [Double?] = [1.5, nil, -2, 0, nil]
        let samples = try WaveformSamples(start: start, rate: 25, values: values)
        #expect(samples.start == start)
        #expect(samples.rate == 25)
        #expect(samples.values == values)
        let same = try WaveformSamples(start: start, rate: 25, values: values)
        let other = try WaveformSamples(start: start, rate: 25, values: [1.5, 0, -2, 0, nil])
        #expect(samples == same)
        #expect(Set([samples, same, other]).count == 2)
    }

    @Test("A nil value is a gap and never reads as zero")
    func gapsAreDistinct() throws {
        let gap = try WaveformSamples(start: .zero, rate: 1, values: [nil])
        let zero = try WaveformSamples(start: .zero, rate: 1, values: [0])
        #expect(gap.values == [nil])
        #expect(gap != zero)
        let allGaps = try WaveformSamples(start: .zero, rate: 1, values: [nil, nil, nil])
        #expect(allGaps.values.allSatisfy { $0 == nil })
    }

    @Test("Start bounds admit zero and the Int64 second limit, and reject anything outside")
    func startBounds() throws {
        #expect(try WaveformSamples(start: .zero, rate: 1, values: [1]).start == .zero)
        #expect(try WaveformSamples(start: Self.limit, rate: 1, values: [1]).start == Self.limit)
        #expect(throws: Failure.startOutOfRange) {
            try WaveformSamples(start: .zero - Self.attosecond, rate: 1, values: [1])
        }
        #expect(throws: Failure.startOutOfRange) {
            try WaveformSamples(start: Self.limit + Self.attosecond, rate: 1, values: [1])
        }
    }

    @Test("Rates must be finite and above zero")
    func rates() throws {
        for rate in [0, -0.0, -1, .infinity, -.infinity, .nan] {
            #expect(throws: Failure.invalidRate) { try WaveformSamples(start: .zero, rate: rate, values: [1]) }
        }
        for rate in [Double.leastNonzeroMagnitude, 0.5, 25, Double.greatestFiniteMagnitude] {
            #expect(try WaveformSamples(start: .zero, rate: rate, values: [1]).rate == rate)
        }
    }

    @Test("An empty series is rejected")
    func empty() {
        #expect(throws: Failure.empty) { try WaveformSamples(start: .zero, rate: 1, values: []) }
    }

    @Test("Exactly maximumCount samples are admitted and one more is rejected")
    func countLimit() throws {
        #expect(WaveformSamples.maximumCount == 2_097_152)
        let admitted = try WaveformSamples(start: .zero, rate: 25,
                                           values: Array(repeating: nil, count: WaveformSamples.maximumCount))
        #expect(admitted.values.count == WaveformSamples.maximumCount)
        #expect(throws: Failure.tooManySamples) {
            try WaveformSamples(start: .zero, rate: 25,
                                values: Array(repeating: 1, count: WaveformSamples.maximumCount + 1))
        }
    }

    @Test("The last sample's offset, start + (count - 1) / rate, may reach but not exceed the limit")
    func endBounds() throws {
        let lastAtLimit = try WaveformSamples(start: .seconds(Int64.max - 2), rate: 1, values: [1, 2, 3])
        #expect(lastAtLimit.values.count == 3)
        #expect(throws: Failure.endOutOfRange) {
            try WaveformSamples(start: .seconds(Int64.max - 2), rate: 1, values: [1, 2, 3, 4])
        }
        #expect(throws: Failure.endOutOfRange) {
            try WaveformSamples(start: Self.limit, rate: 1, values: [1, 2])
        }
        // A tiny rate places the second sample an enormous time after the first.
        #expect(throws: Failure.endOutOfRange) {
            try WaveformSamples(start: .zero, rate: Double.leastNonzeroMagnitude, values: [1, 2])
        }
        #expect(throws: Failure.endOutOfRange) {
            try WaveformSamples(start: .zero, rate: 1e-30, values: [1, 2])
        }
        // A single sample's end is its start.
        #expect(try WaveformSamples(start: .zero, rate: 1e-30, values: [1]).values == [1])
    }

    @Test("The first non-finite value is reported by index")
    func nonFiniteValues() throws {
        for value in [Double.nan, .infinity, -.infinity] {
            #expect(throws: Failure.nonFiniteValue(index: 0)) {
                try WaveformSamples(start: .zero, rate: 1, values: [value])
            }
        }
        #expect(throws: Failure.nonFiniteValue(index: 2)) {
            try WaveformSamples(start: .zero, rate: 1, values: [1, nil, .infinity, .nan, 3])
        }
        let extremes = try WaveformSamples(start: .zero, rate: 1,
                                           values: [-.greatestFiniteMagnitude, .greatestFiniteMagnitude, nil])
        #expect(extremes.values.count == 3)
    }

    @Test("Validation reports the first failing check in the specified order")
    func order() {
        let negative = Duration.zero - Self.attosecond
        // startOutOfRange before invalidRate, empty and everything after.
        #expect(throws: Failure.startOutOfRange) { try WaveformSamples(start: negative, rate: .nan, values: []) }
        // invalidRate before empty.
        #expect(throws: Failure.invalidRate) { try WaveformSamples(start: .zero, rate: 0, values: []) }
        // invalidRate before tooManySamples and nonFiniteValue.
        #expect(throws: Failure.invalidRate) {
            try WaveformSamples(start: .zero, rate: -1,
                                values: Array(repeating: .nan, count: WaveformSamples.maximumCount + 1))
        }
        // tooManySamples before endOutOfRange and nonFiniteValue.
        #expect(throws: Failure.tooManySamples) {
            try WaveformSamples(start: Self.limit, rate: 1,
                                values: Array(repeating: .nan, count: WaveformSamples.maximumCount + 1))
        }
        // endOutOfRange before nonFiniteValue.
        #expect(throws: Failure.endOutOfRange) {
            try WaveformSamples(start: Self.limit, rate: 1, values: [.nan, .infinity])
        }
    }
}
