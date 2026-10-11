import Chio
import Testing

struct HistorySeriesTests {
    @Test("Checked observations preserve missing, zero, finite extremes and duration boundaries")
    func observations() throws {
        let missing = try HistorySeries.Sample(offset: .zero, value: nil)
        let zero = try HistorySeries.Sample(offset: .zero, value: 0)
        let extreme = try HistorySeries.Sample(offset: .seconds(Int64.max), value: -.greatestFiniteMagnitude)
        #expect(missing.value == nil)
        #expect(zero.value == 0)
        #expect(missing != zero)
        #expect(extreme.offset == .seconds(Int64.max))
        #expect(Set([missing, zero, extreme]).count == 3)
        for offset in [Duration(secondsComponent: 0, attosecondsComponent: -1),
                       Duration(secondsComponent: Int64.max, attosecondsComponent: 1)] {
            #expect(throws: HistorySeries.Sample.ValidationError.offsetOutOfRange) {
                try HistorySeries.Sample(offset: offset, value: 0)
            }
        }
        for value in [Double.nan, .infinity, -.infinity] {
            #expect(throws: HistorySeries.Sample.ValidationError.nonfiniteValue) {
                try HistorySeries.Sample(offset: .zero, value: value)
            }
        }
    }

    @Test("Equal timestamps retain every observation; explicit segments may restart and overlap")
    func orderAndBreaks() throws {
        let first = try HistorySeries.Sample(offset: .seconds(5), value: 1)
        let second = try HistorySeries.Sample(offset: .seconds(5), value: 2)
        let restart = try HistorySeries.Sample(offset: .seconds(1), value: 3)
        let series = try HistorySeries(segments: [[first, second], [restart, first]])
        #expect(series.segments == [[first, second], [restart, first]])
        #expect(try HistorySeries(samples: [first, second]).segments == [[first, second]])
        #expect(try HistorySeries(samples: []).segments.isEmpty)
        #expect(try HistorySeries(segments: []).segments.isEmpty)
        #expect(throws: HistorySeries.ValidationError.emptySegment(segmentIndex: 1)) {
            try HistorySeries(segments: [[first], []])
        }
        #expect(throws: HistorySeries.ValidationError.decreasingOffset(segmentIndex: 1, sampleIndex: 1)) {
            try HistorySeries(segments: [[restart], [first, restart]])
        }
        // Failed replacement construction cannot mutate the accepted snapshot.
        #expect(series.segments == [[first, second], [restart, first]])
    }

    @Test("Admission accepts exact sample and segment caps, then rejects without truncation")
    func admissionLimits() throws {
        let sample = try HistorySeries.Sample(offset: .zero, value: 1)
        let exactSamples = Array(repeating: sample, count: 16_384)
        #expect(try HistorySeries(samples: exactSamples).segments == [exactSamples])
        #expect(throws: HistorySeries.ValidationError.sampleLimitExceeded(segmentIndex: 0, limit: 16_384)) {
            try HistorySeries(samples: exactSamples + [sample])
        }
        #expect(throws: HistorySeries.ValidationError.sampleLimitExceeded(segmentIndex: 1, limit: 16_384)) {
            try HistorySeries(segments: [exactSamples, [sample]])
        }
        let exactSegments = Array(repeating: [sample], count: 4_096)
        #expect(try HistorySeries(segments: exactSegments).segments == exactSegments)
        #expect(throws: HistorySeries.ValidationError.segmentLimitExceeded(limit: 4_096)) {
            try HistorySeries(segments: exactSegments + [[sample]])
        }
    }
}
