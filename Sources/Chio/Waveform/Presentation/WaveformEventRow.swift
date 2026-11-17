/// Pure stable event ordering and cell placement.
struct WaveformEventRow {
    struct Cell {
        let character: Character
        let tone: WaveformEvent.Tone
    }
    let cells: [Cell]
    let visible: [WaveformEvent]

    init(events: [WaveformEvent], window: HistoryInterval, width: Int) {
        let windowStart = window.range.lowerBound
        let windowEnd = window.range.upperBound
        visible = events.enumerated().filter {
            let event = $0.element
            let startsBeforeWindowEnd = event.start <= windowEnd
            let startsInsideWindow = event.start >= windowStart
            let extendsIntoWindow = event.duration > windowStart - event.start
            return startsBeforeWindowEnd && (startsInsideWindow || extendsIntoWindow)
        }.sorted {
            if $0.element.start == $1.element.start { return $0.offset < $1.offset }
            return $0.element.start < $1.element.start
        }.map(\.element)
        guard width > 0 else { cells = []; return }
        let windowDurationSeconds = WaveformTime.seconds(windowEnd - windowStart)
        let anchors = visible.map {
            let position = WaveformTime.seconds($0.start - windowStart) / windowDurationSeconds * Double(width)
            // A visible range may start far before a subsecond window. Clamp
            // in Double before converting, including the exact right endpoint.
            if position <= 0 { return 0 }
            if position >= Double(width - 1) { return width - 1 }
            return Int(position.rounded(.down))
        }
        var output = Array(repeating: Cell(character: " ", tone: .muted), count: width)
        var lastOccupiedCell = -2
        for (index, event) in visible.enumerated() {
            let anchor = anchors[index]
            let nextAnchor = index + 1 < anchors.count ? anchors[index + 1] : width + 1
            let labelEnd = anchor + event.label.count - 1
            let fitsInRow = labelEnd < width
            let clearsPreviousCell = anchor >= lastOccupiedCell + 2
            let clearsNextAnchor = labelEnd + 1 < nextAnchor
            if fitsInRow && clearsPreviousCell && clearsNextAnchor {
                for (offset, character) in event.label.enumerated() {
                    output[anchor + offset] = Cell(character: character, tone: event.tone)
                }
                lastOccupiedCell = labelEnd
            } else {
                let existingCell = output[anchor]
                let isExistingMarker = existingCell.character == "▾"
                let isExistingMoreSevere = Self.severity(existingCell.tone) > Self.severity(event.tone)
                let keepsExistingTone = isExistingMarker && isExistingMoreSevere
                let tone = keepsExistingTone ? existingCell.tone : event.tone
                output[anchor] = Cell(character: "▾", tone: tone)
                lastOccupiedCell = max(lastOccupiedCell, anchor)
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
