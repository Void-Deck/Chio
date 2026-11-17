import Foundation
import Chio

/// Entirely synthetic signals. No recording, patient data or clinical inference.
struct WaveformStudyNight {
    static let sampleRate = 25
    static let seconds = 8 * 60 * 60
    static let startMinute = 22 * 60 + 31
    let flow: [Float?]
    let pressure: [Float?]
    let events: [Event]
    let gap: Range<Int>
    let waveformFlow: Result<WaveformSamples, any Error>
    let waveformPressure: Result<WaveformSamples, any Error>
    let waveformMagnitude: Result<WaveformSamples, any Error>
    let waveformEvents: Result<[WaveformEvent], any Error>

    struct Event {
        enum Kind: String { case obstructive = "OA", hypopnea = "H", central = "CA", limitation = "FL" }
        let kind: Kind
        let seconds: Range<Int>
        var label: String { "\(kind.rawValue) \(seconds.count)s" }
    }

    static func synthetic() -> Self {
        var seed: UInt64 = 0x504E45554D41
        func random() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / 9_007_199_254_740_992
        }
        let gap = (4 * 3600)..<(4 * 3600 + 300)
        var events: [Event] = []
        var time = 240
        var ordinal = 0
        while time < seconds - 70 {
            let kind: Event.Kind
            let duration: Int
            switch ordinal % 4 {
            case 0: kind = .obstructive; duration = 12 + Int(random() * 15)
            case 1: kind = .hypopnea; duration = 18 + Int(random() * 23)
            case 2: kind = .central; duration = 10 + Int(random() * 9)
            default: kind = .limitation; duration = 30 + Int(random() * 41)
            }
            let range = time..<(time + duration)
            if range.overlaps(gap) == false { events.append(Event(kind: kind, seconds: range)) }
            time += 240 + Int(random() * 901)
            ordinal += 1
        }
        var flow: [Float?] = []
        var pressure: [Float?] = []
        flow.reserveCapacity(seconds * sampleRate)
        pressure.reserveCapacity(seconds * sampleRate)
        var phase = 0.0
        var eventIndex = 0
        for index in 0..<(seconds * sampleRate) {
            let t = Double(index) / Double(sampleRate)
            let second = index / sampleRate
            phase += 2 * .pi * (14 + 1.6 * sin(t / 310)) / 60 / Double(sampleRate)
            let breath = sin(phase)
            var value = (26.5 + 8.5 * sin(t / 173)) * breath
            while eventIndex < events.count, events[eventIndex].seconds.upperBound <= second { eventIndex += 1 }
            if eventIndex < events.count, events[eventIndex].seconds.contains(second) {
                switch events[eventIndex].kind {
                case .obstructive, .central: value *= 0.015
                case .hypopnea: value *= 0.35
                case .limitation: if value > 0 { value = min(value, 10) }
                }
            }
            value += (random() - 0.5) * 0.9
            let isGap = gap.contains(second)
            flow.append(isGap ? nil : Float(value))
            let apap = 9 + 3.8 * sin(t / 2400) + 0.7 * sin(t / 417) + 0.18 * breath
            pressure.append(isGap ? nil : Float(min(14, max(4, apap))))
        }
        let checkedEvents = events.map { event in
            let tone: WaveformEvent.Tone
            switch event.kind {
            case .obstructive, .central: tone = .error
            case .hypopnea: tone = .warning
            case .limitation: tone = .muted
            }
            return Result { try WaveformEvent(start: .seconds(event.seconds.lowerBound),
                                              duration: .seconds(event.seconds.count), label: event.label, tone: tone) }
        }
        // Synthetic construction failures remain visible through the plot's result.
        let eventResult = Result { try checkedEvents.map { try $0.get() } }
        let waveformFlow = Result {
            _ = try eventResult.get()
            return try WaveformSamples(start: .zero, rate: Double(sampleRate), values: flow.map { $0.map(Double.init) })
        }
        return Self(flow: flow, pressure: pressure, events: events, gap: gap,
                    waveformFlow: waveformFlow,
                    waveformPressure: Result { try WaveformSamples(start: .zero, rate: Double(sampleRate), values: pressure.map { $0.map(Double.init) }) },
                    waveformMagnitude: Result { try WaveformSamples(start: .zero, rate: Double(sampleRate), values: flow.map { $0.map { abs(Double($0)) } }) },
                    waveformEvents: eventResult)
    }

    static func clock(_ offset: Int, includesSeconds: Bool = false) -> String {
        let minute = (startMinute + offset / 60) % (24 * 60)
        if includesSeconds {
            return String(format: "%02d:%02d:%02d", minute / 60, minute % 60, offset % 60)
        }
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}


extension WaveformStudyNight {
    func pressureBounds(in indices: Range<Int>) -> ClosedRange<Double>? {
        var minimum: Double?
        var maximum: Double?
        for index in indices {
            guard let value = pressure[index] else { continue }
            let reading = Double(value)
            minimum = min(minimum ?? reading, reading)
            maximum = max(maximum ?? reading, reading)
        }
        guard let minimum, let maximum else { return nil }
        return floor(minimum - 0.5)...ceil(maximum + 0.5)
    }

    /// Density means event starts per ten minutes, with the earliest window winning ties.
    var eventStudyWindows: [WaveformStudyWindow] {
        let ordered = events.sorted { $0.seconds.lowerBound < $1.seconds.lowerBound }
        var bestStart = 0
        var bestCount = 0
        var end = 0
        var lower = 0
        for first in ordered.indices {
            let start = min(ordered[first].seconds.lowerBound, Self.seconds - 600)
            while end < ordered.count, ordered[end].seconds.lowerBound < start + 600 { end += 1 }
            while lower < ordered.count, ordered[lower].seconds.lowerBound < start { lower += 1 }
            let count = end - lower
            if count > bestCount { bestStart = start; bestCount = count }
        }
        let cluster = ordered.filter { (bestStart..<(bestStart + 600)).contains($0.seconds.lowerBound) }
        let center: Int
        if cluster.isEmpty {
            center = bestStart + 300
        } else {
            let event = cluster[cluster.count / 2]
            center = event.seconds.lowerBound + event.seconds.count / 2
        }
        return [WaveformStudyWindow(start: 0, length: .night),
                WaveformStudyWindow(start: bestStart, length: .tenMinutes),
                WaveformStudyWindow(start: center - 60, length: .twoMinutes)]
    }

    func nextEventStudyWindow(after window: WaveformStudyWindow) -> WaveformStudyWindow {
        let windows = eventStudyWindows
        switch window.length {
        case .night: return windows[1]
        case .tenMinutes: return windows[2]
        case .hour, .twoMinutes, .thirtySeconds: return windows[0]
        }
    }
}
