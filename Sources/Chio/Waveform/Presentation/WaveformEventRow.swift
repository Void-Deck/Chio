/// Pure stable event ordering and cell placement.
struct WaveformEventRow {
    struct Cell {
        let character: Character
        let tone: WaveformEvent.Tone
    }
    let cells: [Cell]
    let visible: [WaveformEvent]

    init(events: [WaveformEvent], window: HistoryInterval, width: Int) {
        let start = window.range.lowerBound
        let end = window.range.upperBound
        visible = events.enumerated().filter {
            $0.element.start <= end && ($0.element.start >= start || $0.element.duration > start - $0.element.start)
        }.sorted {
            if $0.element.start == $1.element.start { return $0.offset < $1.offset }
            return $0.element.start < $1.element.start
        }.map(\.element)
        guard width > 0 else { cells = []; return }
        let duration = WaveformColumns.seconds(end - start)
        let anchors = visible.map {
            max(0, min(width - 1, Int((WaveformColumns.seconds($0.start - start) / duration * Double(width)).rounded(.down))))
        }
        var output = Array(repeating: Cell(character: " ", tone: .muted), count: width)
        var previous = -2
        for (index, event) in visible.enumerated() {
            let anchor = anchors[index]
            guard anchor < width else { continue }
            let next = index + 1 < anchors.count ? anchors[index + 1] : width + 1
            let end = anchor + event.label.count - 1
            if end < width, anchor >= previous + 2, end + 1 < next {
                for (offset, character) in event.label.enumerated() {
                    output[anchor + offset] = Cell(character: character, tone: event.tone)
                }
                previous = end
            } else {
                let old = output[anchor]
                let tone = old.character == "▾" && Self.severity(old.tone) > Self.severity(event.tone) ? old.tone : event.tone
                output[anchor] = Cell(character: "▾", tone: tone)
                previous = max(previous, anchor)
            }
        }
        cells = output
    }

    private static func severity(_ tone: WaveformEvent.Tone) -> Int {
        switch tone {
        case .muted: 0
        case .warning: 1
        case .error: 2
        }
    }
}
