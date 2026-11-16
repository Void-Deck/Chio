struct WaveformStudyWindow {
    enum Length: String {
        case night = "8h", hour = "1h", tenMinutes = "10m", twoMinutes = "2m", thirtySeconds = "30s"
        static let ordered: [Self] = [.night, .hour, .tenMinutes, .twoMinutes, .thirtySeconds]
        var seconds: Int {
            switch self {
            case .night: 28_800
            case .hour: 3_600
            case .tenMinutes: 600
            case .twoMinutes: 120
            case .thirtySeconds: 30
            }
        }
    }
    let start: Int
    let length: Length
    // Retain the intended center when a wide window is clamped by session edges.
    let zoomCenterSecond: Int

    init(start: Int, length: Length, zoomCenterSecond: Int? = nil) {
        let fittedStart = min(max(0, start), WaveformStudyNight.seconds - length.seconds)
        self.start = fittedStart
        self.length = length
        self.zoomCenterSecond = zoomCenterSecond ?? (fittedStart + length.seconds / 2)
    }
    var end: Int { start + length.seconds }
    var clockRange: String {
        let includesSeconds = length.seconds < 600
        return "\(WaveformStudyNight.clock(start, includesSeconds: includesSeconds))–\(WaveformStudyNight.clock(end, includesSeconds: includesSeconds))"
    }
    var indices: Range<Int> { (start * WaveformStudyNight.sampleRate)..<(end * WaveformStudyNight.sampleRate) }
    func panned(_ direction: Int) -> Self { Self(start: start + direction * length.seconds / 4, length: length) }
    func zoomed(_ direction: Int) -> Self {
        guard let index = Length.ordered.firstIndex(of: length) else { return self }
        let next = Length.ordered[min(Length.ordered.count - 1, max(0, index + direction))]
        return Self(start: zoomCenterSecond - next.seconds / 2, length: next,
                    zoomCenterSecond: zoomCenterSecond)
    }
}
