import SwiftTUIViews

/// Immutable terminal-cell presentation; authored lit colors belong to the frame.
public struct DotMatrixStyle {
    public enum Shape: String {
        case round
        case square

        var glyph: Character {
            switch self {
            case .round: "●"
            case .square: "■"
            }
        }
    }

    public enum ValidationError {
        case horizontalGapOutOfRange
        case verticalGapOutOfRange
    }

    public let shape: Shape
    /// Blank terminal columns between adjacent LEDs, in `0...8`.
    public let horizontalGap: Int
    /// Blank terminal rows between adjacent LED rows, in `0...8`.
    public let verticalGap: Int
    /// `nil` inherits the current Chio style's muted text color.
    public let unlitColor: Color?

    public init(shape: Shape = .round, horizontalGap: Int = 1, verticalGap: Int = 0,
                unlitColor: Color? = nil) throws(ValidationError) {
        guard (0...8).contains(horizontalGap) else { throw .horizontalGapOutOfRange }
        guard (0...8).contains(verticalGap) else { throw .verticalGapOutOfRange }
        self.shape = shape
        self.horizontalGap = horizontalGap
        self.verticalGap = verticalGap
        self.unlitColor = unlitColor
    }

    private enum CodingKeys: String, CodingKey { case shape, horizontalGap, verticalGap, unlitColor }
}

extension DotMatrixStyle: Decodable {
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let shape = try values.decode(Shape.self, forKey: .shape)
        let horizontalGap = try values.decode(Int.self, forKey: .horizontalGap)
        let verticalGap = try values.decode(Int.self, forKey: .verticalGap)
        let unlitColor = try values.decodeIfPresent(Color.self, forKey: .unlitColor)
        do {
            try self.init(shape: shape, horizontalGap: horizontalGap, verticalGap: verticalGap,
                          unlitColor: unlitColor)
        } catch {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath, debugDescription: "Invalid dot matrix style: \(error)"
            ))
        }
    }
}

extension DotMatrixStyle: Encodable {}
extension DotMatrixStyle: Hashable {}
extension DotMatrixStyle: Sendable {}
extension DotMatrixStyle.Shape: Codable {}
extension DotMatrixStyle.Shape: Hashable {}
extension DotMatrixStyle.Shape: Sendable {}
extension DotMatrixStyle.ValidationError: Error {}
extension DotMatrixStyle.ValidationError: Hashable {}
extension DotMatrixStyle.ValidationError: Sendable {}
