import SwiftTUI

/// A complete bounded frame. Off is a visible inactive LED, not transparency.
struct DotMatrixFrame {
    enum Dot {
        case off
        case on(Color)
    }

    enum ValidationError {
        case heightOutOfBounds
        case widthOutOfBounds
        case unevenRows
    }

    let rows: [[Dot]]

    var columns: Int { rows[0].count }
    var height: Int { rows.count }
    var cellWidth: Int { columns * 2 - 1 }

    init(rows: [[Dot]]) throws(ValidationError) {
        guard (1...32).contains(rows.count) else { throw .heightOutOfBounds }
        let width = rows[0].count
        guard (1...64).contains(width) else { throw .widthOutOfBounds }
        guard rows.allSatisfy({ $0.count == width }) else { throw .unevenRows }
        self.rows = rows
    }
}

extension DotMatrixFrame: Codable {
    private enum CodingKeys: String, CodingKey { case rows }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try container.decode([[Dot]].self, forKey: .rows)
        do { try self.init(rows: rows) }
        catch {
            throw DecodingError.dataCorruptedError(forKey: .rows, in: container,
                                                   debugDescription: "Invalid matrix dimensions: \(error)")
        }
    }
}

extension DotMatrixFrame: Hashable {}
extension DotMatrixFrame: Sendable {}
extension DotMatrixFrame.Dot: Codable {}
extension DotMatrixFrame.Dot: Hashable {}
extension DotMatrixFrame.Dot: Sendable {}
extension DotMatrixFrame.ValidationError: Equatable {}
extension DotMatrixFrame.ValidationError: Error {}
