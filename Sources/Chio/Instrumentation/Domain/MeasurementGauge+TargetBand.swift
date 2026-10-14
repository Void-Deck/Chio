extension MeasurementGauge {
    /// An authored desired interval on the gauge's normalized scale.
    ///
    /// Applications own the interval's meaning, units and normalization. Range
    /// membership is inclusive and independent of the gauge's raster rounding.
    public nonisolated struct TargetBand {
        public let range: ClosedRange<Double>

        public enum ValidationError {
            case invalidLowerBound
            case invalidUpperBound
            case nonIncreasingBounds
        }

        public init(lowerBound: Double, upperBound: Double) throws(ValidationError) {
            let isLowerFinite = lowerBound.isFinite
            let isLowerWithinScale = (0...1).contains(lowerBound)
            guard isLowerFinite && isLowerWithinScale else {
                throw .invalidLowerBound
            }
            let isUpperFinite = upperBound.isFinite
            let isUpperWithinScale = (0...1).contains(upperBound)
            guard isUpperFinite && isUpperWithinScale else {
                throw .invalidUpperBound
            }
            guard lowerBound < upperBound else { throw .nonIncreasingBounds }
            range = lowerBound...upperBound
        }
    }
}

extension MeasurementGauge.TargetBand: Hashable {}
extension MeasurementGauge.TargetBand: Sendable {}

extension MeasurementGauge.TargetBand.ValidationError: Equatable {}
extension MeasurementGauge.TargetBand.ValidationError: Error {}
extension MeasurementGauge.TargetBand.ValidationError: Sendable {}
