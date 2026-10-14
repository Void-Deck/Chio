import Foundation

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

    public struct Attribution {
        public let text: String
        public let link: URL

        public init(text: String, link: URL) throws(ValidationError) {
            let hasVisibleText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let isWithinTextLimit = text.utf8.count <= 1_024
            let hasNoControls = !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
            guard hasVisibleText, isWithinTextLimit, hasNoControls else { throw .invalidText }
            let hasSupportedScheme = ["http", "https"].contains(link.scheme?.lowercased() ?? "")
            let hasHost = !(link.host ?? "").isEmpty
            let hasNoCredentials = link.user == nil && link.password == nil
            let isWithinURLLimit = link.absoluteString.utf8.count <= 2_048
            let isAbsolute = link.baseURL == nil
            guard hasSupportedScheme, hasHost, hasNoCredentials, isWithinURLLimit, isAbsolute
            else { throw .invalidLink }
            self.text = text
            self.link = link
        }

        public enum ValidationError { case invalidText, invalidLink }
    }

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

extension MapPlaceMatches.Attribution: Codable {
    private enum CodingKeys: String, CodingKey { case text, link }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(text: values.decode(String.self, forKey: .text),
                      link: values.decode(URL.self, forKey: .link))
    }
}

extension MapPlaceMatches.Attribution: Hashable {}
extension MapPlaceMatches.Attribution: Sendable {}

extension MapPlaceMatches.ValidationError: Equatable {}
extension MapPlaceMatches.ValidationError: Error {}
extension MapPlaceMatches.ValidationError: Sendable {}

extension MapPlaceMatches.Attribution.ValidationError: Equatable {}
extension MapPlaceMatches.Attribution.ValidationError: Error {}
extension MapPlaceMatches.Attribution.ValidationError: Sendable {}
