import Chio
import Foundation
import Testing

struct PhotonReverseGeocoderTests {
    @Test("Reverse construction retains the complete explicit endpoint and shared safe configuration")
    func configuration() throws {
        let endpoint = try #require(URL(string: "https://example.test/custom/reverse"))
        let provider = try PhotonReverseGeocoder(endpoint: endpoint, userAgent: "Example/1.0")
        #expect(provider.endpoint.absoluteString == "https://example.test/custom/reverse")
        #expect(provider.userAgent == "Example/1.0")
        for address in ["http://example.test/reverse", "https://example.test/reverse?lat=1",
                        "https://user:secret@example.test/reverse", "https://example.test/reverse#hidden"] {
            let invalid = try #require(URL(string: address))
            #expect(throws: PhotonReverseGeocoder.ConfigurationError.invalidEndpoint) {
                try PhotonReverseGeocoder(endpoint: invalid, userAgent: "Tests")
            }
        }
        #expect(throws: PhotonReverseGeocoder.ConfigurationError.invalidUserAgent) {
            try PhotonReverseGeocoder(endpoint: endpoint, userAgent: "Tests\r\nInjected: true")
        }
    }
}
