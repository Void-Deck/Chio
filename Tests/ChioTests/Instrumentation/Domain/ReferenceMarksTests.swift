import Chio
import Testing

struct ReferenceMarksTests {
    @Test("Bounded references preserve authored order, independent positions and explicit removal")
    func orderedFacts() throws {
        let mean = try MeasurementGauge.ReferenceMark(id: "mean", label: "Mean 410 W", position: 410.0 / 600)
        let maximum = try MeasurementGauge.ReferenceMark(id: "maximum", label: "Maximum 220 W", position: 220.0 / 600)
        let references = try MeasurementGauge.ReferenceMarks([mean, maximum])
        #expect(references.marks == [mean, maximum])
        #expect(try MeasurementGauge.ReferenceMarks([]).marks.isEmpty)
        #expect(try MeasurementGauge.ReferenceMarks([maximum]).marks == [maximum])
        #expect(Set([references, references]).count == 1)
        let coincident = try MeasurementGauge.ReferenceMark(id: "other", label: "Mean 410 W", position: mean.position)
        #expect(try MeasurementGauge.ReferenceMarks([mean, coincident]).marks.count == 2)
    }

    @Test("Reference collections reject excessive cardinality and repeated identity independently of coordinates")
    func invalidCollections() throws {
        let first = try MeasurementGauge.ReferenceMark(id: "mean", label: "Mean", position: 0.2)
        let second = try MeasurementGauge.ReferenceMark(id: "maximum", label: "Maximum", position: 0.7)
        let third = try MeasurementGauge.ReferenceMark(id: "third", label: "Third", position: 0.9)
        #expect(throws: MeasurementGauge.ReferenceMarks.ValidationError.tooManyMarks) {
            try MeasurementGauge.ReferenceMarks([first, second, third])
        }
        let repeated = try MeasurementGauge.ReferenceMark(id: "mean", label: "Different caption", position: 0.9)
        #expect(throws: MeasurementGauge.ReferenceMarks.ValidationError.duplicateID) {
            try MeasurementGauge.ReferenceMarks([first, repeated])
        }
    }
}
