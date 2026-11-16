/// Terminal-column placement of supplied synthetic event labels.
struct WaveformStudyEventRow {
    enum Tone: Int { case muted, warning, error }
    struct Cell {
        let character: Character
        let tone: Tone
    }
    let cells: [Cell]

    init(events: [WaveformStudyNight.Event], window: WaveformStudyWindow, width: Int, markersOnly: Bool = false) {
        guard width > 0 else { cells = []; return }
        let visible = events.filter { $0.seconds.overlaps(window.start..<window.end) }
            .sorted { $0.seconds.lowerBound < $1.seconds.lowerBound }
        func column(_ event: WaveformStudyNight.Event) -> Int {
            max(0, event.seconds.lowerBound - window.start) * width / window.length.seconds
        }
        var output = Array(repeating: Cell(character: " ", tone: .muted), count: width)
        var lastOccupied = -2
        for (index, event) in visible.enumerated() {
            let start = column(event)
            let next = index + 1 < visible.count ? column(visible[index + 1]) : width + 1
            let label = Array(event.label)
            let end = start + label.count - 1
            let hasPreviousSpace = start > lastOccupied + 1
            let hasNextSpace = end + 1 < next
            let fits = end < width
            let tone: Tone
            switch event.kind {
            case .obstructive, .central: tone = .error
            case .hypopnea: tone = .warning
            case .limitation: tone = .muted
            }
            if markersOnly == false, hasPreviousSpace, hasNextSpace, fits {
                for (offset, character) in label.enumerated() {
                    output[start + offset] = Cell(character: character, tone: tone)
                }
                lastOccupied = end
            } else {
                let existing = output[start]
                let merged = existing.tone.rawValue > tone.rawValue ? existing.tone : tone
                output[start] = Cell(character: "▾", tone: merged)
                lastOccupied = max(lastOccupied, start)
            }
        }
        cells = output
    }
}
