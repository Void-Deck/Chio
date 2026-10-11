import Chio
import Testing

// No main-actor annotation: the checked value is usable by application domain code.
struct TargetBandTests {
    @Test("A target preserves its exact range and inclusive endpoints")
    func rangeAndMembership() throws {
        let band = try MeasurementGauge.TargetBand(lowerBound: 0.45, upperBound: 0.60)
        #expect(band.range == 0.45...0.60)
        #expect(band.range.contains(0.45))
        #expect(band.range.contains(0.60))
        #expect(!band.range.contains(Double(0.45).nextDown))
        #expect(!band.range.contains(Double(0.60).nextUp))
        #expect(try MeasurementGauge.TargetBand(lowerBound: 0, upperBound: 1).range == 0...1)
        let narrow = try MeasurementGauge.TargetBand(lowerBound: 0.5, upperBound: Double(0.5).nextUp)
        #expect(narrow.range == 0.5...Double(0.5).nextUp)
        #expect(Set([band, band]).count == 1)
    }

    @Test("Invalid scalar endpoints reject before constructing a closed range")
    func invalidEndpoints() {
        for lower in [Double.nan, .infinity, -.infinity, -Double.leastNonzeroMagnitude, Double(1).nextUp] {
            #expect(throws: MeasurementGauge.TargetBand.ValidationError.invalidLowerBound) {
                try MeasurementGauge.TargetBand(lowerBound: lower, upperBound: 1)
            }
        }
        for upper in [Double.nan, .infinity, -.infinity, -Double.leastNonzeroMagnitude, Double(1).nextUp] {
            #expect(throws: MeasurementGauge.TargetBand.ValidationError.invalidUpperBound) {
                try MeasurementGauge.TargetBand(lowerBound: 0, upperBound: upper)
            }
        }
        #expect(throws: MeasurementGauge.TargetBand.ValidationError.invalidLowerBound) {
            try MeasurementGauge.TargetBand(lowerBound: .nan, upperBound: .nan)
        }
        for bounds in [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0), (0.75, 0.25)] {
            #expect(throws: MeasurementGauge.TargetBand.ValidationError.nonIncreasingBounds) {
                try MeasurementGauge.TargetBand(lowerBound: bounds.0, upperBound: bounds.1)
            }
        }
    }
}
