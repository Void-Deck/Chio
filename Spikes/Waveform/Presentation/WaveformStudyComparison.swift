import Chio
import SwiftTUI

@MainActor
struct WaveformStudyComparison {
    let night: WaveformStudyNight
    let window: WaveformStudyWindow

    private var stride: Int {
        (window.indices.count + HistorySeries.maximumSampleCount - 1) / HistorySeries.maximumSampleCount
    }

    private func history() throws -> (HistorySeries, HistoryInterval) {
        let samples = try Swift.stride(from: window.indices.lowerBound, to: window.indices.upperBound, by: stride).map { index in
            try HistorySeries.Sample(offset: .milliseconds((index - window.indices.lowerBound) * 40),
                                     value: night.flow[index].map(Double.init))
        }
        return try (HistorySeries(samples: samples), HistoryInterval(start: .zero, end: .seconds(window.length.seconds)))
    }
}

extension WaveformStudyComparison: View {
    var body: some View {
        GroupBox(stride == 1 ? "HistoryChart (all visible samples)" : "HistoryChart (every \(stride)th sample)") {
            // Construction errors remain visible; they never become empty data.
            switch Result(catching: history) {
            case .success(let (series, interval)):
                VStack(spacing: 0) {
                    Text("Same window · fixed −60…+60").frame(height: 1)
                    HistoryChart(series, window: interval, scale: .fixed(-60...60))
                }
            case .failure(let error): Text("History unavailable: \(String(describing: error))")
            }
        }
    }
}
