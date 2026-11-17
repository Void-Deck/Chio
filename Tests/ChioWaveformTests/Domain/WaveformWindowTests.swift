@testable import WaveformExample
import Testing

/// Supplementary implementer checks for application-owned navigation.
struct WaveformWindowTests {
    @Test func fittingAndPan() {
        #expect(WaveformWindow(start: -100, length: .twoMinutes).start == 0)
        let end = WaveformWindow(start: 28_800, length: .twoMinutes)
        #expect(end.start == 28_680)
        #expect(end.end == 28_800)
        #expect(end.panned(1).start == 28_680)
        let window = WaveformWindow(start: 600, length: .twoMinutes)
        #expect(window.panned(1).start == 630)
        #expect(window.panned(-1).start == 570)
        #expect(window.start == 600)
        #expect(window.indices == 15_000..<18_000)
    }

    @Test func zoomRetainsCenterAtEdges() {
        let night = WaveformWindow(start: 0, length: .night, zoomCenterSecond: 7140)
        let hour = night.zoomed(1)
        let ten = hour.zoomed(1)
        let two = ten.zoomed(1)
        #expect(hour.start == 5340)
        #expect(ten.start == 6840)
        #expect(two.start == 7080)
        #expect(two.clockRange == "00:29:00–00:31:00")
        #expect(two.zoomed(-1).start == 6840)
        #expect(night.zoomed(-1).length == .night)
        #expect(WaveformWindow(start: 0, length: .thirtySeconds).zoomed(1).length == .thirtySeconds)
    }
}
