import Chio
import SwiftTUI

@MainActor
struct StudyWaveform {
    enum Mode {
        case bipolar(limit: Double)
        case magnitude(lower: Double, upper: Double)
        var bounds: ClosedRange<Double> {
            switch self {
            case .bipolar(let limit): -limit...limit
            case .magnitude(let lower, let upper): lower...upper
            }
        }
    }
    let samples: [Float?]
    let indices: Range<Int>
    let mode: Mode
    let usesAbsoluteValues: Bool

    init(samples: [Float?], indices: Range<Int>, mode: Mode, usesAbsoluteValues: Bool = false) {
        self.samples = samples
        self.indices = indices
        self.mode = mode
        self.usesAbsoluteValues = usesAbsoluteValues
    }
    @Environment(\.chioStyle) private var theme
}

extension StudyWaveform: View {
    var body: some View {
        Canvas(Envelope(samples: samples, indices: indices, mode: mode, usesAbsoluteValues: usesAbsoluteValues, axisColor: theme.colors.mutedText), grid: .braille2x4)
            .foregroundStyle(theme.colors.accent)
            .accessibilityLabel("Synthetic min/max envelope; missing readings leave gaps.")
    }
}

extension StudyWaveform.Mode: Equatable {}
extension StudyWaveform.Mode: Sendable {}

private struct Envelope: CanvasDrawing {
    let samples: [Float?]
    let indices: Range<Int>
    let mode: StudyWaveform.Mode
    let usesAbsoluteValues: Bool
    let axisColor: Color

    func draw(into context: inout CanvasContext) {
        let columns = context.gridSize.width
        let rows = context.gridSize.height
        guard columns > 0, rows > 0, indices.isEmpty == false else { return }
        let bounds = mode.bounds
        func row(_ value: Double) -> Int {
            let fraction = min(1, max(0, (value - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)))
            return Int(((1 - fraction) * Double(rows - 1)).rounded())
        }
        for column in 0..<columns {
            let lower = Double(indices.lowerBound) + Double(column) * Double(indices.count) / Double(columns)
            let upper = Double(indices.lowerBound) + Double(column + 1) * Double(indices.count) / Double(columns)
            var first = Int(lower.rounded(.up))
            var end = Int(upper.rounded(.up))
            // At sub-sample zoom, include the neighbours without leaving the window.
            if upper - lower < 1 {
                first = Int(lower.rounded(.down))
                end = Int(upper.rounded(.up)) + 1
            }
            first = max(indices.lowerBound, first)
            end = min(indices.upperBound, end)
            var minimum: Double?
            var maximum: Double?
            for index in first..<max(first, end) {
                if let sample = samples[index] {
                    let value = usesAbsoluteValues ? abs(Double(sample)) : Double(sample)
                    minimum = min(minimum ?? value, value)
                    maximum = max(maximum ?? value, value)
                }
            }
            guard var low = minimum, var high = maximum else { continue }
            switch mode {
            case .bipolar: low = min(0, low); high = max(0, high)
            case .magnitude: break
            }
            let x = Double(column) / 2
            context.line(from: Point(x: x, y: Double(row(high)) / 4),
                         to: Point(x: x, y: Double(row(low)) / 4))
            switch mode {
            case .bipolar:
                // A sparse axis tint; native braille color belongs to the cell.
                if column % 16 == 0 {
                    context.setPixel(at: Point(x: x, y: Double(row(0)) / 4), foreground: axisColor)
                }
            case .magnitude: break
            }
        }
    }
}
