import Foundation

/// OSRM route responses are not geographic map-source GeoJSON documents.
/// Decode their envelope and one bounded LineString without retaining leg data.
enum OSRMRouteDecoder {
    static func decode(_ data: Data, statusCode: Int, attributions: [MapAttribution]) throws(OSRMRouter.RouteError) -> MapRouteResponse {
        guard data.count <= 2 * 1_024 * 1_024 else { throw .responseTooLarge }
        let response: Response
        do { response = try JSONDecoder().decode(Response.self, from: data) }
        catch { throw .invalidData(error) }
        switch (statusCode, response.code) {
        case (200, "Ok"):
            do {
                let success = try JSONDecoder().decode(Success.self, from: data)
                return try MapRouteResponse(route: success.route, attributions: attributions)
            } catch DecodeError.degenerateRoute { throw .unsupportedGeometry }
            catch { throw .invalidData(error) }
        case (400, "NoRoute"):
            do { return try MapRouteResponse(route: nil, attributions: attributions) }
            catch { throw .invalidData(error) }
        case (400, "NoSegment"): throw .cannotSnap
        case (400, "Ok"): throw .invalidResponse
        case (400, let code): throw .rejectedRequest(code: code)
        default: throw .invalidResponse
        }
    }

    fileprivate enum DecodeError {
        case invalidCode, invalidRouteCount, invalidGeometry, degenerateRoute
    }

    fileprivate struct Response {
        let code: String
    }

    fileprivate struct Success {
        let route: MapRouteResponse.Route
    }

    fileprivate struct Route {
        let value: MapRouteResponse.Route
    }

    fileprivate struct Geometry {
        let path: MapPolyline
    }
}

extension OSRMRouteDecoder.DecodeError: Error {}

extension OSRMRouteDecoder.Response: Decodable {
    private enum CodingKeys: String, CodingKey { case code }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        code = try values.decode(String.self, forKey: .code)
        let hasBoundedCode = !code.isEmpty && code.utf8.count <= 64
        let isIdentifier = code.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) }
        guard hasBoundedCode, isIdentifier else { throw OSRMRouteDecoder.DecodeError.invalidCode }
    }
}

extension OSRMRouteDecoder.Success: Decodable {
    private enum CodingKeys: String, CodingKey { case routes }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        var routes = try values.nestedUnkeyedContainer(forKey: .routes)
        guard routes.count == 1 else { throw OSRMRouteDecoder.DecodeError.invalidRouteCount }
        route = try routes.decode(OSRMRouteDecoder.Route.self).value
        guard routes.isAtEnd else { throw OSRMRouteDecoder.DecodeError.invalidRouteCount }
    }
}

extension OSRMRouteDecoder.Route: Decodable {
    private enum CodingKeys: String, CodingKey { case geometry, distance, duration }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // OSRM promises both metrics. Missing values are malformed here, though
        // other providers may legitimately leave either estimate unknown.
        let distance = try values.decode(Double.self, forKey: .distance)
        let duration = try values.decode(Double.self, forKey: .duration)
        let hasValidDistance = distance.isFinite && distance >= 0
        let hasValidDuration = duration.isFinite && duration >= 0
        guard hasValidDistance else { throw MapRouteResponse.Route.ValidationError.invalidDistance }
        guard hasValidDuration else { throw MapRouteResponse.Route.ValidationError.invalidDuration }
        let geometry = try values.decode(OSRMRouteDecoder.Geometry.self, forKey: .geometry)
        value = try MapRouteResponse.Route(path: geometry.path, distanceMeters: distance, durationSeconds: duration)
    }
}

extension OSRMRouteDecoder.Geometry: Decodable {
    private enum CodingKeys: String, CodingKey { case type, coordinates }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(String.self, forKey: .type) == "LineString" else {
            throw OSRMRouteDecoder.DecodeError.invalidGeometry
        }
        var positions = try values.nestedUnkeyedContainer(forKey: .coordinates)
        var coordinates: [MapCoordinate] = []
        while !positions.isAtEnd {
            guard coordinates.count < MapLimits.pathVertices else { throw MapValidationError.budgetExceeded }
            var position = try positions.nestedUnkeyedContainer()
            let longitude = try position.decode(Double.self)
            let latitude = try position.decode(Double.self)
            guard position.isAtEnd else { throw OSRMRouteDecoder.DecodeError.invalidGeometry }
            coordinates.append(try MapCoordinate(latitude: latitude, longitude: longitude))
        }
        guard coordinates.count >= 2 else { throw OSRMRouteDecoder.DecodeError.invalidGeometry }
        guard Set(coordinates).count >= 2 else { throw OSRMRouteDecoder.DecodeError.degenerateRoute }
        path = try MapPolyline(coordinates: coordinates)
    }
}
