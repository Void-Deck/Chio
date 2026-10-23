import SwiftTUI

/// Fixed example content. No animation state or font logic belongs to DotMatrix.
struct MatrixScene {
    enum Palette: String {
        case amber
        case green

        var lit: Color {
            switch self {
            case .amber: Color(hexRGB: 0xFFBC55)
            case .green: Color(hexRGB: 0x85F3B3)
            }
        }

        var unlit: Color {
            switch self {
            case .amber: Color(hexRGB: 0x594532)
            case .green: Color(hexRGB: 0x2F5147)
            }
        }

        var next: Self {
            switch self {
            case .amber: .green
            case .green: .amber
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

    let amberLettering: DotMatrixFrame
    let greenLettering: DotMatrixFrame
    private let icons: [DotMatrixFrame]

    init() throws {
        amberLettering = try MatrixLettering.frame("CHIO", color: Palette.amber.lit)
        greenLettering = try MatrixLettering.frame("CHIO", color: Palette.green.lit)
        let masks = [
            ["........", "........", "..#..#..", ".######.", ".######.", "..####..", "...##...", "........"],
            ["........", ".##..##.", "########", "########", ".######.", "..####..", "...##...", "........"],
            [".##..##.", "########", "########", "########", ".######.", "..####..", "...##...", "........"],
            ["........", ".##..##.", "########", "########", ".######.", "..####..", "...##...", "........"],
        ]
        icons = try masks.map { mask in
            try DotMatrixFrame(rows: mask.enumerated().map { y, line in
                line.enumerated().map { x, value in
                    guard value == "#" else { return .off }
                    let isHighlight = y < 3 && x < 4
                    return .on(Color(hexRGB: isHighlight ? 0xFFD49B : 0xFF6F91))
                }
            })
        }
    }

    func lettering(for palette: Palette) -> DotMatrixFrame {
        switch palette {
        case .amber: amberLettering
        case .green: greenLettering
        }
    }

    func icon(at frame: Frame) -> DotMatrixFrame { icons[frame.rawValue] }
}

extension MatrixScene: Sendable {}
extension MatrixScene.Palette: Hashable {}
extension MatrixScene.Palette: Sendable {}
extension MatrixScene.Frame: CaseIterable {}
extension MatrixScene.Frame: Hashable {}
extension MatrixScene.Frame: Sendable {}
