import Foundation

/// Arithmetic index admission and streaming extrema; storage is proportional to columns.
struct WaveformColumns {
    struct Span {
        let minimum: Double
        let maximum: Double
    }
    let columns: [Span?]
    let minimum: Double?
    let maximum: Double?
    let knownCount: Int
    let gapCount: Int

    init(samples: WaveformSamples, window: HistoryInterval, count: Int) {
        let windowStartSeconds = WaveformTime.seconds(window.range.lowerBound - samples.start)
        let windowDurationSeconds = WaveformTime.seconds(window.range.upperBound - window.range.lowerBound)
        let windowStartPosition = windowStartSeconds * samples.rate
        let windowEndPosition = WaveformTime.seconds(window.range.upperBound - samples.start) * samples.rate
        func sampleIndex(at position: Double, rounding: FloatingPointRoundingRule) -> Int {
            // Saturate even infinite products before conversion. The admitted
            // sample count bounds every converted position to at most 2,097,152.
            if position <= 0 { return 0 }
            if position >= Double(samples.values.count) { return samples.values.count }
            return Int(position.rounded(rounding))
        }
        let firstSampleIndex = sampleIndex(at: windowStartPosition, rounding: .up)
        let isEndNonnegative = windowEndPosition >= 0
        let isEndBeforeSampleLimit = windowEndPosition < Double(samples.values.count)
        let includesEndSample = isEndNonnegative && isEndBeforeSampleLimit
        let endSampleIndex = sampleIndex(at: windowEndPosition, rounding: .down)
        let sampleLimit = min(samples.values.count, endSampleIndex + (includesEndSample ? 1 : 0))
        var windowMinimum: Double?
        var windowMaximum: Double?
        var known = 0
        var gaps = 0
        var wasGap = false
        for sampleIndex in firstSampleIndex..<max(firstSampleIndex, sampleLimit) {
            if let value = samples.values[sampleIndex] {
                windowMinimum = min(windowMinimum ?? value, value)
                windowMaximum = max(windowMaximum ?? value, value)
                known += 1
                wasGap = false
            } else {
                if !wasGap { gaps += 1 }
                wasGap = true
            }
        }
        minimum = windowMinimum
        maximum = windowMaximum
        knownCount = known
        gapCount = gaps
        guard count > 0 else { columns = []; return }
        guard firstSampleIndex < sampleLimit else { columns = Array(repeating: nil, count: count); return }
        var output: [Span?] = []
        output.reserveCapacity(count)
        for column in 0..<count {
            let columnStartPosition = (windowStartSeconds + Double(column) / Double(count) * windowDurationSeconds) * samples.rate
            let columnEndPosition = (windowStartSeconds + Double(column + 1) / Double(count) * windowDurationSeconds) * samples.rate
            let firstColumnSampleIndex = max(firstSampleIndex, sampleIndex(at: columnStartPosition, rounding: .up))
            let columnSampleLimit = min(sampleLimit, column == count - 1 ? sampleLimit : sampleIndex(at: columnEndPosition, rounding: .up))
            var columnMinimum: Double?
            var columnMaximum: Double?
            for sampleIndex in firstColumnSampleIndex..<max(firstColumnSampleIndex, columnSampleLimit) {
                if let value = samples.values[sampleIndex] {
                    columnMinimum = min(columnMinimum ?? value, value)
                    columnMaximum = max(columnMaximum ?? value, value)
                }
            }
            let hasNoSample = firstColumnSampleIndex == columnSampleLimit
            let startsInsideWindowSamples = columnStartPosition >= Double(firstSampleIndex)
            let endsInsideWindowSamples = columnEndPosition <= Double(sampleLimit - 1)
            let hasLeftNeighbour = columnStartPosition >= 0
            let hasRightNeighbour = columnStartPosition < Double(samples.values.count - 1)
            let canInterpolate = hasNoSample && startsInsideWindowSamples && endsInsideWindowSamples
                && hasLeftNeighbour && hasRightNeighbour
            if let columnMinimum, let columnMaximum {
                output.append(Span(minimum: columnMinimum, maximum: columnMaximum))
            } else if canInterpolate {
                let leftSampleIndex = sampleIndex(at: columnStartPosition, rounding: .down)
                if let leftValue = samples.values[leftSampleIndex], let rightValue = samples.values[leftSampleIndex + 1] {
                    let startValue = Self.blend(leftValue, rightValue, fraction: columnStartPosition - Double(leftSampleIndex))
                    let endValue = Self.blend(leftValue, rightValue, fraction: columnEndPosition - Double(leftSampleIndex))
                    output.append(Span(minimum: min(startValue, endValue), maximum: max(startValue, endValue)))
                } else { output.append(nil) }
            } else { output.append(nil) }
        }
        columns = output
    }

    private static func blend(_ leftValue: Double, _ rightValue: Double, fraction: Double) -> Double {
        let magnitude = max(abs(leftValue), abs(rightValue))
        guard magnitude > 0 else { return 0 }
        let blendedValue = leftValue / magnitude * (1 - fraction) + rightValue / magnitude * fraction
        return min(max(leftValue, rightValue), max(min(leftValue, rightValue), min(1, max(-1, blendedValue)) * magnitude))
    }
}

extension WaveformColumns.Span: Equatable {}
extension WaveformColumns.Span: Sendable {}
