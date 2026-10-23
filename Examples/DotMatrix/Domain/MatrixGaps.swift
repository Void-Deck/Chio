/// Example choices measured in terminal cells between complete dots.
enum MatrixGaps: Int {
    case compact, regular, open

    var horizontal: Int {
        switch self {
        case .compact: 0
        case .regular: 1
        case .open: 3
        }
    }

    var vertical: Int {
        switch self {
        case .compact, .regular: 0
        case .open: 1
        }
    }

    var next: Self {
        switch self {
        case .compact: .regular
        case .regular: .open
        case .open: .compact
        }
    }
}

extension MatrixGaps: Sendable {}

extension MatrixGaps: CaseIterable {}
