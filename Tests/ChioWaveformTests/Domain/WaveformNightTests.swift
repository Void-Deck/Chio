@testable import WaveformExample
import Testing

/// Supplementary implementer checks; no live or clinical data.
struct WaveformNightTests {
    @Test func syntheticNight() throws {
        let night = WaveformNight.synthetic()
        #expect(night.flow.count == 720_000)
        #expect(night.pressure.count == 720_000)
        #expect(night.gap == 14_400..<14_700)
        #expect(night.flow[360_000..<367_500].allSatisfy { $0 == nil })
        #expect(night.pressure[360_000..<367_500].allSatisfy { $0 == nil })
        #expect(night.flow[359_999] != nil)
        #expect(night.flow[367_500] != nil)
        #expect(night.pressure.compactMap { $0 }.allSatisfy { (4...14).contains($0) })
        #expect(night.pressureBounds(in: 360_000..<367_500) == nil)
        #expect(night.events.isEmpty == false)
        #expect(night.events.allSatisfy { !$0.seconds.overlaps(14_400..<14_700) })
        #expect(try night.waveformFlow.get().values.count == 720_000)
        #expect(try night.waveformPressure.get().values[360_000] == nil)
        #expect(try night.waveformMagnitude.get().values.compactMap { $0 }.allSatisfy { $0 >= 0 })
        #expect(try night.waveformEvents.get().count == night.events.count)
        #expect(WaveformNight.clock(28_800) == "06:31")
        let windows = night.eventWindows
        #expect(windows.map(\.length) == [.night, .tenMinutes, .twoMinutes])
        #expect(night.nextEventWindow(after: windows[2]).length == .night)
    }
}
