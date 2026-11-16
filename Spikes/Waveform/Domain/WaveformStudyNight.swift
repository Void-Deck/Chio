import Foundation

/// Entirely synthetic signals. No recording, patient data or clinical inference.
struct WaveformStudyNight {
    static let sampleRate = 25
    static let seconds = 8 * 60 * 60
    static let startMinute = 22 * 60 + 31
    let flow: [Float?]
    let pressure: [Float?]
    let events: [Event]
    let gap: Range<Int>

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
        return Self(flow: flow, pressure: pressure, events: events, gap: gap)
    }

    static func clock(_ offset: Int, includesSeconds: Bool = false) -> String {
        let minute = (startMinute + offset / 60) % (24 * 60)
        if includesSeconds {
            return String(format: "%02d:%02d:%02d", minute / 60, minute % 60, offset % 60)
        }
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}
