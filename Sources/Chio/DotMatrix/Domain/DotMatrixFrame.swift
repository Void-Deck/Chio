/// A complete rectangular image of RGB channels and independent intensity.
///
/// Each SIMD value stores red, green, blue, then intensity in `0...1`.
/// Painting multiplies encoded sRGB channels by intensity. This terminal
/// brightness convention does not represent physical luminance or alpha.
/// Zero intensity and black RGB both paint as an inactive LED.
public struct DotMatrixFrame {
    public let matrix: [[SIMD4<Float>]]
    public var columns: Int { matrix[0].count }
    public var height: Int { matrix.count }

    public enum ValidationError {
        case emptyRows
        case emptyColumns
        case unevenRows(rowIndex: Int)
        case channelOutOfRange(rowIndex: Int, columnIndex: Int, channelIndex: Int)
    }

    public init(matrix: [[SIMD4<Float>]]) throws(ValidationError) {
        guard let first = matrix.first else { throw .emptyRows }
        guard !first.isEmpty else { throw .emptyColumns }
        for (rowIndex, row) in matrix.enumerated() {
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
        self.matrix = matrix
    }

    private enum CodingKeys: String, CodingKey { case matrix = "rows" }
}

extension DotMatrixFrame: Decodable {
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let matrix = try values.decode([[SIMD4<Float>]].self, forKey: .matrix)
        do { try self.init(matrix: matrix) }
        catch {
            throw DecodingError.dataCorruptedError(
                forKey: .matrix, in: values, debugDescription: "Invalid dot matrix frame: \(error)"
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
