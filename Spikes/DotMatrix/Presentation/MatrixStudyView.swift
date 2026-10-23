import Chio
import SwiftTUI

@MainActor
struct MatrixStudyView {
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

    @Environment(\.terminalSize) private var terminalSize
    @Environment(\.requestTermination) private var requestTermination
    @State private var playback: Playback = .paused(.first)
    @State private var palette: MatrixScene.Palette = .amber
    @State private var shape: DotMatrixStyle.Shape = .round
    let scene: MatrixScene

    init(scene: MatrixScene) { self.scene = scene }

    private var matrixStyle: DotMatrixStyle {
        DotMatrixStyle(unlitColor: palette.unlit, shape: shape)
    }

    private var isCompact: Bool { terminalSize.height < 26 || terminalSize.width < 50 }
    private var isTiny: Bool { terminalSize.height < 22 || terminalSize.width < 32 }

    private var lettering: some View {
        VStack(alignment: .leading, spacing: 1) {
            if !isCompact {
                Text("lettering  /  23 × 7").foregroundStyle(ChioStyle.btop.colors.secondaryText)
            }
            DotMatrix(frame: scene.lettering(for: palette), style: matrixStyle, label: "CHIO")
                .frame(maxWidth: .infinity)
                .frame(height: isTiny ? 1 : nil)
        }
    }

    @ViewBuilder private var icon: some View {
        if isTiny {
            VStack(alignment: .leading, spacing: 1) {
                DotMatrix(frame: scene.icon(at: playback.frame), style: matrixStyle, label: "Beating heart")
                    .frame(height: 1)
                Text("frame \(playback.frame.rawValue + 1) / 4 · \(playback.isPlaying ? "playing" : "paused")")
            }
        } else { expandedIcon }
    }

    private var expandedIcon: some View {
        HStack(alignment: .center, spacing: 3) {
            DotMatrix(frame: scene.icon(at: playback.frame), style: matrixStyle, label: "Beating heart")
            VStack(alignment: .leading, spacing: 1) {
                Text("frame \(playback.frame.rawValue + 1) / 4").bold()
                Text(playback.isPlaying ? "playing" : "paused").foregroundStyle(palette.lit)
                if !isCompact {
                    Text("8 × 8 • two colours").foregroundStyle(ChioStyle.btop.colors.secondaryText)
                    Text("Same view. New frame.").foregroundStyle(ChioStyle.btop.colors.mutedText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: isTiny ? 0 : 1) {
            HStack {
                Text("chio / dot matrix").bold().foregroundStyle(palette.lit)
                if !isCompact {
                    Spacer(minLength: 1)
                    Text("visual study").foregroundStyle(ChioStyle.btop.colors.mutedText)
                }
            }
            Text("\(palette.rawValue) · \(shape.rawValue)")
                .foregroundStyle(ChioStyle.btop.colors.secondaryText)
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
        .style(.btop)
    }

    private var hints: some View {
        KeyHints {
            KeyHint("space", "play")
            KeyHint("→", "step")
            KeyHint("t", "colour")
            KeyHint("s", "dots")
            KeyHint("q", "quit")
        }
    }
}

extension MatrixStudyView: View {
    var body: some View {
        content
            .focusable()
            .onKeyPress { press in
                guard press.modifiers.isEmpty else { return .ignored }
                switch press.key {
                case .character("q"): _ = requestTermination()
                case .character("t"): palette = palette.next
                case .character("s"): shape = shape.next
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
