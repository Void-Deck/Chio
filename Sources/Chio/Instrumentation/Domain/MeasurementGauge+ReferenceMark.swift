extension MeasurementGauge {
    /// A supplied reference on the normalized scale, with stable caller identity.
    ///
    /// The label is a complete authored caption, including units when useful.
    /// Applications own calculation, normalization and interpretation.
    public nonisolated struct ReferenceMark {
        public let id: String
        public let label: String
        public let position: Double

        public enum ValidationError {
            case invalidPosition
            case emptyLabel
        }

        public init(id: String, label: String, position: Double) throws(ValidationError) {
            let isFinite = position.isFinite
            let isWithinScale = (0...1).contains(position)
            guard isFinite && isWithinScale else { throw .invalidPosition }
            guard !label.isEmpty else { throw .emptyLabel }
            self.id = id
            self.label = label
            self.position = position
        }
    }
}

extension MeasurementGauge.ReferenceMark: Hashable {}
extension MeasurementGauge.ReferenceMark: Sendable {}
extension MeasurementGauge.ReferenceMark.ValidationError: Error {}
extension MeasurementGauge.ReferenceMark.ValidationError: Equatable {}
extension MeasurementGauge.ReferenceMark.ValidationError: Sendable {}
