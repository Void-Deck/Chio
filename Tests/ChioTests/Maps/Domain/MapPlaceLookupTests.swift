import Chio
import Foundation
import Testing

struct MapPlaceLookupTests {
    @Test("Coordinate lookup preserves geographic endpoints and validates requested counts")
    func construction() throws {
        let coordinate = try MapCoordinate(latitude: 90, longitude: -180)
        let lookup = try MapPlaceLookup(coordinate: coordinate)
        #expect(lookup.coordinate.latitude == 90)
        #expect(lookup.coordinate.longitude == -180)
        #expect(lookup.limit == 1)
        #expect(try MapPlaceLookup(coordinate: coordinate, limit: 10).limit == 10)
        for limit in [Int.min, -1, 0, 11, Int.max] {
            #expect(throws: MapPlaceLookup.ValidationError.invalidLimit) {
                try MapPlaceLookup(coordinate: coordinate, limit: limit)
            }
        }
    }

    @Test("Lookup coding uses checked coordinates and limits rather than bypassing either invariant")
    func coding() throws {
        let document = Data(#"{"coordinate":{"latitude":-90,"longitude":180},"limit":10}"#.utf8)
        let lookup = try JSONDecoder().decode(MapPlaceLookup.self, from: document)
        #expect(lookup.coordinate.latitude == -90)
        #expect(lookup.coordinate.longitude == 180)
        #expect(lookup.limit == 10)
        let encoded = try JSONEncoder().encode(lookup)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let coordinate = try #require(object["coordinate"] as? [String: Any])
        #expect(object["limit"] as? Int == 10)
        #expect(coordinate["latitude"] as? Double == -90)
        #expect(coordinate["longitude"] as? Double == 180)
        for limit in [0, 11, Int.max] {
            let invalid = Data("{\"coordinate\":{\"latitude\":0,\"longitude\":0},\"limit\":\(limit)}".utf8)
            #expect(throws: MapPlaceLookup.ValidationError.invalidLimit) {
                try JSONDecoder().decode(MapPlaceLookup.self, from: invalid)
            }
        }
        for ordinates in [#""latitude":91,"longitude":0"#, #""latitude":0,"longitude":181"#] {
            let invalid = Data("{\"coordinate\":{\(ordinates)},\"limit\":1}".utf8)
            #expect(throws: MapValidationError.invalidCoordinate) {
                try JSONDecoder().decode(MapPlaceLookup.self, from: invalid)
            }
        }
    }
}
