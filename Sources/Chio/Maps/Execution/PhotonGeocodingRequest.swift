import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Shared Photon configuration and bounded response handling. Each caller owns
/// its operation-specific query parameters and each transfer has its own lifetime.
enum PhotonGeocodingRequest {
    static func validate(endpoint: URL, userAgent: String) throws(PhotonGeocoder.ConfigurationError) {
        do { try MapHTTPClient.validateConfiguration(endpoint: endpoint, userAgent: userAgent) }
        catch {
            switch error {
            case .invalidEndpoint: throw .invalidEndpoint
            case .invalidUserAgent: throw .invalidUserAgent
            }
        }
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
