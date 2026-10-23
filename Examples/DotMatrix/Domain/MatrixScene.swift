import Chio

/// App-owned immutable images. Playback, lettering and intensity are not view policy.
struct MatrixScene {
    enum Palette: String {
        case amber
        case green

        var rgb: SIMD3<Float> {
            switch self {
            case .amber: SIMD3<Float>(1, 188.0 / 255, 85.0 / 255)
            case .green: SIMD3<Float>(133.0 / 255, 243.0 / 255, 179.0 / 255)
            }
        }

        var next: Self {
            switch self {
            case .amber: .green
            case .green: .amber
            }
        }
    }

    enum Intensity: Int {
        case full, half, dim

        var value: Float {
            switch self {
            case .full: 1
            case .half: 0.5
            case .dim: 0.2
            }
        }

        var label: String {
            switch self {
            case .full: "1"
            case .half: "0.5"
            case .dim: "0.2"
            }
        }

        var next: Self {
            switch self {
            case .full: .half
            case .half: .dim
            case .dim: .full
            }
        }
    }

    enum Frame: Int {
        case first, second, third, fourth

        var next: Self {
            switch self {
            case .first: .second
            case .second: .third
            case .third: .fourth
            case .fourth: .first
            }
        }
    }

    private let amberLettering: [DotMatrixFrame]
    private let greenLettering: [DotMatrixFrame]
    private let icons: [[DotMatrixFrame]]
    private let roundStyles: [DotMatrixStyle]
    private let squareStyles: [DotMatrixStyle]
    let gradient: DotMatrixFrame

    init() throws {
        roundStyles = try MatrixGaps.allCases.map {
            try DotMatrixStyle(shape: .round, horizontalGap: $0.horizontal, verticalGap: $0.vertical)
        }
        squareStyles = try MatrixGaps.allCases.map {
            try DotMatrixStyle(shape: .square, horizontalGap: $0.horizontal, verticalGap: $0.vertical)
        }
        amberLettering = try Intensity.allCases.map { intensity in
            try MatrixLettering.frame("CHIO", color: SIMD4<Float>(Palette.amber.rgb, intensity.value))
        }
        greenLettering = try Intensity.allCases.map { intensity in
            try MatrixLettering.frame("CHIO", color: SIMD4<Float>(Palette.green.rgb, intensity.value))
        }
        let masks = [
            ["........", "........", "..#..#..", ".######.", ".######.", "..####..", "...##...", "........"],
            ["........", ".##..##.", "########", "########", ".######.", "..####..", "...##...", "........"],
            [".##..##.", "########", "########", "########", ".######.", "..####..", "...##...", "........"],
            ["........", ".##..##.", "########", "########", ".######.", "..####..", "...##...", "........"],
        ]
        icons = try Intensity.allCases.map { intensity in
            try masks.map { mask in
                try DotMatrixFrame(rows: mask.enumerated().map { y, line in
                    line.enumerated().map { x, value in
                        guard value == "#" else { return SIMD4<Float>.zero }
                        let isHighlight = y < 3 && x < 4
                        let rgb = isHighlight ? SIMD3<Float>(1, 212.0 / 255, 155.0 / 255)
                                              : SIMD3<Float>(1, 111.0 / 255, 145.0 / 255)
                        return SIMD4<Float>(rgb, intensity.value)
                    }
                })
            }
        }
        gradient = try DotMatrixFrame(rows: (0..<40).map { y in
            (0..<64).map { x in SIMD4<Float>(Float(x) / 63, Float(y) / 39, 1 - Float(x) / 63, 1) }
        })
    }

    func style(shape: DotMatrixStyle.Shape, gaps: MatrixGaps) -> DotMatrixStyle {
        switch shape {
        case .round: roundStyles[gaps.rawValue]
        case .square: squareStyles[gaps.rawValue]
        }
    }

    func lettering(for palette: Palette, intensity: Intensity) -> DotMatrixFrame {
        switch palette {
        case .amber: amberLettering[intensity.rawValue]
        case .green: greenLettering[intensity.rawValue]
        }
    }

    func icon(at frame: Frame, intensity: Intensity) -> DotMatrixFrame {
        icons[intensity.rawValue][frame.rawValue]
    }
}

extension MatrixScene: Sendable {}
extension MatrixScene.Palette: Hashable {}
extension MatrixScene.Palette: Sendable {}
extension MatrixScene.Intensity: CaseIterable {}
extension MatrixScene.Intensity: Sendable {}
extension MatrixScene.Frame: CaseIterable {}
extension MatrixScene.Frame: Hashable {}
extension MatrixScene.Frame: Sendable {}
