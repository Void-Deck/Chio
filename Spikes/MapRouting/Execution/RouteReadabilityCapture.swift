import Chio
import Foundation
import SwiftTUI

/// A bounded native hosted capture. PNG rendering is a separate inspection step.
@MainActor
enum RouteReadabilityCapture {
    static func export(_ application: RouteReadabilityApplication, width: Int, height: Int, style: ChioStyle) async throws {
        let recorder = Recorder(size: CellSize(width: width, height: height))
        let surface = HostedRasterSurface(surfaceSize: recorder.size, appearance: .fallback,
                                          onFrame: { recorder.receive($0) })
        let session = try HostedSceneSession(for: application, sceneID: WindowIdentifier("Route readability"), surface: surface)
        let run = Task { try await session.start() }
        let outcome: Result<RasterSurface, any Error>
        do { outcome = .success(try await recorder.wait()) }
        catch { outcome = .failure(error) }
        session.stop()
        let termination = await run.result
        let raster = try outcome.get()
        _ = try termination.get()
        let pixels = raster.cells.map { row in
            row.map { cell in
                Pixel(character: String(cell.character), foreground: cell.style?.foregroundColor ?? style.colors.foreground,
                      background: cell.style?.backgroundColor ?? style.colors.surface)
            }
        }
        print(String(decoding: try JSONEncoder().encode(pixels), as: UTF8.self))
    }

    @MainActor
    private final class Recorder {
        let size: CellSize
        private var raster: RasterSurface?

        init(size: CellSize) { self.size = size }

        func receive(_ frame: SemanticHostFrame) {
            let text = frame.raster.lines.joined(separator: "\n")
            let hasExpectedSize = frame.raster.size == size
            let isPreparing = text.contains("Preparing map")
            let hasHeader = text.contains("route readability")
            let hasRaster = text.unicodeScalars.contains { (0x2801...0x28FF).contains($0.value) }
            let hasFallback = text.contains("More room for the map")
            guard raster == nil, hasExpectedSize, hasHeader, !isPreparing, hasRaster || hasFallback else { return }
            raster = frame.raster
        }

        func wait() async throws -> RasterSurface {
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while ContinuousClock.now < deadline {
                try Task.checkCancellation()
                if let raster { return raster }
                try await Task.sleep(for: .milliseconds(5))
            }
            throw CaptureError.frameTimeout
        }
    }

    private enum CaptureError: Error { case frameTimeout }
    private struct Pixel: Encodable {
        let character: String
        let foreground: Color
        let background: Color
    }
}
