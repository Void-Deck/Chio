import Chio
import Foundation
import Testing

struct PhotonGeocoderTests {
    @Test("Photon configuration requires an explicit safe endpoint and application identity")
    func configuration() throws {
        for address in ["https://example.test/api", "http://127.0.0.1:1234/api", "http://[::1]:1234/api", "http://localhost/api"] {
            let endpoint = try #require(URL(string: address))
            let provider = try PhotonGeocoder(endpoint: endpoint, userAgent: "Example/1.0 (contact@example.test)")
            #expect(provider.endpoint == endpoint)
            #expect(provider.userAgent == "Example/1.0 (contact@example.test)")
        }
        for address in ["http://example.test/api", "ftp://example.test/api", "https://user:secret@example.test/api",
                        "https://example.test/api?q=hidden", "https://example.test/api#fragment", "https://example.test/api?",
                        "https://example.test:0/api", "https://example.test:65536/api", "https://example.test/a%0Ab",
                        "https://example.test/" + String(repeating: "a", count: 2_048), "/api"] {
            let endpoint = try #require(URL(string: address))
            #expect(throws: PhotonGeocoder.ConfigurationError.invalidEndpoint) {
                try PhotonGeocoder(endpoint: endpoint, userAgent: "Tests")
            }
        }
        let endpoint = try #require(URL(string: "https://example.test/api"))
        for identity in ["", "   ", "Name\r\nOther: value", "Name\t", "Café", String(repeating: "a", count: 257)] {
            #expect(throws: PhotonGeocoder.ConfigurationError.invalidUserAgent) {
                try PhotonGeocoder(endpoint: endpoint, userAgent: identity)
            }
        }
        let maximum = try PhotonGeocoder(endpoint: endpoint, userAgent: String(repeating: "a", count: 256))
        #expect(maximum.userAgent.utf8.count == 256)
    }
}
