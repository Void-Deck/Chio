import SwiftTUIViews

/// A passive fixed-pitch LED image with an authored accessible text fallback.
///
/// Every LED occupies its own terminal cell. The complete matrix must fit;
/// otherwise native text presents `label`. A drawing above 262,144 terminal
/// cells, including gaps, also uses that fallback before constructing a Canvas.
/// Applications own image generation, animation, clocks and interaction.
@MainActor
public struct DotMatrix {
    @Environment(\.chioStyle) private var theme
    @Environment(\.dotMatrixStyle) private var style
    private let frame: DotMatrixFrame
    private let label: String

    public init(frame: DotMatrixFrame, label: String) {
        self.frame = frame
        self.label = label
    }

    private var drawingSize: CellSize? {
        // Frame and gap construction bound each operand before arithmetic.
        let width = frame.columns + (frame.columns - 1) * style.horizontalGap
        let height = frame.height + (frame.height - 1) * style.verticalGap
        guard width <= 262_144 / height else { return nil }
        return CellSize(width: width, height: height)
    }
}

extension DotMatrix: View {
    public var body: some View {
        Group {
            if let size = drawingSize {
                ViewThatFits {
                    Canvas(DotMatrixDrawing(frame: frame, style: style,
                                            unlitColor: style.unlitColor ?? theme.colors.mutedText),
                           grid: .fullCell)
                        .frame(width: size.width, height: size.height)
                        .fixedSize()
                    Text(verbatim: label)
                }
            } else {
                Text(verbatim: label)
            }
        }
        .accessibilityLabel(label)
    }
}

private struct DotMatrixDrawing {
    let frame: DotMatrixFrame
    let style: DotMatrixStyle
    let unlitColor: Color
}

extension DotMatrixDrawing: CanvasDrawing {
    func draw(into context: inout CanvasContext) {
        for (rowIndex, row) in frame.rows.enumerated() {
            for (columnIndex, dot) in row.enumerated() {
                let point = CellPoint(x: columnIndex * (style.horizontalGap + 1),
                                      y: rowIndex * (style.verticalGap + 1))
                let hasColor = dot.x > 0 || dot.y > 0 || dot.z > 0
                let hasIntensity = dot.w > 0
                if hasColor && hasIntensity {
                    // Scale encoded channels in Double to retain tiny Float inputs.
                    let intensity = Double(dot.w)
                    let color = Color(red: Double(dot.x) * intensity, green: Double(dot.y) * intensity,
                                      blue: Double(dot.z) * intensity)
                    context.setCell(at: point, character: style.shape.glyph, foreground: color)
                } else {
                    context.setCell(at: point, character: "·", foreground: unlitColor)
                }
            }
        }
    }
}
