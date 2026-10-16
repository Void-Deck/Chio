extension MeasurementGauge {
    /// Up to two ordered, independently supplied references with unique identities.
    ///
    /// Caller order determines presentation ordinals, not the positions or labels.
    /// An empty collection explicitly removes references. No relative ordering
    /// between positions is required, even for captions such as mean and maximum.
    public nonisolated struct ReferenceMarks {
        public let marks: [ReferenceMark]

        public enum ValidationError {
            case tooManyMarks
            case duplicateID
        }

        public init(_ marks: [ReferenceMark]) throws(ValidationError) {
            guard marks.count <= 2 else { throw .tooManyMarks }
            let identities = Set(marks.map(\.id))
            guard identities.count == marks.count else { throw .duplicateID }
            self.marks = marks
        }
    }
}

extension MeasurementGauge.ReferenceMarks: Hashable {}
extension MeasurementGauge.ReferenceMarks: Sendable {}

extension MeasurementGauge.ReferenceMarks.ValidationError: Equatable {}
extension MeasurementGauge.ReferenceMarks.ValidationError: Error {}
extension MeasurementGauge.ReferenceMarks.ValidationError: Sendable {}
