import Chio
import Foundation
import SwiftTUI

/// Bounded native hosted captures. Animation delays belong to the exported document.
@MainActor
enum WaveformStudyCapture {
    static func export(_ application: WaveformStudyApplication, width: Int, height: Int, style: ChioStyle,
                       sequence: WaveformStudyCommand.CaptureSequence?, initialWindow: WaveformStudyWindow,
                       frameCount: Int, delayMS: Int) async throws {
        let recorder = Recorder(size: CellSize(width: width, height: height))
        recorder.prepare(after: nil, window: initialWindow)
        let surface = HostedRasterSurface(surfaceSize: recorder.size, appearance: .fallback,
                                          onFrame: { recorder.receive($0) })
        let session = try HostedSceneSession(for: application, sceneID: WindowIdentifier("Waveform study"), surface: surface)
        let run = Task { try await session.start() }
        let outcome: Result<[Frame], any Error>
        do {
            var current = try await recorder.wait(frameNumber: 1)
            var frames = [Frame(delayMS: delayMS, cells: pixels(current.raster, style: style))]
            var window = initialWindow
            if let sequence {
                switch sequence {
                case .pan:
                    var direction = 1
                    for number in 1..<frameCount {
                        var next = window.panned(direction)
                        if next.start == window.start {
                            direction = -direction
                            next = window.panned(direction)
                        }
                        recorder.prepare(after: current.sequence, window: next)
                        session.send(.key(direction > 0 ? .arrowRight : .arrowLeft))
                        // A whole-night window cannot move. Still send the real key,
                        // then request a new public frame for that unchanged window.
                        if next.start == window.start { session.requestSurfaceRefresh() }
                        current = try await recorder.wait(frameNumber: number + 1)
                        frames.append(Frame(delayMS: delayMS, cells: pixels(current.raster, style: style)))
                        window = next
                    }
                case .zoom:
                    for number in 1..<WaveformStudyWindow.Length.ordered.count {
                        let next = window.zoomed(1)
                        recorder.prepare(after: current.sequence, window: next)
                        session.send(.key(.character("+")))
                        current = try await recorder.wait(frameNumber: number + 1)
                        frames.append(Frame(delayMS: delayMS, cells: pixels(current.raster, style: style)))
                        window = next
                    }
                    let final = Frame(delayMS: delayMS, cells: pixels(current.raster, style: style))
                    frames.append(contentsOf: Array(repeating: final, count: 4))
                }
            }
            outcome = .success(frames)
        } catch { outcome = .failure(error) }
        session.stop()
        let termination = await run.result
        let frames = try outcome.get()
        _ = try termination.get()
        let data: Data
        if sequence != nil {
            data = try JSONEncoder().encode(FrameDocument(frames: frames))
        } else if let first = frames.first {
            data = try JSONEncoder().encode(first.cells)
        } else {
            throw CaptureError.emptyCapture
        }
        print(String(decoding: data, as: UTF8.self))
    }

    private static func pixels(_ raster: RasterSurface, style: ChioStyle) -> [[Pixel]] {
        raster.cells.map { row in
            row.map { cell in
                Pixel(character: String(cell.character), foreground: cell.style?.foregroundColor ?? style.colors.foreground,
                      background: cell.style?.backgroundColor ?? style.colors.surface)
            }
        }
    }

    @MainActor
    private final class Recorder {
        let size: CellSize
        private var captured: SemanticHostFrame?
        private var after: UInt64?
        private var expectedHeader = ""

        init(size: CellSize) { self.size = size }

        func prepare(after sequence: UInt64?, window: WaveformStudyWindow) {
            captured = nil
            after = sequence
            expectedHeader = "\(window.clockRange) · \(window.length.rawValue)"
        }

        func receive(_ frame: SemanticHostFrame) {
            if let after, frame.sequence <= after { return }
            let text = frame.raster.lines.joined(separator: "\n")
            let hasExpectedSize = frame.raster.size == size
            let hasHeader = text.contains("pneuma study") && text.contains(expectedHeader)
            let hasRaster = text.unicodeScalars.contains { (0x2801...0x28FF).contains($0.value) }
            // The study's root is its only native focus region. Do not send the
            // next key until native focus and the completed raster arrive together.
            let hasFocus = frame.focusedIdentity != nil
            guard captured == nil, hasExpectedSize, hasHeader, hasRaster, hasFocus else { return }
            captured = frame
        }

        func wait(frameNumber: Int) async throws -> SemanticHostFrame {
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while ContinuousClock.now < deadline {
                try Task.checkCancellation()
                if let captured { return captured }
                try await Task.sleep(for: .milliseconds(5))
            }
            throw CaptureError.frameTimeout(number: frameNumber, header: expectedHeader)
        }
    }

    private enum CaptureError: Error, CustomStringConvertible {
        case frameTimeout(number: Int, header: String)
        case emptyCapture
        var description: String {
            switch self {
            case .frameTimeout(let number, let header):
                "Capture frame \(number) timed out after 10 seconds waiting for header '\(header)' and braille with native study focus."
            case .emptyCapture: "Capture produced no frames."
            }
        }
    }
    private struct FrameDocument: Encodable { let frames: [Frame] }
    private struct Frame: Encodable {
        let delayMS: Int
        let cells: [[Pixel]]
    }
    private struct Pixel: Encodable {
        let character: String
        let foreground: Color
        let background: Color
    }
}
