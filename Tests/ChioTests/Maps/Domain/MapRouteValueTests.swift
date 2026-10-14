import Chio
import Foundation
import Testing

struct MapRouteValueTests {
    @Test("Submitted endpoints preserve their order, poles and equal-coordinate requests")
    func requestCoordinates() throws {
        let origin = try MapCoordinate(latitude: 90, longitude: -180)
        let destination = try MapCoordinate(latitude: -90, longitude: 180)
        let request = MapRouteRequest(origin: origin, destination: destination)
        let decoded = try JSONDecoder().decode(MapRouteRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded.origin.latitude == 90)
        #expect(decoded.origin.longitude == -180)
        #expect(decoded.destination.latitude == -90)
        #expect(decoded.destination.longitude == 180)
        #expect(MapRouteRequest(origin: origin, destination: origin).destination == origin)
        #expect(throws: MapValidationError.invalidCoordinate) {
            try JSONDecoder().decode(MapRouteRequest.self, from: Data(#"{"origin":{"latitude":91,"longitude":0},"destination":{"latitude":0,"longitude":0}}"#.utf8))
        }
    }

    @Test("Missing estimates remain distinct from known zero and reject nonfinite or negative values")
    func estimates() throws {
        let path = try fixturePath()
        let unknown = try MapRouteResponse.Route(path: path)
        let zero = try MapRouteResponse.Route(path: path, distanceMeters: 0, durationSeconds: 0)
        #expect(unknown.distanceMeters == nil)
        #expect(unknown.durationSeconds == nil)
        #expect(zero.distanceMeters == 0)
        #expect(zero.durationSeconds == 0)
        #expect(unknown != zero)
        #expect(try JSONDecoder().decode(MapRouteResponse.Route.self, from: JSONEncoder().encode(zero)) == zero)
        for invalid in [-1, Double.infinity, -Double.infinity, Double.nan] {
            #expect(throws: MapRouteResponse.Route.ValidationError.invalidDistance) {
                try MapRouteResponse.Route(path: path, distanceMeters: invalid)
            }
            #expect(throws: MapRouteResponse.Route.ValidationError.invalidDuration) {
                try MapRouteResponse.Route(path: path, durationSeconds: invalid)
            }
        }
        let encodedPath = String(decoding: try JSONEncoder().encode(path), as: UTF8.self)
        for metrics in ["", ",\"distanceMeters\":null,\"durationSeconds\":null"] {
            let document = Data("{\"path\":\(encodedPath)\(metrics)}".utf8)
            let decoded = try JSONDecoder().decode(MapRouteResponse.Route.self, from: document)
            #expect(decoded.distanceMeters == nil)
            #expect(decoded.durationSeconds == nil)
        }
        #expect(throws: MapRouteResponse.Route.ValidationError.invalidDistance) {
            try JSONDecoder().decode(MapRouteResponse.Route.self, from: Data("{\"path\":\(encodedPath),\"distanceMeters\":-1}".utf8))
        }
        #expect(throws: MapRouteResponse.Route.ValidationError.invalidDuration) {
            try JSONDecoder().decode(MapRouteResponse.Route.self, from: Data("{\"path\":\(encodedPath),\"durationSeconds\":-1}".utf8))
        }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        #expect(throws: MapRouteResponse.Route.ValidationError.invalidDistance) {
            try decoder.decode(MapRouteResponse.Route.self, from: Data("{\"path\":\(encodedPath),\"distanceMeters\":\"Infinity\"}".utf8))
        }
        #expect(throws: MapRouteResponse.Route.ValidationError.invalidDuration) {
            try decoder.decode(MapRouteResponse.Route.self, from: Data("{\"path\":\(encodedPath),\"durationSeconds\":\"NaN\"}".utf8))
        }
    }

    @Test("Route and no-route responses require bounded credits through construction and decoding")
    func responseCredits() throws {
        let credit = try fixtureCredit()
        let route = try MapRouteResponse.Route(path: fixturePath(), distanceMeters: 125, durationSeconds: 30)
        let routed = try MapRouteResponse(route: route, attributions: [credit])
        let noRoute = try MapRouteResponse(route: nil, attributions: [credit])
        #expect(routed.route?.distanceMeters == 125)
        #expect(noRoute.route == nil)
        #expect(noRoute.attributions == [credit])
        #expect(try JSONDecoder().decode(MapRouteResponse.self, from: JSONEncoder().encode(routed)) == routed)
        #expect(try JSONDecoder().decode(MapRouteResponse.self, from: JSONEncoder().encode(noRoute)) == noRoute)
        #expect(try MapRouteResponse(route: nil, attributions: Array(repeating: credit, count: 4)).attributions.count == 4)
        for credits in [[], Array(repeating: credit, count: 5)] {
            #expect(throws: MapRouteResponse.ValidationError.invalidAttributionCount) {
                try MapRouteResponse(route: nil, attributions: credits)
            }
        }
        #expect(throws: MapRouteResponse.ValidationError.invalidAttributionCount) {
            try JSONDecoder().decode(MapRouteResponse.self, from: Data(#"{"route":null,"attributions":[]}"#.utf8))
        }
        let encodedCredit = String(decoding: try JSONEncoder().encode(credit), as: UTF8.self)
        let fourCredits = Array(repeating: encodedCredit, count: 4).joined(separator: ",")
        #expect(throws: MapRouteResponse.ValidationError.invalidAttributionCount) {
            try JSONDecoder().decode(MapRouteResponse.self, from: Data("{\"attributions\":[\(fourCredits),{}]}".utf8))
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MapRouteResponse.self, from: Data(#"{"route":null}"#.utf8))
        }
    }

    @Test("Routing inherits the existing path admission bound without repairing degenerate geometry")
    func pathAdmission() throws {
        let origin = try MapCoordinate(latitude: 1, longitude: 103)
        let destination = try MapCoordinate(latitude: 1.01, longitude: 103.01)
        let coordinates = (0..<20_000).map { index in index.isMultiple(of: 2) ? origin : destination }
        let route = try MapRouteResponse.Route(path: MapPolyline(coordinates: coordinates))
        #expect(route.path.coordinates.count == 20_000)
        #expect(throws: MapValidationError.budgetExceeded) {
            try MapRouteResponse.Route(path: MapPolyline(coordinates: coordinates + [origin]))
        }
        #expect(throws: MapValidationError.invalidPath) {
            try MapRouteResponse.Route(path: MapPolyline(coordinates: [origin, origin]))
        }
        #expect(throws: MapValidationError.invalidPath) {
            try JSONDecoder().decode(MapRouteResponse.Route.self, from: Data(#"{"path":{"coordinates":[{"latitude":1,"longitude":103},{"latitude":1,"longitude":103}]}}"#.utf8))
        }
    }

    @Test("Shared attribution retains the original public spelling and literal wire representation")
    func attributionCompatibility() throws {
        let document = Data(#"{"text":"Provider credit","link":"https://example.test/credit"}"#.utf8)
        let shared = try JSONDecoder().decode(MapAttribution.self, from: document)
        let legacy: MapPlaceMatches.Attribution = try JSONDecoder().decode(MapPlaceMatches.Attribution.self, from: document)
        #expect(shared == legacy)
        #expect(shared.text == "Provider credit")
        #expect(shared.link.absoluteString == "https://example.test/credit")
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(shared)) as? [String: String])
        #expect(encoded == ["text": "Provider credit", "link": "https://example.test/credit"])
        #expect(throws: MapPlaceMatches.Attribution.ValidationError.invalidText) {
            try MapAttribution(text: "\n", link: shared.link)
        }
        #expect(throws: MapAttribution.ValidationError.invalidLink) {
            try JSONDecoder().decode(MapAttribution.self, from: Data(#"{"text":"Credit","link":"https://user@example.test"}"#.utf8))
        }
    }

    private func fixturePath() throws -> MapPolyline {
        try MapPolyline(coordinates: [MapCoordinate(latitude: 1, longitude: 103),
                                      MapCoordinate(latitude: 1.01, longitude: 103.01)])
    }

    private func fixtureCredit() throws -> MapAttribution {
        try MapAttribution(text: "Provider credit", link: #require(URL(string: "https://example.test/credit")))
    }
}
