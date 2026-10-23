/// A complete rectangular image of RGB channels and independent intensity.
///
/// Each SIMD value stores red, green, blue, then intensity in `0...1`.
/// Painting multiplies encoded sRGB channels by intensity. This terminal
/// brightness convention does not represent physical luminance or alpha.
/// Zero intensity and black RGB both paint as an inactive LED.
public struct DotMatrixFrame {
    public static let maximumDotCount = 65_536

    public let rows: [[SIMD4<Float>]]
    public var columns: Int { rows[0].count }
    public var height: Int { rows.count }

    public enum ValidationError {
        case emptyRows
        case emptyColumns
        case unevenRows(rowIndex: Int)
        case dotLimitExceeded(limit: Int)
        case channelOutOfRange(rowIndex: Int, columnIndex: Int, channelIndex: Int)
    }

    public init(rows: [[SIMD4<Float>]]) throws(ValidationError) {
        guard let first = rows.first else { throw .emptyRows }
        guard !first.isEmpty else { throw .emptyColumns }
        // Division avoids overflowing a product supplied by arbitrary input.
        guard rows.count <= Self.maximumDotCount / first.count else {
            throw .dotLimitExceeded(limit: Self.maximumDotCount)
        }
        for (rowIndex, row) in rows.enumerated() {
            guard row.count == first.count else { throw .unevenRows(rowIndex: rowIndex) }
            for (columnIndex, dot) in row.enumerated() {
                for channelIndex in 0..<4 {
                    let channel = dot[channelIndex]
                    let isFinite = channel.isFinite
                    let isInRange = (0...1).contains(channel)
                    guard isFinite && isInRange else {
                        throw .channelOutOfRange(rowIndex: rowIndex, columnIndex: columnIndex,
                                                 channelIndex: channelIndex)
                    }
                }
            }
        }
        self.rows = rows
    }

    private enum CodingKeys: String, CodingKey { case rows }
}

extension DotMatrixFrame: Decodable {
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try values.decode([[SIMD4<Float>]].self, forKey: .rows)
        do { try self.init(rows: rows) }
        catch {
            throw DecodingError.dataCorruptedError(
                forKey: .rows, in: values, debugDescription: "Invalid dot matrix frame: \(error)"
            )
        }
    }
}

extension DotMatrixFrame: Encodable {}
extension DotMatrixFrame: Hashable {}
extension DotMatrixFrame: Sendable {}
extension DotMatrixFrame.ValidationError: Error {}
extension DotMatrixFrame.ValidationError: Hashable {}
extension DotMatrixFrame.ValidationError: Sendable {}
