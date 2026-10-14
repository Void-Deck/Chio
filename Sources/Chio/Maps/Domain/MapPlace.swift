import Foundation

/// A provider observation without a permanent provider or application selection ID.
public struct MapPlace {
    public let coordinate: MapCoordinate
    public let name: String
    public let detail: String

    public init(coordinate: MapCoordinate, name: String, detail: String = "") throws(ValidationError) {
        let hasVisibleName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isWithinNameLimit = name.utf8.count <= 256
        let hasNoNameControls = !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        guard hasVisibleName, isWithinNameLimit, hasNoNameControls else { throw .invalidName }
        let isWithinDetailLimit = detail.utf8.count <= 1_024
        let hasNoDetailControls = !detail.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        guard isWithinDetailLimit, hasNoDetailControls else { throw .invalidDetail }
        self.coordinate = coordinate
        self.name = name
        self.detail = detail
    }

    public enum ValidationError { case invalidName, invalidDetail }
}

extension MapPlace: Codable {
    private enum CodingKeys: String, CodingKey { case coordinate, name, detail }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(coordinate: values.decode(MapCoordinate.self, forKey: .coordinate),
                      name: values.decode(String.self, forKey: .name),
                      detail: values.decode(String.self, forKey: .detail))
    }
}

extension MapPlace: Hashable {}
extension MapPlace: Sendable {}

extension MapPlace.ValidationError: Equatable {}
extension MapPlace.ValidationError: Error {}
extension MapPlace.ValidationError: Sendable {}
