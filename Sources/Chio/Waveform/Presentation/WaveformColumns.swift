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

    static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    init(samples: WaveformSamples, window: HistoryInterval, count: Int) {
        let startSeconds = Self.seconds(window.range.lowerBound - samples.start)
        let duration = Self.seconds(window.range.upperBound - window.range.lowerBound)
        let start = startSeconds * samples.rate
        let end = Self.seconds(window.range.upperBound - samples.start) * samples.rate
        func index(_ value: Double, rounding: FloatingPointRoundingRule) -> Int {
            if value <= 0 { return 0 }
            if value >= Double(samples.values.count) { return samples.values.count }
            return Int(value.rounded(rounding))
        }
        let first = index(start, rounding: .up)
        let limit = min(samples.values.count, index(end, rounding: .down) + (end >= 0 && end < Double(samples.values.count) ? 1 : 0))
        var low: Double?
        var high: Double?
        var known = 0
        var gaps = 0
        var wasGap = false
        for position in first..<max(first, limit) {
            if let value = samples.values[position] {
                low = min(low ?? value, value)
                high = max(high ?? value, value)
                known += 1
                wasGap = false
            } else {
                if !wasGap { gaps += 1 }
                wasGap = true
            }
        }
        minimum = low
        maximum = high
        knownCount = known
        gapCount = gaps
        guard count > 0 else { columns = []; return }
        guard first < limit else { columns = Array(repeating: nil, count: count); return }
        var output: [Span?] = []
        output.reserveCapacity(count)
        for column in 0..<count {
            let a = (startSeconds + Double(column) / Double(count) * duration) * samples.rate
            let b = (startSeconds + Double(column + 1) / Double(count) * duration) * samples.rate
            let lower = max(first, index(a, rounding: .up))
            let upper = min(limit, column == count - 1 ? limit : index(b, rounding: .up))
            var minimum: Double?
            var maximum: Double?
            for position in lower..<max(lower, upper) {
                if let value = samples.values[position] {
                    minimum = min(minimum ?? value, value)
                    maximum = max(maximum ?? value, value)
                }
            }
            if let minimum, let maximum {
                output.append(Span(minimum: minimum, maximum: maximum))
            } else if lower == upper, a >= Double(first), b <= Double(limit - 1), a >= 0,
                      a < Double(samples.values.count - 1) {
                let left = Int(a.rounded(.down))
                if let x = samples.values[left], let y = samples.values[left + 1] {
                    let v = Self.blend(x, y, fraction: a - Double(left))
                    let w = Self.blend(x, y, fraction: b - Double(left))
                    output.append(Span(minimum: min(v, w), maximum: max(v, w)))
                } else { output.append(nil) }
            } else { output.append(nil) }
        }
        columns = output
    }

    private static func blend(_ a: Double, _ b: Double, fraction: Double) -> Double {
        let magnitude = max(abs(a), abs(b))
        guard magnitude > 0 else { return 0 }
        let value = a / magnitude * (1 - fraction) + b / magnitude * fraction
        return min(max(a, b), max(min(a, b), min(1, max(-1, value)) * magnitude))
    }
}

extension WaveformColumns.Span: Equatable {}
extension WaveformColumns.Span: Sendable {}
