import Chio
import Testing

struct ReferenceMarkTests {
    @Test("Reference identity and the complete authored caption are preserved off the main actor")
    func suppliedFacts() throws {
        let mark = try MeasurementGauge.ReferenceMark(id: "mean", label: "Mean 20.8 °C", position: 220.0 / 600)
        #expect(mark.id == "mean")
        #expect(mark.label == "Mean 20.8 °C")
        #expect(mark.position == 220.0 / 600)
        #expect(Set([mark, mark]).count == 1)
        #expect(try MeasurementGauge.ReferenceMark(id: "", label: "Zero", position: 0).position == 0)
        #expect(try MeasurementGauge.ReferenceMark(id: "upper", label: "Upper", position: 1).position == 1)
    }

    @Test("References reject missing captions and nonfinite or out-of-scale positions without clamping")
    func invalidConstruction() {
        #expect(throws: MeasurementGauge.ReferenceMark.ValidationError.emptyLabel) {
            try MeasurementGauge.ReferenceMark(id: "mean", label: "", position: 0.5)
        }
        for position in [Double.nan, .infinity, -.infinity, -Double.leastNonzeroMagnitude, Double(1).nextUp] {
            #expect(throws: MeasurementGauge.ReferenceMark.ValidationError.invalidPosition) {
                try MeasurementGauge.ReferenceMark(id: "mean", label: "Mean", position: position)
            }
        }
    }
}
