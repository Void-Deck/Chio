import Chio
import Foundation
import Testing

struct MapPlaceValueTests {
    @Test("Submitted text is preserved and bounded by UTF-8 bytes and terminal safety")
    func queryBounds() throws {
        #expect(try MapPlaceQuery(text: "  Merlion  ").text == "  Merlion  ")
        #expect(try MapPlaceQuery(text: "Merlion").limit == 8)
        #expect(try MapPlaceQuery(text: String(repeating: "é", count: 256), limit: 10).limit == 10)
        for text in ["", "   ", "A\nB", "A\u{001B}B", "A\u{0085}B", String(repeating: "é", count: 257)] {
            #expect(throws: MapPlaceQuery.ValidationError.invalidText) { try MapPlaceQuery(text: text) }
        }
        for limit in [0, 11, Int.max] {
            #expect(throws: MapPlaceQuery.ValidationError.invalidLimit) { try MapPlaceQuery(text: "x", limit: limit) }
        }
        #expect(throws: MapPlaceQuery.ValidationError.invalidLimit) {
            try JSONDecoder().decode(MapPlaceQuery.self, from: Data(#"{"text":"x","limit":0}"#.utf8))
        }
        #expect(throws: MapPlaceQuery.ValidationError.invalidText) {
            try JSONDecoder().decode(MapPlaceQuery.self, from: Data(#"{"text":"x\u001b","limit":8}"#.utf8))
        }
    }

    @Test("Places retain geographic poles and reject unsafe or oversized labels through construction and coding")
    func placeBounds() throws {
        let pole = try MapCoordinate(latitude: 90, longitude: -180)
        let place = try MapPlace(coordinate: pole, name: String(repeating: "é", count: 128),
                                 detail: String(repeating: "é", count: 512))
        #expect(place.coordinate.latitude == 90)
        #expect(try MapPlace(coordinate: pole, name: "Pole").detail.isEmpty)
        #expect(try JSONDecoder().decode(MapPlace.self, from: JSONEncoder().encode(place)) == place)
        for name in ["", " ", "x\t", String(repeating: "é", count: 129)] {
            #expect(throws: MapPlace.ValidationError.invalidName) { try MapPlace(coordinate: pole, name: name) }
        }
        for detail in ["x\u{009B}", String(repeating: "é", count: 513)] {
            #expect(throws: MapPlace.ValidationError.invalidDetail) { try MapPlace(coordinate: pole, name: "Pole", detail: detail) }
        }
        #expect(throws: MapPlace.ValidationError.invalidName) {
            try JSONDecoder().decode(MapPlace.self, from: Data(#"{"coordinate":{"latitude":0,"longitude":0},"name":" ","detail":""}"#.utf8))
        }
        #expect(throws: MapPlace.ValidationError.invalidDetail) {
            try JSONDecoder().decode(MapPlace.self, from: Data(#"{"coordinate":{"latitude":0,"longitude":0},"name":"x","detail":"\n"}"#.utf8))
        }
        #expect(throws: MapValidationError.invalidCoordinate) {
            try JSONDecoder().decode(MapPlace.self, from: Data(#"{"coordinate":{"latitude":91,"longitude":0},"name":"x","detail":""}"#.utf8))
        }
    }

    @Test("Attribution requires safe display text and a bounded absolute uncredentialed HTTP link")
    func attributionBounds() throws {
        let url = try #require(URL(string: "https://example.com/credit"))
        let attribution = try MapPlaceMatches.Attribution(text: String(repeating: "é", count: 512), link: url)
        #expect(try JSONDecoder().decode(MapPlaceMatches.Attribution.self, from: JSONEncoder().encode(attribution)) == attribution)
        for text in ["", " ", "x\r", String(repeating: "é", count: 513)] {
            #expect(throws: MapPlaceMatches.Attribution.ValidationError.invalidText) {
                try MapPlaceMatches.Attribution(text: text, link: url)
            }
        }
        for address in ["/credit", "file:///credit", "https://user:password@example.com", "https://example.com/" + String(repeating: "a", count: 2_048)] {
            let invalid = try #require(URL(string: address))
            #expect(throws: MapPlaceMatches.Attribution.ValidationError.invalidLink) {
                try MapPlaceMatches.Attribution(text: "Credit", link: invalid)
            }
        }
        let maximumLink = try #require(URL(string: "https://example.com/" + String(repeating: "a", count: 2_028)))
        #expect(maximumLink.absoluteString.utf8.count == 2_048)
        #expect(try MapPlaceMatches.Attribution(text: "Credit", link: maximumLink).link == maximumLink)
        #expect(throws: MapPlaceMatches.Attribution.ValidationError.invalidLink) {
            try JSONDecoder().decode(MapPlaceMatches.Attribution.self, from: Data(#"{"text":"Credit","link":"https://user@example.com"}"#.utf8))
        }
    }

    @Test("Ordered match multiplicity and required credits survive coding with bounded array decoding")
    func matchesBounds() throws {
        let place = try MapPlace(coordinate: MapCoordinate(latitude: 1, longitude: 103), name: "Landmark")
        let credit = try MapPlaceMatches.Attribution(text: "Credit", link: #require(URL(string: "https://example.com")))
        let matches = try MapPlaceMatches(places: [place, place], attributions: [credit])
        #expect(matches.places.count == 2)
        #expect(try JSONDecoder().decode(MapPlaceMatches.self, from: JSONEncoder().encode(matches)) == matches)
        #expect(try MapPlaceMatches(places: [], attributions: [credit]).attributions.count == 1)
        #expect(try MapPlaceMatches(places: Array(repeating: place, count: 10), attributions: Array(repeating: credit, count: 4)).places.count == 10)
        #expect(throws: MapPlaceMatches.ValidationError.tooManyPlaces) {
            try MapPlaceMatches(places: Array(repeating: place, count: 11), attributions: [credit])
        }
        for credits in [[], Array(repeating: credit, count: 5)] {
            #expect(throws: MapPlaceMatches.ValidationError.invalidAttributionCount) {
                try MapPlaceMatches(places: [], attributions: credits)
            }
        }
        #expect(throws: MapPlaceMatches.ValidationError.invalidAttributionCount) {
            try JSONDecoder().decode(MapPlaceMatches.self, from: Data(#"{"places":[],"attributions":[]}"#.utf8))
        }
        let encodedPlace = String(decoding: try JSONEncoder().encode(place), as: UTF8.self)
        let tenPlaces = Array(repeating: encodedPlace, count: 10).joined(separator: ",")
        #expect(throws: MapPlaceMatches.ValidationError.tooManyPlaces) {
            try JSONDecoder().decode(MapPlaceMatches.self, from: Data("{\"places\":[\(tenPlaces),{}],\"attributions\":[]}".utf8))
        }
        let encodedCredit = String(decoding: try JSONEncoder().encode(credit), as: UTF8.self)
        let fourCredits = Array(repeating: encodedCredit, count: 4).joined(separator: ",")
        #expect(throws: MapPlaceMatches.ValidationError.invalidAttributionCount) {
            try JSONDecoder().decode(MapPlaceMatches.self, from: Data("{\"places\":[],\"attributions\":[\(fourCredits),{}]}".utf8))
        }
    }
}
