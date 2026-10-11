import Chio

/// Bounded, synthetic observations. No system or external data is collected.
struct InstrumentFixture {
    let temperatures: [Double]
    let target: MeasurementGauge.TargetBand
    let references: MeasurementGauge.ReferenceMarks
    let noReferences: MeasurementGauge.ReferenceMarks
    let history: HistorySeries
    let emptyHistory: HistorySeries
    let window: HistoryInterval

    static let example: Self = {
        do {
            return try InstrumentFixture(
                temperatures: [21.4, 22, 19.6, 24.8, 20.8, 21.4],
                target: MeasurementGauge.TargetBand(lowerBound: 0.45, upperBound: 0.60),
                references: MeasurementGauge.ReferenceMarks([
                    MeasurementGauge.ReferenceMark(id: "mean", label: "Mean 20.8 °C", position: 0.52),
                    MeasurementGauge.ReferenceMark(id: "maximum", label: "Maximum 24.8 °C", position: 0.62)
                ]),
                noReferences: MeasurementGauge.ReferenceMarks([]),
                history: HistorySeries(segments: [
                    [HistorySeries.Sample(offset: .seconds(0), value: 72),
                     HistorySeries.Sample(offset: .seconds(7), value: 94),
                     HistorySeries.Sample(offset: .seconds(7), value: 118),
                     HistorySeries.Sample(offset: .seconds(19), value: nil),
                     HistorySeries.Sample(offset: .seconds(26), value: 81)],
                    [HistorySeries.Sample(offset: .seconds(61), value: 310),
                     HistorySeries.Sample(offset: .seconds(83), value: 88)]
                ]),
                emptyHistory: HistorySeries(samples: []),
                window: HistoryInterval(start: .seconds(0), end: .seconds(90))
            )
        } catch {
            preconditionFailure("Invalid local instrument fixture: \(error)")
        }
    }()
}

extension InstrumentFixture: Sendable {}
