import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One submitted route against an application-selected OSRM service.
/// The endpoint includes `/route/v1/{profile}`. The server's prepared graph,
/// not the profile's spelling, determines the actual mode of travel.
public struct OSRMRouter {
    public let endpoint: URL
    public let userAgent: String
    public let attributions: [MapAttribution]

    public enum ConfigurationError {
        case invalidEndpoint, invalidUserAgent, invalidAttributionCount
    }

    public enum RouteError {
        case cancelled, deadlineExceeded, invalidResponse
        case responseTooLarge, unexpectedContentType, rejectedRedirect
        /// Empty retryAfter means no usable hint; the client never retries itself.
        case httpStatus(Int, retryAfter: String)
        case cannotSnap
        case rejectedRequest(code: String)
        /// A zero-length route cannot be drawn as Chio's nondegenerate polyline.
        case unsupportedGeometry
        case transport(any Error)
        case invalidData(any Error)
    }

    /// Credits belong to the selected service and its data, even for no route.
    /// Construction validates configuration and performs no I/O.
    public init(endpoint: URL, userAgent: String, attributions: [MapAttribution]) throws(ConfigurationError) {
        do { try MapHTTPClient.validateConfiguration(endpoint: endpoint, userAgent: userAgent) }
        catch {
            switch error {
            case .invalidEndpoint: throw .invalidEndpoint
            case .invalidUserAgent: throw .invalidUserAgent
            }
        }
        // A bare host is not a route endpoint. Permit reverse-proxy prefixes
        // without inferring or hardcoding the operator's profile name.
        let hasEndpointPath = !endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty
        guard hasEndpointPath else { throw .invalidEndpoint }
        guard (1...4).contains(attributions.count) else { throw .invalidAttributionCount }
        self.endpoint = endpoint
        self.userAgent = userAgent
        self.attributions = attributions
    }

    func requestURL(for request: MapRouteRequest) throws(RouteError) -> URL {
        let coordinates = "\(request.origin.longitude),\(request.origin.latitude);\(request.destination.longitude),\(request.destination.latitude)"
        guard var components = URLComponents(url: endpoint.appendingPathComponent(coordinates), resolvingAgainstBaseURL: false) else {
            throw .invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "geometries", value: "geojson"),
            URLQueryItem(name: "overview", value: "full"),
            URLQueryItem(name: "alternatives", value: "false"),
            URLQueryItem(name: "steps", value: "false"),
            URLQueryItem(name: "annotations", value: "false"),
            URLQueryItem(name: "generate_hints", value: "false"),
            URLQueryItem(name: "skip_waypoints", value: "true")
        ]
        guard let url = components.url else { throw .invalidResponse }
        return url
    }
}

extension OSRMRouter: MapRoutingProvider {
    /// Reads at most 2 MiB within ten seconds, including at most three same-origin
    /// redirects. Geometry is full resolution and bounded to 20,000 vertices.
    /// The path's endpoints may differ from the requested coordinates after snapping.
    public func route(_ request: MapRouteRequest) async throws(RouteError) -> MapRouteResponse {
        guard !Task.isCancelled else { throw .cancelled }
        let url = try requestURL(for: request)
        let response: MapHTTPClient.Response
        do {
            response = try await MapHTTPClient.fetchResponse(url, resource: .routing,
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
        let result = try OSRMRouteDecoder.decode(response.data, statusCode: response.statusCode, attributions: attributions)
        guard !Task.isCancelled else { throw .cancelled }
        return result
    }
}

extension OSRMRouter: Sendable {}
extension OSRMRouter.ConfigurationError: Equatable {}
extension OSRMRouter.ConfigurationError: Error {}
extension OSRMRouter.RouteError: Error {}
