import Chio
import SwiftTUI

@MainActor
struct MatrixExampleView {
    private enum Playback {
        case paused(MatrixScene.Frame)
        case playing(MatrixScene.Frame)

        var frame: MatrixScene.Frame {
            switch self {
            case .paused(let frame), .playing(let frame): frame
            }
        }

        var isPlaying: Bool {
            switch self {
            case .paused: false
            case .playing: true
            }
        }
    }

    @Environment(\.chioStyle) private var theme
    @Environment(\.terminalSize) private var terminalSize
    @Environment(\.requestTermination) private var requestTermination
    @State private var playback: Playback = .paused(.first)
    @State private var palette: MatrixScene.Palette = .amber
    @State private var shape: DotMatrixStyle.Shape = .round
    @State private var gaps: MatrixGaps = .regular
    @State private var intensity: MatrixScene.Intensity = .full
    let scene: MatrixScene

    init(scene: MatrixScene) { self.scene = scene }

    private var accent: Color {
        switch palette {
        case .amber: Color(hexRGB: 0xFFBC55)
        case .green: Color(hexRGB: 0x85F3B3)
        }
    }

    private var shapeName: String {
        switch shape {
        case .round: "round"
        case .square: "square"
        }
    }

    private var matrixStyle: DotMatrixStyle {
        scene.style(shape: shape, gaps: gaps)
    }

    // Open spacing gives the image more rows; use compact chrome to retain controls.
    private var isCompact: Bool {
        terminalSize.height < 26 || terminalSize.width < 50 || gaps == .open
    }
    private var isTiny: Bool { terminalSize.height < 22 || terminalSize.width < 32 }

    private var lettering: some View {
        VStack(alignment: .leading, spacing: 1) {
            if !isCompact {
                Text("lettering  /  23 × 7").foregroundStyle(theme.colors.secondaryText)
            }
            DotMatrix(frame: scene.lettering(for: palette, intensity: intensity), label: "CHIO")
                .frame(maxWidth: .infinity)
                .frame(height: isTiny ? 1 : nil)
        }
    }

    @ViewBuilder private var icon: some View {
        if isTiny {
            VStack(alignment: .leading, spacing: 1) {
                DotMatrix(frame: scene.icon(at: playback.frame, intensity: intensity), label: "Beating heart")
                    .frame(height: 1)
                Text("frame \(playback.frame.rawValue + 1) / 4 · \(playback.isPlaying ? "playing" : "paused")")
            }
        } else { expandedIcon }
    }

    private var expandedIcon: some View {
        HStack(alignment: .center, spacing: 3) {
            DotMatrix(frame: scene.icon(at: playback.frame, intensity: intensity), label: "Beating heart")
            VStack(alignment: .leading, spacing: 1) {
                Text("frame \(playback.frame.rawValue + 1) / 4").bold()
                Text(playback.isPlaying ? "playing" : "paused").foregroundStyle(accent)
                if !isCompact {
                    Text("8 × 8 • two colours").foregroundStyle(theme.colors.secondaryText)
                    Text("Same view. New frame.").foregroundStyle(theme.colors.mutedText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: isTiny ? 0 : 1) {
            HStack {
                Text("chio / dot matrix").bold().foregroundStyle(accent)
                if !isCompact {
                    Spacer(minLength: 1)
                    Text("fixed-pitch frames").foregroundStyle(theme.colors.mutedText)
                }
            }
            Text("\(palette.rawValue) · \(shapeName) · intensity \(intensity.label) · gaps \(gaps.horizontal),\(gaps.vertical)")
                .foregroundStyle(theme.colors.secondaryText)
            if isCompact {
                lettering
                icon
            } else {
                GroupBox { lettering }
                GroupBox { icon }
            }
            Spacer(minLength: 0)
            if isTiny { hints }
            else { StatusBar { hints } }
        }
        .padding(1)
        .frame(maxWidth: 80, maxHeight: .infinity, alignment: .topLeading)
        .frame(width: terminalSize.width, height: terminalSize.height, alignment: .top)
        .dotMatrixStyle(matrixStyle)
    }

    private var hints: some View {
        KeyHints {
            KeyHint("space", "play")
            KeyHint("→", "step")
            KeyHint("t", "colour")
            KeyHint("s", "dots")
            KeyHint("g", "gaps")
            KeyHint("i", "intensity")
            KeyHint("q", "quit")
        }
    }
}

extension MatrixExampleView: View {
    var body: some View {
        content
            .focusable()
            .onKeyPress { press in
                guard press.modifiers.isEmpty else { return .ignored }
                switch press.key {
                case .character("q"): _ = requestTermination()
                case .character("t"): palette = palette.next
                case .character("s"):
                    switch shape {
                    case .round: shape = .square
                    case .square: shape = .round
                    }
                case .character("g"): gaps = gaps.next
                case .character("i"): intensity = intensity.next
                case .arrowRight: playback = .paused(playback.frame.next)
                case .space:
                    switch playback {
                    case .paused(let frame): playback = .playing(frame)
                    case .playing(let frame): playback = .paused(frame)
                    }
                default: return .ignored
                }
                return .handled
            }
            .task(id: playback.isPlaying) {
                // This example owns scheduling. The matrix only presents a frame.
                guard playback.isPlaying else { return }
                do {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .milliseconds(300))
                        try Task.checkCancellation()
                        switch playback {
                        case .paused: return
                        case .playing(let frame): playback = .playing(frame.next)
                        }
                    }
                } catch is CancellationError {
                    // Native task cancellation ends playback on pause or exit.
                } catch {
                    playback = .paused(playback.frame)
                }
            }
    }
}
