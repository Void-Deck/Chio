import Foundation

/// Explicit submitted forward-search text and the maximum requested match count.
public struct MapPlaceQuery {
    public let text: String
    public let limit: Int

    public init(text: String, limit: Int = 8) throws(ValidationError) {
        let hasVisibleText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isWithinTextLimit = text.utf8.count <= 512
        let hasNoControls = !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        guard hasVisibleText, isWithinTextLimit, hasNoControls else { throw .invalidText }
        guard (1...10).contains(limit) else { throw .invalidLimit }
        self.text = text
        self.limit = limit
    }

    public enum ValidationError { case invalidText, invalidLimit }
}

extension MapPlaceQuery: Codable {
    private enum CodingKeys: String, CodingKey { case text, limit }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(text: values.decode(String.self, forKey: .text),
                      limit: values.decode(Int.self, forKey: .limit))
    }
}

extension MapPlaceQuery: Hashable {}
extension MapPlaceQuery: Sendable {}

extension MapPlaceQuery.ValidationError: Equatable {}
extension MapPlaceQuery.ValidationError: Error {}
extension MapPlaceQuery.ValidationError: Sendable {}
