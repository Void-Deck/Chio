import SwiftTUI

struct DotMatrixDrawing {
    let frame: DotMatrixFrame
    let style: DotMatrixStyle
}

extension DotMatrixDrawing: CanvasDrawing {
    func draw(into context: inout CanvasContext) {
        // A blank column between dots approximates square pitch with tall cells.
        // Logical coordinates never stretch to the parent's available space.
        for (y, row) in frame.rows.enumerated() {
            for (x, dot) in row.enumerated() {
                switch dot {
                case .off:
                    context.setCell(at: CellPoint(x: x * 2, y: y), character: "·",
                                    foreground: style.unlitColor)
                case .on(let color):
                    context.setCell(at: CellPoint(x: x * 2, y: y), character: style.shape.glyph,
                                    foreground: color)
                }
            }
        }
    }
}
