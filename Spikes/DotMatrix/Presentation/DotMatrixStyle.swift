import SwiftTUI

/// Pure view options. Authored lit colors belong to the supplied image frame.
struct DotMatrixStyle {
    enum Shape: String {
        case round
        case square

        var glyph: Character {
            switch self {
            case .round: "●"
            case .square: "■"
            }
        }

        var next: Self {
            switch self {
            case .round: .square
            case .square: .round
            }
        }
    }

    let unlitColor: Color
    let shape: Shape
}

extension DotMatrixStyle: Codable {}
extension DotMatrixStyle: Hashable {}
extension DotMatrixStyle: Sendable {}
extension DotMatrixStyle.Shape: Codable {}
extension DotMatrixStyle.Shape: Hashable {}
extension DotMatrixStyle.Shape: Sendable {}
