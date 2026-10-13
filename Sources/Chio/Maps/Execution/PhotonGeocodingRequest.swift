import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Shared Photon configuration and bounded response handling. Each caller owns
/// its operation-specific query parameters and each transfer has its own lifetime.
enum PhotonGeocodingRequest {
    static func validate(endpoint: URL, userAgent: String) throws(PhotonGeocoder.ConfigurationError) {
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
    }

    static func matches(at url: URL, userAgent: String, limit: Int) async throws(PhotonGeocoder.SearchError) -> MapPlaceMatches {
        guard !Task.isCancelled else { throw .cancelled }
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
        do { matches = try PhotonPlaceDecoder.decode(response.data, limit: limit) }
        catch { throw .invalidData(error) }
        guard !Task.isCancelled else { throw .cancelled }
        return matches
    }
}
