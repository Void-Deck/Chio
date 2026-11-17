import Chio
import Testing

struct WaveformEventSpecTests {
    private typealias Failure = WaveformEvent.ValidationError
    private static let limit = Duration.seconds(Int64.max)
    private static let attosecond = Duration(secondsComponent: 0, attosecondsComponent: 1)

    @Test("Events retain start, duration, label and tone")
    func storedValues() throws {
        let event = try WaveformEvent(start: .seconds(90), duration: .milliseconds(12_500), label: "OA", tone: .warning)
        #expect(event.start == .seconds(90))
        #expect(event.duration == .milliseconds(12_500))
        #expect(event.label == "OA")
        #expect(event.tone == .warning)
        let same = try WaveformEvent(start: .seconds(90), duration: .milliseconds(12_500), label: "OA", tone: .warning)
        let other = try WaveformEvent(start: .seconds(90), duration: .milliseconds(12_500), label: "OA", tone: .error)
        #expect(event == same)
        #expect(Set([event, same, other]).count == 2)
    }

    @Test("Tones are muted, warning and error")
    func tones() {
        #expect(WaveformEvent.Tone.allCases == [.muted, .warning, .error])
    }

    @Test("Start bounds match samples: zero through the Int64 second limit")
    func startBounds() throws {
        #expect(try WaveformEvent(start: .zero, duration: Self.attosecond, label: "A", tone: .muted).start == .zero)
        #expect(try WaveformEvent(start: Self.limit, duration: .seconds(1), label: "A", tone: .muted).start == Self.limit)
        #expect(throws: Failure.startOutOfRange) {
            try WaveformEvent(start: .zero - Self.attosecond, duration: .seconds(1), label: "A", tone: .muted)
        }
        #expect(throws: Failure.startOutOfRange) {
            try WaveformEvent(start: Self.limit + Self.attosecond, duration: .seconds(1), label: "A", tone: .muted)
        }
    }

    @Test("Durations must be positive")
    func durations() throws {
        for duration in [Duration.zero, .zero - Self.attosecond, .seconds(-5)] {
            #expect(throws: Failure.nonPositiveDuration) {
                try WaveformEvent(start: .zero, duration: duration, label: "A", tone: .muted)
            }
        }
        #expect(try WaveformEvent(start: .zero, duration: Self.attosecond, label: "A", tone: .muted).duration
                == Self.attosecond)
    }

    @Test("Labels must be non-empty, at most maximumLabelLength characters, without newlines or controls")
    func labels() throws {
        #expect(WaveformEvent.maximumLabelLength == 16)
        #expect(throws: Failure.emptyLabel) { try WaveformEvent(start: .zero, duration: .seconds(1), label: "", tone: .muted) }
        let longest = String(repeating: "x", count: 16)
        #expect(try WaveformEvent(start: .zero, duration: .seconds(1), label: longest, tone: .muted).label == longest)
        #expect(throws: Failure.invalidLabel) {
            try WaveformEvent(start: .zero, duration: .seconds(1), label: String(repeating: "x", count: 17), tone: .muted)
        }
        // Length counts characters: sixteen decomposed "é" graphemes are sixteen characters.
        let decomposed = String(repeating: "e\u{301}", count: 16)
        #expect(decomposed.count == 16)
        #expect(try WaveformEvent(start: .zero, duration: .seconds(1), label: decomposed, tone: .muted).label == decomposed)
        #expect(try WaveformEvent(start: .zero, duration: .seconds(1), label: "Mask off", tone: .muted).label == "Mask off")
        for label in ["A\nB", "A\r", "\r\n", "A\u{2028}B", "A\u{85}", "A\tB", "\u{0}", "A\u{1B}[0m", "A\u{7F}"] {
            #expect(throws: Failure.invalidLabel) {
                try WaveformEvent(start: .zero, duration: .seconds(1), label: label, tone: .muted)
            }
        }
    }

    @Test("Labels reject format (Cf) scalars and every CharacterSet.newlines member")
    func formatAndNewlineScalars() throws {
        let format = ["A\u{200B}B", "\u{FEFF}A", "A\u{00AD}", "A\u{200D}B", "A\u{2060}"]
        let newlines = ["A\u{0A}", "A\u{0B}", "A\u{0C}", "A\u{0D}", "A\u{85}", "A\u{2028}", "A\u{2029}"]
        for label in format + newlines {
            #expect(throws: Failure.invalidLabel) {
                try WaveformEvent(start: .zero, duration: .seconds(1), label: label, tone: .muted)
            }
        }
        // Printable scalars outside those sets remain admitted.
        for label in ["CA", "Mask off", "e\u{301}", "\u{2014}", "\u{25BE}"] {
            #expect(try WaveformEvent(start: .zero, duration: .seconds(1), label: label, tone: .muted).label == label)
        }
    }

    @Test("Validation reports the first failing check in the specified order")
    func order() {
        #expect(throws: Failure.startOutOfRange) {
            try WaveformEvent(start: .zero - Self.attosecond, duration: .zero, label: "", tone: .error)
        }
        #expect(throws: Failure.nonPositiveDuration) {
            try WaveformEvent(start: .zero, duration: .zero, label: "", tone: .error)
        }
        #expect(throws: Failure.nonPositiveDuration) {
            try WaveformEvent(start: .zero, duration: .seconds(-1), label: "\n", tone: .error)
        }
        #expect(throws: Failure.emptyLabel) {
            try WaveformEvent(start: Self.limit, duration: .seconds(1), label: "", tone: .error)
        }
    }
}
