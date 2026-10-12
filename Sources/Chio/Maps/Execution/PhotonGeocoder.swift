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
        let isAbsolute = endpoint.baseURL == nil
        let hasBoundedURL = endpoint.absoluteString.utf8.count <= 2_048
        guard isAbsolute, hasBoundedURL,
              let components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false),
              let host = components.host, !host.isEmpty else { throw .invalidEndpoint }
        let hasCredentials = components.user != nil || components.password != nil
        let hasQueryOrFragment = components.query != nil || components.fragment != nil
        let hasInvalidPort = components.port.map { !(1...65_535).contains($0) } ?? false
        let hasControls = components.path.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
        let isHTTPS = components.scheme?.lowercased() == "https"
        let isLoopback = ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host.lowercased())
        let isLocalHTTP = components.scheme?.lowercased() == "http" && isLoopback
        guard !hasCredentials, !hasQueryOrFragment, !hasInvalidPort, !hasControls,
              isHTTPS || isLocalHTTP else { throw .invalidEndpoint }
        let hasIdentity = !userAgent.trimmingCharacters(in: .whitespaces).isEmpty
        let hasBoundedIdentity = userAgent.utf8.count <= 256
        let isHeaderText = userAgent.utf8.allSatisfy { (32...126).contains($0) }
        guard hasIdentity, hasBoundedIdentity, isHeaderText else { throw .invalidUserAgent }
        self.endpoint = endpoint
        self.userAgent = userAgent
    }
}

extension PhotonGeocoder: Sendable {}
extension PhotonGeocoder.ConfigurationError: Error {}
extension PhotonGeocoder.ConfigurationError: Equatable {}
extension PhotonGeocoder.SearchError: Error {}

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
        let response: MapHTTPClient.Response
        do {
            response = try await MapHTTPClient.fetchResponse(url, resource: .geocoding,
                                                             userAgent: userAgent, timeout: 10)
        } catch let failure as MapHTTPClient.Failure {
            switch failure {
            case .invalidResponse: throw .invalidResponse
            case .unexpectedContentType: throw .unexpectedContentType
            case .responseTooLarge: throw .responseTooLarge
            case .rejectedRedirect: throw .rejectedRedirect
            case .httpStatus(let status, let retryAfter): throw .httpStatus(status, retryAfter: retryAfter)
            }
        } catch is CancellationError { throw .cancelled }
        catch let error as URLError {
            switch error.code {
            case .cancelled: throw .cancelled
            case .timedOut: throw .deadlineExceeded
            default: throw .transport(error)
            }
        } catch { throw .transport(error) }
        guard !Task.isCancelled else { throw .cancelled }
        let matches: MapPlaceMatches
        do { matches = try PhotonPlaceDecoder.decode(response.data, query: query) }
        catch { throw .invalidData(error) }
        guard !Task.isCancelled else { throw .cancelled }
        return matches
    }
}
