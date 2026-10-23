import SwiftTUI

/// Internal experiment: complete fixed-pitch frame or an authored text fallback.
struct DotMatrix {
    let frame: DotMatrixFrame
    let style: DotMatrixStyle
    let label: String
}

extension DotMatrix: View {
    var body: some View {
        ViewThatFits {
            Canvas(DotMatrixDrawing(frame: frame, style: style), grid: .fullCell)
                .frame(width: frame.cellWidth, height: frame.height)
                .fixedSize()
            Text(verbatim: label)
        }
        .accessibilityLabel(label)
    }
}
