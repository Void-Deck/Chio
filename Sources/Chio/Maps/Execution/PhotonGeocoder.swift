import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Explicit, submitted place search against an application-selected Photon API.
/// The endpoint includes its API path (for example, `/api`). Construction is pure;
/// each search owns its transfer and never cancels another consumer's request.
public struct PhotonGeocoder {
    public let endpoint: URL
    public let userAgent: String

    public enum ConfigurationError {
        case invalidEndpoint, invalidUserAgent
    }

    public enum SearchError {
        case cancelled, deadlineExceeded, invalidResponse
        case responseTooLarge, unexpectedContentType, rejectedRedirect
        /// Empty retryAfter means the server supplied no valid, bounded hint.
        /// This is metadata only; the client never automatically retries.
        case httpStatus(Int, retryAfter: String)
        case transport(any Error)
        case invalidData(any Error)
    }

    public init(endpoint: URL, userAgent: String) throws(ConfigurationError) {
        try PhotonGeocodingRequest.validate(endpoint: endpoint, userAgent: userAgent)
        self.endpoint = endpoint
        self.userAgent = userAgent
    }
}

extension PhotonGeocoder: MapGeocodingProvider {
    /// Returns provider order and attribution, including an attributed empty set.
    /// At most 512 KiB is read with a ten-second resource deadline and three
    /// same-origin redirects. No cache, history, pagination or retry is installed.
    public func search(_ query: MapPlaceQuery) async throws(SearchError) -> MapPlaceMatches {
        guard !Task.isCancelled else { throw .cancelled }
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw .invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "q", value: query.text),
                                 URLQueryItem(name: "limit", value: String(query.limit))]
        // Photon uses form-style query parsing, where an unescaped plus is a
        // space. URLComponents otherwise leaves literal plus signs untouched.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw .invalidResponse }
        return try await PhotonGeocodingRequest.matches(at: url, userAgent: userAgent, limit: query.limit)
    }
}

extension PhotonGeocoder.ConfigurationError: Equatable {}
extension PhotonGeocoder.ConfigurationError: Error {}

extension PhotonGeocoder.SearchError: Error {}

extension PhotonGeocoder: Sendable {}
