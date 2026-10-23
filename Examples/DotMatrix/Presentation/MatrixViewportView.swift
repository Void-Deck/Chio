import Chio
import SwiftTUI

/// Native scrolling owns offsets, clipping, focus, arrows and Home/End.
@MainActor
struct MatrixViewportView {
    @Environment(\.terminalSize) private var terminalSize
    @Environment(\.requestTermination) private var requestTermination
    @Environment(\.chioStyle) private var theme
    @State private var position = ScrollCellOffset.zero
    @FocusState private var isMatrixFocused: Bool
    let frame: DotMatrixFrame

    private var hints: some View {
        KeyHints {
            KeyHint("↑↓←→", "scroll")
            KeyHint("home/end", "jump")
            KeyHint("q", "quit")
        }
    }
}

extension MatrixViewportView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("chio / matrix viewport").bold().foregroundStyle(theme.colors.accent)
            Text("64 × 40 RGB dots · native two-axis scrolling")
                .foregroundStyle(theme.colors.secondaryText)
            ScrollView([.horizontal, .vertical], position: $position) {
                DotMatrix(frame: frame, label: "RGB gradient")
                    .frame(width: frame.columns * 2 - 1, height: frame.height)
            }
            .focused($isMatrixFocused)
            .defaultFocus($isMatrixFocused, true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text("Row \(position.y + 1) · Col \(position.x + 1)")
                .foregroundStyle(theme.colors.secondaryText)
            hints
        }
        .padding(1)
        .frame(width: terminalSize.width, height: terminalSize.height, alignment: .topLeading)
        .onKeyPress { press in
            guard press.modifiers.isEmpty, press.key == .character("q") else { return .ignored }
            _ = requestTermination()
            return .handled
        }
    }
}
