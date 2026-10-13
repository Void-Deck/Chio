/// Explicit submitted geographic coordinate and maximum requested match count.
public struct MapPlaceLookup {
    public let coordinate: MapCoordinate
    public let limit: Int

    public init(coordinate: MapCoordinate, limit: Int = 1) throws(ValidationError) {
        guard (1...10).contains(limit) else { throw .invalidLimit }
        self.coordinate = coordinate
        self.limit = limit
    }

    public enum ValidationError { case invalidLimit }
}

extension MapPlaceLookup: Codable {
    private enum CodingKeys: String, CodingKey { case coordinate, limit }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(coordinate: values.decode(MapCoordinate.self, forKey: .coordinate),
                      limit: values.decode(Int.self, forKey: .limit))
    }
}

extension MapPlaceLookup: Hashable {}
extension MapPlaceLookup: Sendable {}
extension MapPlaceLookup.ValidationError: Equatable {}
extension MapPlaceLookup.ValidationError: Error {}
extension MapPlaceLookup.ValidationError: Sendable {}
