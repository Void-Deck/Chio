/// Provider-ranked observations and the credits required even when there are no matches.
public struct MapPlaceMatches {
    public let places: [MapPlace]
    public let attributions: [Attribution]

    public init(places: [MapPlace], attributions: [Attribution]) throws(ValidationError) {
        guard places.count <= 10 else { throw .tooManyPlaces }
        guard (1...4).contains(attributions.count) else { throw .invalidAttributionCount }
        self.places = places
        self.attributions = attributions
    }

    /// Retains the original public spelling while sharing checked credits with routing.
    public typealias Attribution = MapAttribution

    public enum ValidationError { case tooManyPlaces, invalidAttributionCount }
}

extension MapPlaceMatches: Codable {
    private enum CodingKeys: String, CodingKey { case places, attributions }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        var encodedPlaces = try values.nestedUnkeyedContainer(forKey: .places)
        var places: [MapPlace] = []
        while !encodedPlaces.isAtEnd {
            guard places.count < 10 else { throw ValidationError.tooManyPlaces }
            places.append(try encodedPlaces.decode(MapPlace.self))
        }
        var encodedAttributions = try values.nestedUnkeyedContainer(forKey: .attributions)
        var attributions: [Attribution] = []
        while !encodedAttributions.isAtEnd {
            guard attributions.count < 4 else { throw ValidationError.invalidAttributionCount }
            attributions.append(try encodedAttributions.decode(Attribution.self))
        }
        try self.init(places: places, attributions: attributions)
    }
}

extension MapPlaceMatches: Hashable {}
extension MapPlaceMatches: Sendable {}

extension MapPlaceMatches.ValidationError: Equatable {}
extension MapPlaceMatches.ValidationError: Error {}
extension MapPlaceMatches.ValidationError: Sendable {}
