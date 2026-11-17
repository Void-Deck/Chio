import Chio
import Testing

struct WaveformScaleSpecTests {
    private typealias Failure = WaveformScale.ValidationError

    @Test("Fixed scales admit finite, strictly increasing bounds and compare by value")
    func fixedAdmitted() throws {
        let unit = try WaveformScale.fixed(lower: -1, upper: 1)
        #expect(unit == (try WaveformScale.fixed(lower: -1, upper: 1)))
        #expect(unit != (try WaveformScale.fixed(lower: -1, upper: 2)))
        #expect(unit != (try WaveformScale.automatic(padding: 0)))
        let widest = try WaveformScale.fixed(lower: -.greatestFiniteMagnitude, upper: .greatestFiniteMagnitude)
        let narrowest = try WaveformScale.fixed(lower: 0, upper: .leastNonzeroMagnitude)
        #expect(Set([unit, widest, narrowest]).count == 3)
    }

    @Test("Fixed scales reject a non-finite bound before checking order")
    func fixedNonFinite() {
        let cases: [(Double, Double)] = [(.nan, 1), (0, .nan), (-.infinity, 1), (0, .infinity),
                                         (.infinity, 0), (1, -.infinity), (.nan, .nan)]
        for (lower, upper) in cases {
            #expect(throws: Failure.nonFiniteBound) { try WaveformScale.fixed(lower: lower, upper: upper) }
        }
    }

    @Test("Fixed scales reject equal or decreasing bounds")
    func fixedOrder() {
        for (lower, upper) in [(1.0, 1.0), (2.0, 1.0), (0.0, -0.0), (Double.greatestFiniteMagnitude, -1)] {
            #expect(throws: Failure.nonIncreasingBounds) { try WaveformScale.fixed(lower: lower, upper: upper) }
        }
    }

    @Test("Automatic padding must be finite and at least zero")
    func automaticPadding() throws {
        for padding in [0, 0.5, 3, Double.greatestFiniteMagnitude] {
            _ = try WaveformScale.automatic(padding: padding)
        }
        #expect(try WaveformScale.automatic(padding: 0.5) == WaveformScale.automatic(padding: 0.5))
        #expect(try WaveformScale.automatic(padding: 0.5) != WaveformScale.automatic(padding: 1))
        for padding in [-1, -Double.leastNonzeroMagnitude, .nan, .infinity, -.infinity] {
            #expect(throws: Failure.invalidPadding) { try WaveformScale.automatic(padding: padding) }
        }
    }

    @Test("Modes are the two specified cases")
    func modes() {
        #expect(Set([WaveformMode.bipolar, .magnitude, .bipolar]).count == 2)
    }
}
