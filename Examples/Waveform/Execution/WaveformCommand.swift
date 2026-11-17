import Chio
import SwiftTUI

package struct WaveformCommand {
    @Option(help: "Theme: default, light or btop.") var theme: Appearance = .default
    @Option(help: "Window: 8h, 1h, 10m, 2m or 30s.") var window: WaveformWindow.Length = .twoMinutes
    @Option(help: "Window start clock HH:MM, from 22:31 through 06:30.") var start = "00:30"
    @Flag(help: "Show public HistoryChart beside the flow envelope.") var compare = false
    @Flag(help: "Print a bounded hosted raster as JSON pixels.") var capture = false
    @Option(help: "Hosted sequence: pan, zoom or events; requires --capture.") var captureSequence: CaptureSequence?
    @Option(help: "Pan sequence frame count (1...240). Zoom always emits nine frames.") var frames = 24
    @Option(help: "Animation frame delay in milliseconds (1...60000).") var delayMs = 250
    @Option var width = 120
    @Option var height = 34
    @OptionGroup package var swiftTUIOptions: SwiftTUIOptions

    package init() {}

    enum CaptureSequence: String { case pan, zoom, events }

    enum Appearance: String {
        case `default`, light, btop
        var style: ChioStyle {
            switch self {
            case .default: .default
            case .light: .light
            case .btop: .btop
            }
        }
        var next: Self {
            switch self {
            case .default: .light
            case .light: .btop
            case .btop: .default
            }
        }
    }

    private func startOffset() throws -> Int {
        let parts = start.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ $0.count == 2 && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else {
            throw ValidationError("Use a clock time in HH:MM format.")
        }
        let offset = (hour * 60 + minute - WaveformNight.startMinute + 1440) % 1440 * 60
        guard offset < WaveformNight.seconds else { throw ValidationError("Start must be inside 22:31–06:31.") }
        return offset
    }
}

extension WaveformCommand: AsyncParsableCommand {
    package mutating func validate() throws {
        guard (60...240).contains(width), (24...100).contains(height) else {
            throw ValidationError("Use 60...240 columns and 24...100 rows for capture.")
        }
        if captureSequence != nil, capture == false {
            throw ValidationError("--capture-sequence requires --capture.")
        }
        guard (1...240).contains(frames), (1...60_000).contains(delayMs) else {
            throw ValidationError("Use 1...240 frames and a delay of 1...60000 ms.")
        }
        _ = try startOffset()
    }

    @MainActor
    package mutating func run() async throws {
        let offset = try startOffset()
        let visible: WaveformWindow
        let night = WaveformNight.synthetic()
        if captureSequence == .events {
            visible = night.eventWindows[0]
        } else if captureSequence == .zoom {
            visible = WaveformWindow(start: 0, length: .night, zoomCenterSecond: offset)
        } else {
            visible = WaveformWindow(start: offset, length: window)
        }
        let view = WaveformExampleView(night: night, window: visible, appearance: theme, compare: compare)
        let application = WaveformApplication(content: view)
        if capture {
            try await WaveformCapture.export(application, width: width, height: height, style: theme.style,
                                                  sequence: captureSequence, initialWindow: visible,
                                                  frameCount: frames, delayMS: delayMs, eventWindows: night.eventWindows)
        } else {
            try await WebHostCLIRunner.run(application, configuration: swiftTUIOptions.runtimeConfiguration())
        }
    }
}

extension WaveformCommand.Appearance: ExpressibleByArgument {}
extension WaveformWindow.Length: ExpressibleByArgument {}

extension WaveformCommand.CaptureSequence: ExpressibleByArgument {}
