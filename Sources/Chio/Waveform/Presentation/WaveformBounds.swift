import Foundation

/// Pure scale resolution and overflow-safe dot-row mapping.
struct WaveformBounds {
    let lower: Double
    let upper: Double
    private let divisor: Double

    init(scale: WaveformScale, mode: WaveformMode, columns: WaveformColumns) {
        switch scale.bounds {
        case .fixed(let lower, let upper):
            self.lower = lower
            self.upper = upper
            divisor = 1
        case .automatic(let padding):
            let minimum = columns.minimum ?? 0
            let maximum = columns.maximum ?? 0
            let rawLower = minimum - padding
            let rawUpper = maximum + padding
            let needsNormalization = !rawLower.isFinite || !rawUpper.isFinite
            divisor = needsNormalization ? 2 : 1
            // Normalized arithmetic preserves bounds beyond Double's finite range.
            // At those magnitudes each representable value is already a whole unit.
            var low = needsNormalization ? minimum / 2 - padding / 2 : floor(rawLower)
            var high = needsNormalization ? maximum / 2 + padding / 2 : ceil(rawUpper)
            switch mode {
            case .bipolar: low = min(0, low); high = max(0, high)
            case .magnitude: break
            }
            if low == high { low -= 1; high += 1 }
            lower = low
            upper = high
        }
    }

    func row(_ value: Double, height: Int) -> Int {
        guard height > 1 else { return 0 }
        let value = value / divisor
        if value <= lower { return height - 1 }
        if value >= upper { return 0 }
        let magnitude = max(abs(lower), abs(upper))
        guard lower < upper, magnitude > 0 else { return (height - 1) / 2 }
        let span = upper - lower
        // Use the specified formula exactly; normalize only when the span overflows.
        let fraction = span.isFinite
            ? (upper - value) / span
            : (upper / magnitude - value / magnitude) / (upper / magnitude - lower / magnitude)
        return min(height - 1, max(0, Int((fraction * Double(height - 1)).rounded())))
    }
}

extension WaveformBounds: Equatable {}
extension WaveformBounds: Sendable {}
