import Foundation

/// Explicit reverse lookup against an application-selected Photon reverse API.
/// Supply its complete path (for example, `/reverse`); no forward URL is inferred.
/// Construction is pure and every lookup owns its independent transfer.
public struct PhotonReverseGeocoder {
    public let endpoint: URL
    public let userAgent: String

    public typealias ConfigurationError = PhotonGeocoder.ConfigurationError
    public typealias LookupError = PhotonGeocoder.SearchError

    public init(endpoint: URL, userAgent: String) throws(ConfigurationError) {
        try PhotonGeocodingRequest.validate(endpoint: endpoint, userAgent: userAgent)
        self.endpoint = endpoint
        self.userAgent = userAgent
    }
}

extension PhotonReverseGeocoder: MapReverseGeocodingProvider {
    /// Returns provider order and attribution, including an attributed empty set.
    /// Reads at most 512 KiB with a ten-second resource deadline and three
    /// same-origin redirects. No cache, history, pagination or retry is installed.
    public func reverse(_ query: MapPlaceLookup) async throws(LookupError) -> MapPlaceMatches {
        guard !Task.isCancelled else { throw .cancelled }
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw .invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "lat", value: String(query.coordinate.latitude)),
                                 URLQueryItem(name: "lon", value: String(query.coordinate.longitude)),
                                 URLQueryItem(name: "limit", value: String(query.limit))]
        guard let url = components.url else { throw .invalidResponse }
        return try await PhotonGeocodingRequest.matches(at: url, userAgent: userAgent, limit: query.limit)
    }
}

extension PhotonReverseGeocoder: Sendable {}
