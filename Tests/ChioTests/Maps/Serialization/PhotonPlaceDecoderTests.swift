@testable import Chio
import Foundation
import Testing

struct PhotonPlaceDecoderTests {
    @Test("Photon points use longitude first, retaining order, duplicate observations and polar geography")
    func rankedPoints() throws {
        let query = try MapPlaceQuery(text: "landmark")
        let first = feature(properties: #"{"name":"Landmark","street":"Olympischer Platz","housenumber":"3","postcode":"14053","city":"Berlin","country":"Germany","extent":[1,2,3,4],"osm_id":12}"#,
                            coordinates: "[13.2395,52.5146]")
        let pole = feature(properties: #"{"name":"Pole"}"#, coordinates: "[-180,90]")
        let matches = try PhotonPlaceDecoder.decode(response([first, pole, first]), query: query)
        #expect(matches.places.map(\.name) == ["Landmark", "Pole", "Landmark"])
        #expect(matches.places[0].coordinate.longitude == 13.2395)
        #expect(matches.places[0].coordinate.latitude == 52.5146)
        #expect(matches.places[0].detail == "Olympischer Platz 3, 14053 Berlin, Germany")
        #expect(matches.places[1].coordinate.latitude == 90)
        #expect(matches.places[1].detail.isEmpty)
        #expect(matches.places[0] == matches.places[2])
    }

    @Test("Empty success retains independent provider and data credits")
    func emptyCredits() throws {
        let matches = try PhotonPlaceDecoder.decode(response([]), query: MapPlaceQuery(text: "unknown"))
        #expect(matches.places.isEmpty)
        #expect(matches.attributions.map(\.text) == ["Photon", "© OpenStreetMap contributors"])
        #expect(matches.attributions.map { $0.link.absoluteString } == ["https://photon.komoot.io", "https://www.openstreetmap.org/copyright"])
        let typed = Data(#"{"type":"FeatureCollection","features":[],"extra":true}"#.utf8)
        #expect(try PhotonPlaceDecoder.decode(typed, query: MapPlaceQuery(text: "unknown")) == matches)
    }

    @Test("Name precedence and supporting address composition have explicit independent expectations")
    func nameAndAddress() throws {
        let properties = [
            #"{"name":"Named","street":"Road","housenumber":"12","locality":"Local","district":"District","city":"City","postcode":"123","county":"County","state":"State","country":"Country"}"#,
            #"{"street":"Road","housenumber":"12","city":"City"}"#,
            #"{"locality":"Local","district":"District","city":"City"}"#,
            #"{"district":"District","city":"City"}"#,
            #"{"city":"City","state":"City","country":"Country"}"#,
            #"{"county":"County","state":"State"}"#,
            #"{"state":"State","country":"Country"}"#,
            #"{"country":"Country"}"#
        ]
        let matches = try PhotonPlaceDecoder.decode(response(properties.map { feature(properties: $0) }), query: MapPlaceQuery(text: "x"))
        #expect(matches.places.map(\.name) == ["Named", "Road 12", "Local", "District", "City", "County", "State", "Country"])
        #expect(matches.places.map(\.detail) == [
            "Road 12, Local, District, 123 City, County, State, Country", "City", "District, City", "City",
            "Country", "State", "Country", ""
        ])
    }

    @Test("Malformed provider fields cannot become an empty successful search or repaired labels")
    func malformedFields() throws {
        let query = try MapPlaceQuery(text: "x")
        for properties in [#"{}"#, #"{"name":" ","housenumber":"12"}"#, #"{"postcode":"123"}"#] {
            #expect(throws: PhotonPlaceDecoder.DecodeError.missingName) {
                try PhotonPlaceDecoder.decode(response([feature(properties: properties)]), query: query)
            }
        }
        for properties in [#"{"name":12}"#, #"{"name":"Name","city":null}"#, #"{"name":"Name","street":false}"#] {
            #expect(throws: DecodingError.self) {
                try PhotonPlaceDecoder.decode(response([feature(properties: properties)]), query: query)
            }
        }
        for properties in [#"{"name":"Name\u001b"}"#, #"{"name":"Name","city":"City\u009b"}"#] {
            #expect(throws: PhotonPlaceDecoder.DecodeError.invalidText) {
                try PhotonPlaceDecoder.decode(response([feature(properties: properties)]), query: query)
            }
        }
        let longName = "{\"name\":\"" + String(repeating: "é", count: 129) + "\"}"
        #expect(throws: MapPlace.ValidationError.invalidName) {
            try PhotonPlaceDecoder.decode(response([feature(properties: longName)]), query: query)
        }
        let longComponent = "{\"name\":\"Name\",\"city\":\"" + String(repeating: "é", count: 513) + "\"}"
        #expect(throws: PhotonPlaceDecoder.DecodeError.invalidText) {
            try PhotonPlaceDecoder.decode(response([feature(properties: longComponent)]), query: query)
        }
        let longDetail = "{\"name\":\"Name\",\"city\":\"" + String(repeating: "c", count: 600) + "\",\"country\":\"" + String(repeating: "d", count: 600) + "\"}"
        #expect(throws: MapPlace.ValidationError.invalidDetail) {
            try PhotonPlaceDecoder.decode(response([feature(properties: longDetail)]), query: query)
        }
    }

    @Test("Geometry must be a valid finite Point with exactly two numeric ordinates")
    func geometryFailures() throws {
        let query = try MapPlaceQuery(text: "x")
        for coordinates in ["[0,91]", "[181,0]"] {
            #expect(throws: MapValidationError.invalidCoordinate) {
                try PhotonPlaceDecoder.decode(response([feature(properties: #"{"name":"Name"}"#, coordinates: coordinates)]), query: query)
            }
        }
        #expect(throws: PhotonPlaceDecoder.DecodeError.invalidPoint) {
            try PhotonPlaceDecoder.decode(response([feature(properties: #"{"name":"Name"}"#, coordinates: "[0,0,0]")]), query: query)
        }
        for coordinates in ["[]", "[0]", "[0,\"1\"]", "[null,0]"] {
            #expect(throws: DecodingError.self) {
                try PhotonPlaceDecoder.decode(response([feature(properties: #"{"name":"Name"}"#, coordinates: coordinates)]), query: query)
            }
        }
        let notPoint = Data(#"{"features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[0,0]},"properties":{"name":"Name"}}]}"#.utf8)
        #expect(throws: PhotonPlaceDecoder.DecodeError.invalidPoint) { try PhotonPlaceDecoder.decode(notPoint, query: query) }
        let notFeature = Data(#"{"features":[{"type":"Other","geometry":{"type":"Point","coordinates":[0,0]},"properties":{"name":"Name"}}]}"#.utf8)
        #expect(throws: PhotonPlaceDecoder.DecodeError.invalidFeature) { try PhotonPlaceDecoder.decode(notFeature, query: query) }
        let notCollection = Data(#"{"type":"Other","features":[]}"#.utf8)
        #expect(throws: PhotonPlaceDecoder.DecodeError.invalidCollection) { try PhotonPlaceDecoder.decode(notCollection, query: query) }
        for document in [#"{}"#, #"{"features":null}"#, #"{"features":[{}]}"#, "not JSON"] {
            #expect(throws: DecodingError.self) { try PhotonPlaceDecoder.decode(Data(document.utf8), query: query) }
        }
    }

    @Test("Result counts reject requested-limit overflow and stop before an eleventh malformed feature")
    func limits() throws {
        let item = feature(properties: #"{"name":"Name"}"#)
        #expect(throws: PhotonPlaceDecoder.DecodeError.tooManyPlaces) {
            try PhotonPlaceDecoder.decode(response([item, item]), query: MapPlaceQuery(text: "x", limit: 1))
        }
        #expect(try PhotonPlaceDecoder.decode(response(Array(repeating: item, count: 10)), query: MapPlaceQuery(text: "x", limit: 10)).places.count == 10)
        #expect(throws: PhotonPlaceDecoder.DecodeError.tooManyPlaces) {
            try PhotonPlaceDecoder.decode(response(Array(repeating: item, count: 10) + ["{}"]), query: MapPlaceQuery(text: "x", limit: 10))
        }
        let boundary = Data(("{\"features\":[]}" + String(repeating: " ", count: 512 * 1_024 - 15)).utf8)
        #expect(boundary.count == 512 * 1_024)
        #expect(try PhotonPlaceDecoder.decode(boundary, query: MapPlaceQuery(text: "x")).places.isEmpty)
        #expect(throws: PhotonPlaceDecoder.DecodeError.oversizedData) {
            try PhotonPlaceDecoder.decode(boundary + Data([32]), query: MapPlaceQuery(text: "x"))
        }
    }

    private func feature(properties: String, coordinates: String = "[103,1]") -> String {
        "{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":\(coordinates)},\"properties\":\(properties)}"
    }

    private func response(_ features: [String]) -> Data {
        Data("{\"features\":[\(features.joined(separator: ","))]}".utf8)
    }
}
