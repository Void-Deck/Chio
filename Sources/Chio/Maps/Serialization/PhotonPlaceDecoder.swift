import Foundation

/// Photon-specific normalization, independent of transport and map geometry codecs.
enum PhotonPlaceDecoder {
    static func decode(_ data: Data, limit: Int) throws -> MapPlaceMatches {
        guard data.count <= 512 * 1_024 else { throw DecodeError.oversizedData }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.features.count <= limit else { throw DecodeError.tooManyPlaces }
        let places = try response.features.map { try $0.place() }
        let photonURL = URL(string: "https://photon.komoot.io")
        let osmURL = URL(string: "https://www.openstreetmap.org/copyright")
        guard let photonURL, let osmURL else { throw DecodeError.invalidAttribution }
        let attributions = try [
            MapPlaceMatches.Attribution(text: "Photon", link: photonURL),
            MapPlaceMatches.Attribution(text: "© OpenStreetMap contributors", link: osmURL)
        ]
        return try MapPlaceMatches(places: places, attributions: attributions)
    }

    enum DecodeError {
        case invalidCollection, invalidFeature, invalidPoint, invalidText, missingName
        case tooManyPlaces, oversizedData, invalidAttribution
    }

    private struct Response: Decodable {
        let features: [Feature]

        private enum CodingKeys: String, CodingKey { case type, features }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            if values.contains(.type) {
                guard try values.decode(String.self, forKey: .type) == "FeatureCollection"
                else { throw DecodeError.invalidCollection }
            }
            var encoded = try values.nestedUnkeyedContainer(forKey: .features)
            var features: [Feature] = []
            while !encoded.isAtEnd {
                guard features.count < 10 else { throw DecodeError.tooManyPlaces }
                features.append(try encoded.decode(Feature.self))
            }
            self.features = features
        }
    }

    private struct Feature: Decodable {
        let geometry: Geometry
        let properties: Properties

        private enum CodingKeys: String, CodingKey { case type, geometry, properties }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            guard try values.decode(String.self, forKey: .type) == "Feature"
            else { throw DecodeError.invalidFeature }
            geometry = try values.decode(Geometry.self, forKey: .geometry)
            properties = try values.decode(Properties.self, forKey: .properties)
        }

        func place() throws -> MapPlace {
            let coordinate = try MapCoordinate(latitude: geometry.latitude, longitude: geometry.longitude)
            let address = properties.address
            let candidates = [properties.name, address, properties.locality, properties.district,
                              properties.city, properties.county, properties.state, properties.country]
            guard let name = candidates.first(where: { !$0.isEmpty }) else { throw DecodeError.missingName }
            let postalCity = [properties.postcode, properties.city].filter { !$0.isEmpty }.joined(separator: " ")
            let components = [address, properties.locality, properties.district, postalCity,
                              properties.county, properties.state, properties.country]
            var detailComponents: [String] = []
            for component in components {
                let hasContent = !component.isEmpty
                let differsFromName = component != name
                let isNewComponent = !detailComponents.contains(component)
                if hasContent, differsFromName, isNewComponent { detailComponents.append(component) }
            }
            return try MapPlace(coordinate: coordinate, name: name, detail: detailComponents.joined(separator: ", "))
        }
    }

    private struct Geometry: Decodable {
        let longitude: Double
        let latitude: Double

        private enum CodingKeys: String, CodingKey { case type, coordinates }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            guard try values.decode(String.self, forKey: .type) == "Point" else { throw DecodeError.invalidPoint }
            var coordinates = try values.nestedUnkeyedContainer(forKey: .coordinates)
            longitude = try coordinates.decode(Double.self)
            latitude = try coordinates.decode(Double.self)
            guard coordinates.isAtEnd else { throw DecodeError.invalidPoint }
        }
    }

    private struct Properties: Decodable {
        let name: String
        let street: String
        let housenumber: String
        let postcode: String
        let locality: String
        let district: String
        let city: String
        let county: String
        let state: String
        let country: String

        var address: String {
            guard !street.isEmpty else { return "" }
            return [street, housenumber].filter { !$0.isEmpty }.joined(separator: " ")
        }

        private enum CodingKeys: String, CodingKey {
            case name, street, housenumber, postcode, locality, district, city, county, state, country
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            name = try Self.text(.name, in: values)
            street = try Self.text(.street, in: values)
            housenumber = try Self.text(.housenumber, in: values)
            postcode = try Self.text(.postcode, in: values)
            locality = try Self.text(.locality, in: values)
            district = try Self.text(.district, in: values)
            city = try Self.text(.city, in: values)
            county = try Self.text(.county, in: values)
            state = try Self.text(.state, in: values)
            country = try Self.text(.country, in: values)
        }

        private static func text(_ key: CodingKeys, in values: KeyedDecodingContainer<CodingKeys>) throws -> String {
            guard values.contains(key) else { return "" }
            let text = try values.decode(String.self, forKey: key)
            let hasNoControls = !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
            let isWithinComponentLimit = text.utf8.count <= 1_024
            guard hasNoControls, isWithinComponentLimit else { throw DecodeError.invalidText }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "" }
            return text
        }
    }
}

extension PhotonPlaceDecoder.DecodeError: Error {}
extension PhotonPlaceDecoder.DecodeError: Equatable {}
extension PhotonPlaceDecoder.DecodeError: Sendable {}
