@testable import Chio
import Foundation
import Testing

struct OSRMRouteDecoderTests {
    private func credits() throws -> [MapAttribution] {
        try [MapAttribution(text: "Fixture", link: #require(URL(string: "https://example.test/credits")))]
    }

    private func document(coordinates: String = "[[103.85,1.28],[103.86,1.29]]",
                          distance: String = "123.5", duration: String = "45.25",
                          geometry: String = "LineString") -> Data {
        Data("""
        {"code":"Ok","routes":[{"distance":\(distance),"duration":\(duration),
         "geometry":{"type":"\(geometry)","coordinates":\(coordinates)},"legs":[{"ignored":true}]}]}
        """.utf8)
    }

    @Test("OSRM preserves ordered longitude-first geometry and metre/second estimates")
    func geometryAndEstimates() throws {
        let response = try OSRMRouteDecoder.decode(document(), statusCode: 200, attributions: credits())
        let route = try #require(response.route)
        #expect(route.path.coordinates == [try MapCoordinate(latitude: 1.28, longitude: 103.85),
                                           try MapCoordinate(latitude: 1.29, longitude: 103.86)])
        #expect(route.distanceMeters == 123.5)
        #expect(route.durationSeconds == 45.25)
        #expect(response.attributions.map(\.text) == ["Fixture"])
    }

    @Test("Only HTTP 400 NoRoute is an attributed no-route response")
    func codes() throws {
        let noRoute = try OSRMRouteDecoder.decode(Data(#"{"code":"NoRoute"}"#.utf8), statusCode: 400, attributions: credits())
        #expect(noRoute.route == nil)
        #expect(noRoute.attributions.map(\.text) == ["Fixture"])
        do {
            _ = try OSRMRouteDecoder.decode(Data(#"{"code":"NoSegment"}"#.utf8), statusCode: 400, attributions: credits())
            Issue.record("Unsnappable points became no route")
        } catch OSRMRouter.RouteError.cannotSnap { }
        do {
            _ = try OSRMRouteDecoder.decode(Data(#"{"code":"InvalidQuery","message":"ignored"}"#.utf8), statusCode: 400, attributions: credits())
            Issue.record("Invalid request became no route")
        } catch OSRMRouter.RouteError.rejectedRequest(let code) { #expect(code == "InvalidQuery") }
        for (status, data) in [(200, Data(#"{"code":"NoRoute"}"#.utf8)), (400, document()), (400, document(coordinates: "[[103,1],[103,1]]")), (201, document())] {
            do {
                _ = try OSRMRouteDecoder.decode(data, statusCode: status, attributions: credits())
                Issue.record("Contradictory HTTP status/code accepted")
            } catch OSRMRouter.RouteError.invalidResponse { }
        }
    }

    @Test("Malformed geometry, metrics and success envelopes never become no route")
    func malformedResponses() throws {
        let invalid: [Data] = [
            document(coordinates: "[]"), document(coordinates: "[[103,1]]"),
            document(coordinates: "[[103,1,5],[104,2,5]]"), document(coordinates: "[[103,91],[104,2]]"),
            document(coordinates: "[[181,1],[104,2]]"), document(coordinates: "[[1],[2,3]]"),
            document(geometry: "Polygon"), document(distance: "-1"), document(duration: "-1"),
            document(distance: "null"), document(duration: "\"unknown\""),
            document(coordinates: "[[103,1],[103,1]]", distance: "-1"),
            document(coordinates: "[[103,1],[103,1]]", duration: "null"),
            Data(#"{"code":"Ok","routes":[]}"#.utf8),
            Data(#"{"code":"Ok","routes":[{},{}]}"#.utf8),
            Data(#"{"code":"NoRoute\u001b"}"#.utf8), Data("{}".utf8), Data("not json".utf8)
        ]
        for data in invalid {
            do {
                _ = try OSRMRouteDecoder.decode(data, statusCode: 200, attributions: credits())
                Issue.record("Malformed response accepted")
            } catch OSRMRouter.RouteError.invalidData { }
        }
        do {
            _ = try OSRMRouteDecoder.decode(document(coordinates: "[[103,1],[103,1]]"), statusCode: 200, attributions: credits())
            Issue.record("Degenerate route presented as a drawable path")
        } catch OSRMRouter.RouteError.unsupportedGeometry { }
    }

    @Test("Full route geometry obeys vertex and response bounds without simplifying")
    func bounds() throws {
        let positions = (0..<20_000).map { "[\(Double($0) / 1_000),1]" }
        let maximum = try OSRMRouteDecoder.decode(document(coordinates: "[\(positions.joined(separator: ","))]"),
                                                  statusCode: 200, attributions: credits())
        #expect(maximum.route?.path.coordinates.count == 20_000)
        #expect(maximum.route?.path.coordinates.last?.longitude == 19.999)
        do {
            _ = try OSRMRouteDecoder.decode(document(coordinates: "[\((positions + ["[20,1]"]).joined(separator: ","))]"),
                                            statusCode: 200, attributions: credits())
            Issue.record("Excess vertices silently truncated")
        } catch OSRMRouter.RouteError.invalidData(let error) { #expect(error as? MapValidationError == .budgetExceeded) }
        do {
            _ = try OSRMRouteDecoder.decode(Data(repeating: 32, count: 2_097_153), statusCode: 200, attributions: credits())
            Issue.record("Oversized body decoded")
        } catch OSRMRouter.RouteError.responseTooLarge { }
        let firstRoute = #"{"distance":1,"duration":1,"geometry":{"type":"LineString","coordinates":[[1,1],[2,2]]}}"#
        do {
            _ = try OSRMRouteDecoder.decode(Data("{\"code\":\"Ok\",\"routes\":[\(firstRoute),\(firstRoute)]}".utf8),
                                            statusCode: 200, attributions: credits())
            Issue.record("Unrequested alternatives silently accepted")
        } catch OSRMRouter.RouteError.invalidData { }
        let degenerate = #"{"distance":0,"duration":0,"geometry":{"type":"LineString","coordinates":[[1,1],[1,1]]}}"#
        do {
            _ = try OSRMRouteDecoder.decode(Data("{\"code\":\"Ok\",\"routes\":[\(degenerate),\(firstRoute)]}".utf8),
                                            statusCode: 200, attributions: credits())
            Issue.record("Malformed alternative count classified as a supported response")
        } catch OSRMRouter.RouteError.invalidData { }
    }
}
