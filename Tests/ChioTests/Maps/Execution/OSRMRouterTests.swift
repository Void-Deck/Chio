@testable import Chio
import Foundation
import Testing

struct OSRMRouterTests {
    private func credits() throws -> [MapAttribution] {
        try [MapAttribution(text: "Test data", link: #require(URL(string: "https://example.test/credits")))]
    }

    @Test("Routing requires explicit secure service configuration and credits")
    func configuration() throws {
        for address in ["https://example.test/route/v1/driving", "http://127.0.0.1:1234/route/v1/car", "http://[::1]/route/v1/foot"] {
            let endpoint = try #require(URL(string: address))
            let router = try OSRMRouter(endpoint: endpoint, userAgent: "Example/1.0", attributions: credits())
            #expect(router.endpoint == endpoint)
            #expect(router.attributions.map(\.text) == ["Test data"])
        }
        for address in ["https://example.test", "https://example.test/", "http://example.test/route", "ftp://example.test/route", "https://u:p@example.test/route",
                        "https://example.test/route?key=hidden", "https://example.test/route#hidden", "/route",
                        "https://example.test:0/route", "https://example.test/a%0Ab"] {
            let endpoint = try #require(URL(string: address))
            #expect(throws: OSRMRouter.ConfigurationError.invalidEndpoint) {
                try OSRMRouter(endpoint: endpoint, userAgent: "Tests", attributions: credits())
            }
        }
        let endpoint = try #require(URL(string: "https://example.test/route/v1/driving"))
        for userAgent in ["", " ", "Test\r\nInjected: value", "Café", String(repeating: "x", count: 257)] {
            #expect(throws: OSRMRouter.ConfigurationError.invalidUserAgent) {
                try OSRMRouter(endpoint: endpoint, userAgent: userAgent, attributions: credits())
            }
        }
        for attributions in [[], Array(repeating: try #require(credits().first), count: 5)] {
            #expect(throws: OSRMRouter.ConfigurationError.invalidAttributionCount) {
                try OSRMRouter(endpoint: endpoint, userAgent: "Tests", attributions: attributions)
            }
        }
    }

    @Test("Route URLs preserve supplied coordinate order and explicit full-geometry policy")
    func request() throws {
        let router = try OSRMRouter(endpoint: #require(URL(string: "https://example.test/prefix/route/v1/car/")),
                                    userAgent: "Tests", attributions: credits())
        let request = MapRouteRequest(origin: try MapCoordinate(latitude: 1.28, longitude: 103.85),
                                      destination: try MapCoordinate(latitude: -2.5, longitude: -70.125))
        let url = try router.requestURL(for: request)
        #expect(url.path == "/prefix/route/v1/car/103.85,1.28;-70.125,-2.5")
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(query == ["geometries": "geojson", "overview": "full", "alternatives": "false", "steps": "false",
                          "annotations": "false", "generate_hints": "false", "skip_waypoints": "true"])
    }
}
