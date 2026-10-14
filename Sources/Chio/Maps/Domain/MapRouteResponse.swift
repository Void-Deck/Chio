/// One provider route or a successful no-route observation, with required service credits.
public struct MapRouteResponse {
    /// Absence means the provider found no route; operation failures are thrown separately.
    public let route: Route?
    public let attributions: [MapAttribution]

    public init(route: Route?, attributions: [MapAttribution]) throws(ValidationError) {
        guard (1...4).contains(attributions.count) else { throw .invalidAttributionCount }
        self.route = route
        self.attributions = attributions
    }

    /// Provider geometry and available estimates, without application overlay identity.
    public struct Route {
        /// Its endpoints describe the routed line, which may differ from submitted coordinates.
        public let path: MapPolyline
        /// Absence means the provider supplies no distance estimate; zero is a known value.
        public let distanceMeters: Double?
        /// Absence means the provider supplies no duration estimate; zero is a known value.
        public let durationSeconds: Double?

        public init(path: MapPolyline, distanceMeters: Double? = nil,
                    durationSeconds: Double? = nil) throws(ValidationError) {
            if let distanceMeters {
                let isFiniteDistance = distanceMeters.isFinite
                let isNonnegativeDistance = distanceMeters >= 0
                guard isFiniteDistance, isNonnegativeDistance else { throw .invalidDistance }
            }
            if let durationSeconds {
                let isFiniteDuration = durationSeconds.isFinite
                let isNonnegativeDuration = durationSeconds >= 0
                guard isFiniteDuration, isNonnegativeDuration else { throw .invalidDuration }
            }
            self.path = path
            self.distanceMeters = distanceMeters
            self.durationSeconds = durationSeconds
        }

        public enum ValidationError { case invalidDistance, invalidDuration }
    }

    public enum ValidationError { case invalidAttributionCount }
}

extension MapRouteResponse: Codable {
    private enum CodingKeys: String, CodingKey { case route, attributions }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let route = try values.decodeIfPresent(Route.self, forKey: .route)
        var encodedAttributions = try values.nestedUnkeyedContainer(forKey: .attributions)
        var attributions: [MapAttribution] = []
        while !encodedAttributions.isAtEnd {
            guard attributions.count < 4 else { throw ValidationError.invalidAttributionCount }
            attributions.append(try encodedAttributions.decode(MapAttribution.self))
        }
        try self.init(route: route, attributions: attributions)
    }
}

extension MapRouteResponse: Hashable {}
extension MapRouteResponse: Sendable {}

extension MapRouteResponse.Route: Codable {
    private enum CodingKeys: String, CodingKey { case path, distanceMeters, durationSeconds }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(path: values.decode(MapPolyline.self, forKey: .path),
                      distanceMeters: values.decodeIfPresent(Double.self, forKey: .distanceMeters),
                      durationSeconds: values.decodeIfPresent(Double.self, forKey: .durationSeconds))
    }
}

extension MapRouteResponse.Route: Hashable {}
extension MapRouteResponse.Route: Sendable {}
extension MapRouteResponse.Route.ValidationError: Equatable {}
extension MapRouteResponse.Route.ValidationError: Error {}
extension MapRouteResponse.Route.ValidationError: Sendable {}
extension MapRouteResponse.ValidationError: Equatable {}
extension MapRouteResponse.ValidationError: Error {}
extension MapRouteResponse.ValidationError: Sendable {}
