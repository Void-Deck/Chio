@testable import Chio
import Dispatch
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Synchronization
import Testing
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct MapHTTPClientTests {
    @Test("Resource policies retain exact byte bounds, request headers and MIME alternatives")
    func resourcePolicies() async throws {
        let policies: [(resource: MapHTTPClient.Resource, limit: Int, accept: String,
                        accepted: [String], rejected: [String])] = [
            (.catalog, 262_144, "application/json", ["application/json", "text/json", "APPLICATION/JSON"],
             ["application/octet-stream", "application/x-protobuf", "text/html"]),
            (.tile, 16_777_216, "application/vnd.mapbox-vector-tile, application/x-protobuf, application/octet-stream",
             ["application/vnd.mapbox-vector-tile", "application/x-protobuf", "application/protobuf",
              "application/octet-stream", "APPLICATION/X-PROTOBUF"], ["application/json", "text/json", "text/html"]),
        ]
        try await withServer { server in
            for policy in policies {
                for mime in policy.accepted {
                    let response = try await bounded("accept \(mime)") {
                        try await MapHTTPClient.fetch(server.url("/policy?mime=\(mime)&bytes=0"), resource: policy.resource)
                    }
                    #expect(response.data.isEmpty)
                    #expect(response.headers["x-observed-accept"] == policy.accept)
                    #expect(response.headers["x-observed-user-agent"] == "Chio OpenMapTiles")
                }
                for mime in policy.rejected {
                    await #expect(throws: MapTileLoader.LoadingError.unexpectedContentType) {
                        try await bounded("reject \(mime)") {
                            try await MapHTTPClient.fetch(server.url("/policy?mime=\(mime)&bytes=0"), resource: policy.resource)
                        }
                    }
                }
                let exact = try await bounded("exact resource byte limit") {
                    try await MapHTTPClient.fetch(server.url("/policy?mime=\(policy.accepted[0])&bytes=\(policy.limit)"), resource: policy.resource)
                }
                #expect(exact.data.count == policy.limit)
                await #expect(throws: MapTileLoader.LoadingError.responseTooLarge) {
                    try await bounded("over resource byte limit") {
                        try await MapHTTPClient.fetch(server.url("/policy?mime=\(policy.accepted[0])&bytes=\(policy.limit + 1)"), resource: policy.resource)
                    }
                }
            }
        }
    }

    @Test("Routing preserves HTTP 200 and 400 bodies while other resources still reject 400 before body admission")
    func routingTransportStatuses() async throws {
        try await withServer { server in
            for (status, body) in [(200, #"{"code":"Ok"}"#), (400, #"{"code":"NoRoute"}"#)] {
                let response = try await bounded("routing accepted status and body") {
                    try await MapHTTPClient.fetchResponse(server.url("/routing-response?status=\(status)"),
                        resource: .routing, userAgent: "Chio Routing Tests", timeout: 10)
                }
                #expect(response.statusCode == status)
                #expect(response.data == Data(body.utf8))
                #expect(response.headers["x-observed-accept"] == "application/json")
                #expect(response.headers["x-observed-user-agent"] == "Chio Routing Tests")
            }
            for status in [201, 404, 429, 500] {
                do {
                    _ = try await bounded("routing rejected status") {
                        try await MapHTTPClient.fetchResponse(server.url("/routing-response?status=\(status)"),
                            resource: .routing, userAgent: "Tests", timeout: 10)
                    }
                    Issue.record("Routing accepted HTTP \(status)")
                } catch MapHTTPClient.Failure.httpStatus(let actual, let retryAfter) {
                    #expect(actual == status)
                    #expect(retryAfter == "30")
                }
            }
            let rejectedURL = server.url("/policy?status=400&mime=text/html&bytes=2097153")
            do {
                _ = try await bounded("geocoding rejects routing status") {
                    try await MapHTTPClient.fetchResponse(rejectedURL, resource: .geocoding, userAgent: "Tests", timeout: 10)
                }
                Issue.record("Geocoding admitted HTTP 400")
            } catch MapHTTPClient.Failure.httpStatus(let status, let retryAfter) {
                #expect(status == 400)
                #expect(retryAfter.isEmpty)
            }
            for resource in [MapHTTPClient.Resource.tile, .catalog] {
                await #expect(throws: MapTileLoader.LoadingError.httpStatus(400)) {
                    try await bounded("tile or catalog rejects routing status") {
                        try await MapHTTPClient.fetch(rejectedURL, resource: resource)
                    }
                }
            }
        }
    }

    @Test("Routing requires explicit JSON and bounds HTTP 200 and 400 decompressed bodies at two MiB")
    func routingTransportBoundsAndMIME() async throws {
        try await withServer { server in
            for status in [200, 400] {
                for mime in ["application/json", "APPLICATION/JSON", "application/json;charset=utf-8"] {
                    let response = try await bounded("routing accepted JSON MIME") {
                        try await MapHTTPClient.fetchResponse(server.url("/policy?status=\(status)&mime=\(mime)&bytes=0"),
                            resource: .routing, userAgent: "Tests", timeout: 10)
                    }
                    #expect(response.statusCode == status)
                    #expect(response.data.isEmpty)
                }
                for mime in ["application/geo+json", "text/json", "text/html", "application/octet-stream",
                             "", "   ", "\"application/json\"", "application/json, text/html"] {
                    var components = URLComponents(url: server.url("/policy"), resolvingAgainstBaseURL: false)!
                    components.queryItems = [URLQueryItem(name: "status", value: String(status)),
                                             URLQueryItem(name: "mime", value: mime), URLQueryItem(name: "bytes", value: "0")]
                    components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
                    let url = components.url!
                    do {
                        _ = try await bounded("routing rejected JSON MIME") {
                            try await MapHTTPClient.fetchResponse(url, resource: .routing, userAgent: "Tests", timeout: 10)
                        }
                        Issue.record("Routing accepted invalid explicit Content-Type")
                    } catch MapHTTPClient.Failure.unexpectedContentType { }
                }
                do {
                    _ = try await bounded("routing requires explicit MIME") {
                        try await MapHTTPClient.fetchResponse(server.url("/policy.json?status=\(status)&bytes=0"),
                            resource: .routing, userAgent: "Tests", timeout: 10)
                    }
                    Issue.record("Routing accepted inferred JSON MIME without Content-Type")
                } catch MapHTTPClient.Failure.unexpectedContentType { }
                let exact = try await bounded("routing exact byte limit") {
                    try await MapHTTPClient.fetchResponse(server.url("/policy?status=\(status)&mime=application/json&bytes=2097152"),
                        resource: .routing, userAgent: "Tests", timeout: 10)
                }
                #expect(exact.statusCode == status)
                #expect(exact.data.count == 2_097_152)
                for path in ["/policy?mime=application/json&bytes=2097153&status=\(status)",
                             "/routing-gzip?status=\(status)", "/routing-stream?status=\(status)"] {
                    let acknowledgments = Mutex(0)
                    do {
                        _ = try await bounded("routing decompressed byte overflow") {
                            try await MapHTTPClient.fetchResponse(server.url(path), resource: .routing, userAgent: "Tests", timeout: 10,
                                onTerminalAcknowledgement: { acknowledgments.withLock { $0 += 1 } })
                        }
                        Issue.record("Routing admitted oversized HTTP \(status) data")
                    } catch MapHTTPClient.Failure.responseTooLarge { }
                    #expect(acknowledgments.withLock { $0 } == 1)
                }
            }
        }
    }

    @Test("An accepted routing HTTP 400 body retains the transfer deadline and terminal acknowledgement")
    func routingTransportDeadline() async throws {
        try await withServer { server in
            let acknowledgments = Mutex(0)
            do {
                _ = try await bounded("routing HTTP 400 body deadline") {
                    try await MapHTTPClient.fetchResponse(server.url("/routing-deadline"), resource: .routing,
                        userAgent: "Tests", timeout: 0.25,
                        onTerminalAcknowledgement: { acknowledgments.withLock { $0 += 1 } })
                }
                Issue.record("Routing HTTP 400 body exceeded its transfer deadline")
            } catch let error as URLError { #expect(error.code == .timedOut) }
            #expect(acknowledgments.withLock { $0 } == 1)
        }
    }

    @Test("The OSRM client submits ordered longitude-latitude endpoints and fixed options, retaining snapped geometry and credits")
    func osrmLoopbackRoute() async throws {
        try await withServer { server in
            let attributions = try routingAttributions()
            let router = try OSRMRouter(endpoint: server.url("/osrm-ok/route/v1/driving"),
                                        userAgent: "Chio Routing Tests", attributions: attributions)
            let response = try await bounded("OSRM route request and response") { try await router.route(routingRequest()) }
            let route = try #require(response.route)
            #expect(route.path.coordinates.map(\.longitude) == [103.751, 103.8, 103.849])
            #expect(route.path.coordinates.map(\.latitude) == [1.251, 1.29, 1.349])
            #expect(route.distanceMeters == 1_234.5)
            #expect(route.durationSeconds == 321.25)
            #expect(response.attributions.map(\.text) == ["Fixture routing service", "Fixture road data"])
            #expect(response.attributions.map { $0.link.absoluteString } == ["https://example.test/router", "https://example.test/roads"])
            let observed = try await MapHTTPClient.fetch(server.url("/osrm-observed"), resource: .catalog)
            let requests = try JSONDecoder().decode([[String: String]].self, from: observed.data)
            #expect(requests == [[
                "path": "/osrm-ok/route/v1/driving/103.75,1.25;103.85,1.35",
                "query": "alternatives=false&annotations=false&generate_hints=false&geometries=geojson&overview=full&skip_waypoints=true&steps=false",
                "userAgent": "Chio Routing Tests", "accept": "application/json"
            ]])
        }
    }

    @Test("The OSRM client distinguishes no route, snapping and provider rejection from malformed or inconsistent responses")
    func osrmLoopbackFailures() async throws {
        try await withServer { server in
            let attributions = try routingAttributions()
            let request = try routingRequest()
            let noRoute = try OSRMRouter(endpoint: server.url("/osrm-no-route/route/v1/driving"),
                                         userAgent: "Chio Routing Tests", attributions: attributions)
            let empty = try await bounded("OSRM HTTP 400 no route") { try await noRoute.route(request) }
            #expect(empty.route == nil)
            #expect(empty.attributions == attributions)
            let noSegment = try OSRMRouter(endpoint: server.url("/osrm-no-segment/route/v1/driving"),
                                           userAgent: "Chio Routing Tests", attributions: attributions)
            do {
                _ = try await bounded("OSRM cannot snap") { try await noSegment.route(request) }
                Issue.record("OSRM NoSegment became a route response")
            } catch OSRMRouter.RouteError.cannotSnap { }
            let invalidQuery = try OSRMRouter(endpoint: server.url("/osrm-invalid-query/route/v1/driving"),
                                              userAgent: "Chio Routing Tests", attributions: attributions)
            do {
                _ = try await bounded("OSRM rejected request") { try await invalidQuery.route(request) }
                Issue.record("OSRM InvalidQuery became a route response")
            } catch OSRMRouter.RouteError.rejectedRequest(let code) { #expect(code == "InvalidQuery") }
            for mode in ["malformed", "bad-geometry"] {
                let router = try OSRMRouter(endpoint: server.url("/osrm-\(mode)/route/v1/driving"),
                                            userAgent: "Chio Routing Tests", attributions: attributions)
                do {
                    _ = try await bounded("OSRM invalid data") { try await router.route(request) }
                    Issue.record("OSRM malformed body or geometry became a route response")
                } catch OSRMRouter.RouteError.invalidData { }
            }
            for mode in ["wrong-status", "ok-error"] {
                let router = try OSRMRouter(endpoint: server.url("/osrm-\(mode)/route/v1/driving"),
                                            userAgent: "Chio Routing Tests", attributions: attributions)
                do {
                    _ = try await bounded("OSRM inconsistent status and code") { try await router.route(request) }
                    Issue.record("OSRM inconsistent status and code became a route response")
                } catch OSRMRouter.RouteError.invalidResponse { }
            }
            let throttled = try OSRMRouter(endpoint: server.url("/osrm-throttled/route/v1/driving"),
                                           userAgent: "Chio Routing Tests", attributions: attributions)
            do {
                _ = try await bounded("OSRM HTTP rejection metadata") { try await throttled.route(request) }
                Issue.record("OSRM HTTP 429 became a route response")
            } catch OSRMRouter.RouteError.httpStatus(let status, let retryAfter) {
                #expect(status == 429)
                #expect(retryAfter == "30")
            }
        }
    }

    @Test("The OSRM client acknowledges in-flight cancellation and enforces its public ten-second deadline")
    func osrmLoopbackCancellationAndDeadline() async throws {
        try await withServer { server in
            let attributions = try routingAttributions()
            let request = try routingRequest()
            let slow = try OSRMRouter(endpoint: server.url("/osrm-slow/route/v1/driving"),
                                      userAgent: "Chio Routing Tests", attributions: attributions)
            let pending = Task { try await slow.route(request) }
            defer { pending.cancel() }
            try await bounded("OSRM transfer entered") {
                while true {
                    let response = try await MapHTTPClient.fetch(server.url("/started"), resource: .catalog)
                    if String(decoding: response.data, as: UTF8.self) == "true" { return }
                    try await Task.sleep(for: .milliseconds(10))
                }
            }
            pending.cancel()
            do {
                _ = try await bounded("OSRM cancellation acknowledgement") { try await pending.value }
                Issue.record("Cancelled OSRM request succeeded")
            } catch OSRMRouter.RouteError.cancelled { }
            let deadline = try OSRMRouter(endpoint: server.url("/osrm-deadline/route/v1/driving"),
                                          userAgent: "Chio Routing Tests", attributions: attributions)
            do {
                _ = try await bounded("OSRM public ten-second deadline", timeout: .seconds(11)) { try await deadline.route(request) }
                Issue.record("OSRM request exceeded its public ten-second deadline")
            } catch OSRMRouter.RouteError.deadlineExceeded { }
        }
    }

    private func routingRequest() throws -> MapRouteRequest {
        try MapRouteRequest(origin: MapCoordinate(latitude: 1.25, longitude: 103.75),
                            destination: MapCoordinate(latitude: 1.35, longitude: 103.85))
    }

    private func routingAttributions() throws -> [MapAttribution] {
        try [MapAttribution(text: "Fixture routing service", link: URL(string: "https://example.test/router")!),
             MapAttribution(text: "Fixture road data", link: URL(string: "https://example.test/roads")!)]
    }

    @Test("Photon sends submitted text and identity, preserves order, and distinguishes empty matches")
    func photonSearch() async throws {
        try await withServer { server in
            let geocoder = try PhotonGeocoder(endpoint: server.url("/photon"), userAgent: "Chio Tests/1.0")
            let query = try MapPlaceQuery(text: "Café + quay & marina", limit: 2)
            let matches = try await bounded("Photon query and Unicode decoding") { try await geocoder.search(query) }
            #expect(matches.places.map(\.name) == ["Café + quay & marina", "Second"])
            #expect(matches.places[0].coordinate.latitude == 1.3)
            #expect(matches.places[0].coordinate.longitude == 103.8)
            #expect(matches.places[0].detail == "Chio Tests/1.0")
            #expect(matches.attributions.map(\.text).contains("© OpenStreetMap contributors"))
            let empty = try await bounded("Photon no matches") { try await geocoder.search(MapPlaceQuery(text: "empty")) }
            #expect(empty.places.isEmpty)
            #expect(!empty.attributions.isEmpty)
            let bad = try PhotonGeocoder(endpoint: server.url("/photon-invalid"), userAgent: "Chio Tests/1.0")
            do {
                _ = try await bounded("Photon malformed JSON") { try await bad.search(query) }
                Issue.record("Malformed JSON became successful matches")
            } catch PhotonGeocoder.SearchError.invalidData { }
            let cancelled = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await geocoder.search(query)
            }
            do { _ = try await cancelled.value; Issue.record("Cancelled Photon search succeeded") }
            catch PhotonGeocoder.SearchError.cancelled { }
        }
    }

    @Test("Photon reverse lookup sends only latitude, longitude and limit to its explicit path")
    func photonReverseLookup() async throws {
        try await withServer { server in
            let provider = try PhotonReverseGeocoder(endpoint: server.url("/custom/reverse"), userAgent: "Chio Reverse Tests/1.0")
            let query = try MapPlaceLookup(coordinate: MapCoordinate(latitude: 1.25, longitude: -73.5), limit: 3)
            let matches = try await bounded("Photon reverse wire coordinates") { try await provider.reverse(query) }
            #expect(matches.places.map(\.name) == ["Reverse", "Pole", "Reverse"])
            #expect(matches.places[0].coordinate.latitude == 1.3)
            #expect(matches.places[0].coordinate.longitude == 103.8)
            #expect(matches.places[0].detail == "lat=1.25;lon=-73.5;limit=3;keys=lat,limit,lon;ua=Chio Reverse Tests/1.0")
            #expect(matches.places[1].coordinate.latitude == -90)
            #expect(matches.places[1].coordinate.longitude == 180)
            #expect(matches.places[0] == matches.places[2])
            #expect(matches.attributions.map(\.text) == ["Photon", "© OpenStreetMap contributors"])
            let polar = try MapPlaceLookup(coordinate: MapCoordinate(latitude: 90, longitude: -180))
            let one = try await bounded("Photon reverse default limit and polar input") { try await provider.reverse(polar) }
            #expect(one.places.count == 1)
            #expect(one.places[0].detail == "lat=90.0;lon=-180.0;limit=1;keys=lat,limit,lon;ua=Chio Reverse Tests/1.0")
            let emptyQuery = try MapPlaceLookup(coordinate: MapCoordinate(latitude: 0, longitude: 0))
            let empty = try await bounded("Photon reverse no matches") { try await provider.reverse(emptyQuery) }
            #expect(empty.places.isEmpty)
            #expect(empty.attributions.map { $0.link.absoluteString } == ["https://photon.komoot.io", "https://www.openstreetmap.org/copyright"])
            let redirected = try PhotonReverseGeocoder(endpoint: server.url("/reverse-redirect"), userAgent: "Tests")
            let redirectMatches = try await bounded("Photon reverse same-origin redirect") { try await redirected.reverse(query) }
            #expect(redirectMatches.places.map(\.name) == ["Reverse", "Pole", "Reverse"])
            #expect(redirectMatches.places[0].detail == "lat=1.25;lon=-73.5;limit=3;keys=lat,limit,lon;ua=Tests")
            let cancelled = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await provider.reverse(query)
            }
            do { _ = try await cancelled.value; Issue.record("Precancelled reverse lookup succeeded") }
            catch PhotonReverseGeocoder.LookupError.cancelled { }
        }
    }

    @Test("Reverse lookup preserves shared HTTP, MIME, byte, redirect and malformed-response failures")
    func photonReverseFailures() async throws {
        try await withServer { server in
            let query = try MapPlaceLookup(coordinate: MapCoordinate(latitude: 1, longitude: 103))
            for path in ["/photon-invalid", "/photon"] {
                let provider = try PhotonReverseGeocoder(endpoint: server.url(path), userAgent: "Tests")
                do {
                    _ = try await bounded("reverse invalid or over-limit response") { try await provider.reverse(query) }
                    Issue.record("Malformed or requested-limit overflow became reverse matches")
                } catch PhotonReverseGeocoder.LookupError.invalidData { }
            }
            let missingMIME = try PhotonReverseGeocoder(endpoint: server.url("/photon-no-mime.json"), userAgent: "Tests")
            do { _ = try await missingMIME.reverse(query); Issue.record("Reverse lookup accepted missing MIME") }
            catch PhotonReverseGeocoder.LookupError.unexpectedContentType { }
            for path in ["/geocoding-stream", "/geocoding-gzip"] {
                let provider = try PhotonReverseGeocoder(endpoint: server.url(path), userAgent: "Tests")
                do {
                    _ = try await bounded("reverse streamed or decompressed byte limit") { try await provider.reverse(query) }
                    Issue.record("Reverse lookup accepted oversized data")
                } catch PhotonReverseGeocoder.LookupError.responseTooLarge { }
            }
            for path in ["/cross-host", "/scheme", "/loop"] {
                let provider = try PhotonReverseGeocoder(endpoint: server.url(path), userAgent: "Tests")
                do {
                    _ = try await bounded("reverse forbidden redirect") { try await provider.reverse(query) }
                    Issue.record("Reverse lookup accepted forbidden redirect")
                } catch PhotonReverseGeocoder.LookupError.rejectedRedirect { }
            }
            let throttled = try PhotonReverseGeocoder(endpoint: server.url("/reverse-status"), userAgent: "Tests")
            do { _ = try await throttled.reverse(query); Issue.record("Reverse HTTP rejection became success") }
            catch PhotonReverseGeocoder.LookupError.httpStatus(let status, let retryAfter) {
                #expect(status == 429)
                #expect(retryAfter == "30")
            }
        }
    }

    @Test("Reverse lookup acknowledges in-flight cancellation and retains the public ten-second deadline")
    func photonReverseCancellationAndDeadline() async throws {
        try await withServer { server in
            let query = try MapPlaceLookup(coordinate: MapCoordinate(latitude: 1, longitude: 103))
            let slow = try PhotonReverseGeocoder(endpoint: server.url("/photon-slow"), userAgent: "Tests")
            let pending = Task { try await slow.reverse(query) }
            defer { pending.cancel() }
            try await bounded("reverse transfer started") {
                while true {
                    let response = try await MapHTTPClient.fetch(server.url("/started"), resource: .catalog)
                    if String(decoding: response.data, as: UTF8.self) == "true" { return }
                    try await Task.sleep(for: .milliseconds(10))
                }
            }
            pending.cancel()
            do { _ = try await bounded("reverse cancellation acknowledgment") { try await pending.value }; Issue.record("Cancelled reverse lookup succeeded") }
            catch PhotonReverseGeocoder.LookupError.cancelled { }
            let deadline = try PhotonReverseGeocoder(endpoint: server.url("/photon-deadline"), userAgent: "Tests")
            do { _ = try await deadline.reverse(query); Issue.record("Reverse lookup exceeded its deadline") }
            catch PhotonReverseGeocoder.LookupError.deadlineExceeded { }
        }
    }

    @Test("Search transport requires JSON, retains bounded rejection metadata and acknowledges cancellation")
    func geocodingTransport() async throws {
        try await withServer { server in
            for mime in ["application/json", "application/geo+json", "application/json;charset=utf-8"] {
                var components = URLComponents(url: server.url("/policy"), resolvingAgainstBaseURL: false)!
                components.queryItems = [URLQueryItem(name: "mime", value: mime), URLQueryItem(name: "bytes", value: "0")]
                components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
                let url = components.url!
                let response = try await bounded("geocoding MIME") {
                    try await MapHTTPClient.fetchResponse(url,
                                                         resource: .geocoding, userAgent: "Chio Search Tests", timeout: 10)
                }
                #expect(response.headers["x-observed-user-agent"] == "Chio Search Tests")
                #expect(response.headers["x-observed-accept"] == "application/json, application/geo+json")
            }
            for path in ["/policy?bytes=0", "/photon-no-mime.json", "/policy?mime=text/json&bytes=0"] {
                do {
                    _ = try await MapHTTPClient.fetchResponse(server.url(path), resource: .geocoding,
                                                              userAgent: "Tests", timeout: 10)
                    Issue.record("Invalid geocoding MIME accepted")
                } catch MapHTTPClient.Failure.unexpectedContentType { }
            }
            for mime in ["", "   ", "\"application/json\"", "application/json, text/html"] {
                var components = URLComponents(url: server.url("/policy"), resolvingAgainstBaseURL: false)!
                components.queryItems = [URLQueryItem(name: "mime", value: mime), URLQueryItem(name: "bytes", value: "0")]
                do {
                    _ = try await MapHTTPClient.fetchResponse(components.url!, resource: .geocoding,
                                                              userAgent: "Tests", timeout: 10)
                    Issue.record("Malformed explicit Content-Type accepted")
                } catch MapHTTPClient.Failure.unexpectedContentType { }
            }
            let exact = try await MapHTTPClient.fetchResponse(server.url("/policy?mime=application/json&bytes=524288"),
                                                              resource: .geocoding, userAgent: "Tests", timeout: 10)
            #expect(exact.data.count == 524_288)
            for path in ["/policy?mime=application/json&bytes=524289", "/geocoding-stream", "/geocoding-gzip"] {
                let acknowledgments = Mutex(0)
                do {
                    _ = try await bounded("geocoding overflow") {
                        try await MapHTTPClient.fetchResponse(server.url(path), resource: .geocoding, userAgent: "Tests", timeout: 10,
                                                              onTerminalAcknowledgement: { acknowledgments.withLock { $0 += 1 } })
                    }
                    Issue.record("Oversized geocoding response accepted")
                } catch MapHTTPClient.Failure.responseTooLarge { }
                #expect(acknowledgments.withLock { $0 } == 1)
            }
            for (hint, expected) in [("30", "30"), ("Wed, 21 Oct 2015 07:28:00 GMT", "Wed, 21 Oct 2015 07:28:00 GMT"),
                                     ("Sunday, 06-Nov-94 08:49:37 GMT", "Sunday, 06-Nov-94 08:49:37 GMT"),
                                     ("Sun Nov  6 08:49:37 1994", "Sun Nov  6 08:49:37 1994"),
                                     ("banana", ""), ("-1", ""), ("", ""), (String(repeating: "1", count: 257), "")] {
                var components = URLComponents(url: server.url("/photon-status"), resolvingAgainstBaseURL: false)!
                components.queryItems = [URLQueryItem(name: "retry", value: hint)]
                do {
                    _ = try await MapHTTPClient.fetchResponse(components.url!, resource: .geocoding,
                                                              userAgent: "Tests", timeout: 10)
                    Issue.record("HTTP 429 became success")
                } catch MapHTTPClient.Failure.httpStatus(let status, let retryAfter) {
                    #expect(status == 429)
                    #expect(retryAfter == expected)
                }
            }
            let throttled = try PhotonGeocoder(endpoint: server.url("/photon-status"), userAgent: "Tests")
            do { _ = try await throttled.search(MapPlaceQuery(text: "test")); Issue.record("HTTP 429 search succeeded") }
            catch PhotonGeocoder.SearchError.httpStatus(let status, let retryAfter) {
                #expect(status == 429)
                #expect(retryAfter.isEmpty)
            }
            let slow = try PhotonGeocoder(endpoint: server.url("/photon-slow"), userAgent: "Tests")
            let pending = Task { try await slow.search(MapPlaceQuery(text: "test")) }
            defer { pending.cancel() }
            try await bounded("geocoding request entered") {
                while true {
                    let response = try await MapHTTPClient.fetch(server.url("/started"), resource: .catalog)
                    if String(decoding: response.data, as: UTF8.self) == "true" { return }
                    try await Task.sleep(for: .milliseconds(10))
                }
            }
            pending.cancel()
            do { _ = try await bounded("cancel geocoder") { try await pending.value }; Issue.record("Cancelled search succeeded") }
            catch PhotonGeocoder.SearchError.cancelled { }
        }
    }

    @Test("A geocoding deadline spans redirects and Photon retains timeout and redirect failures")
    func geocodingDeadlineAndRedirects() async throws {
        try await withServer { server in
            let acknowledgments = Mutex(0)
            do {
                _ = try await bounded("whole redirect-chain deadline") {
                    try await MapHTTPClient.fetchResponse(server.url("/delayed-redirect?hop=0"),
                        resource: .geocoding, userAgent: "Tests", timeout: 2,
                        onTerminalAcknowledgement: { acknowledgments.withLock { $0 += 1 } })
                }
                Issue.record("Redirects extended the transfer deadline")
            } catch let error as URLError { #expect(error.code == .timedOut) }
            #expect(acknowledgments.withLock { $0 } == 1)
            let observed = try await MapHTTPClient.fetch(server.url("/redirect-hops"), resource: .catalog)
            let hops = try JSONDecoder().decode([Int].self, from: observed.data)
            #expect(Array(hops.prefix(2)) == [0, 1])
            for path in ["/cross-host", "/scheme", "/loop"] {
                let geocoder = try PhotonGeocoder(endpoint: server.url(path), userAgent: "Tests")
                do {
                    _ = try await bounded("Photon rejects redirect") { try await geocoder.search(MapPlaceQuery(text: "test")) }
                    Issue.record("Photon accepted a forbidden redirect")
                } catch PhotonGeocoder.SearchError.rejectedRedirect { }
            }
            let redirected = try PhotonGeocoder(endpoint: server.url("/photon-redirect"), userAgent: "Tests")
            let matches = try await bounded("Photon same-origin redirect") { try await redirected.search(MapPlaceQuery(text: "test")) }
            #expect(matches.places.map(\.name) == ["test", "Second"])
            let slow = try PhotonGeocoder(endpoint: server.url("/photon-deadline"), userAgent: "Tests")
            // Exercise the public ten-second policy directly. The server would
            // finish successfully at twelve seconds if the deadline were lost.
            do { _ = try await slow.search(MapPlaceQuery(text: "test")); Issue.record("Photon deadline did not expire") }
            catch PhotonGeocoder.SearchError.deadlineExceeded { }
        }
    }

    @Test("Real localhost transport bounds decompressed bodies and rejects HTTP/MIME/redirect failures")
    func boundedHTTP() async throws {
        try await withServer { server in
            let valid = try await bounded("empty HTTP 200") { try await MapHTTPClient.fetch(server.url("/empty"), resource: .tile) }
            #expect(valid.data.isEmpty)
            #expect(valid.headers["cache-control"] == "max-age=60")
            let tile = try await bounded("nonempty HTTP 200") { try await MapHTTPClient.fetch(server.url("/tile"), resource: .tile) }
            #expect(tile.data == Data([0x08, 0x00]))
            let redirected = try await bounded("permitted same-origin redirect") { try await MapHTTPClient.fetch(server.url("/redirect"), resource: .tile) }
            #expect(redirected.data.isEmpty)
            for (path, expected) in [
                ("/status", MapTileLoader.LoadingError.httpStatus(503)),
                ("/mime", .unexpectedContentType), ("/cross-host", .rejectedRedirect),
                ("/scheme", .rejectedRedirect), ("/loop", .rejectedRedirect),
                ("/oversize-header", .responseTooLarge), ("/oversize-stream", .responseTooLarge),
            ] {
                let terminalCount = Mutex(0)
                await #expect(throws: expected) {
                    try await bounded("reject \(path)") {
                        try await MapHTTPClient.fetch(server.url(path), resource: .tile,
                            onTerminalAcknowledgement: { terminalCount.withLock { $0 += 1 } })
                    }
                }
                #expect(terminalCount.withLock { $0 } == 1)
            }
            // The compressed Content-Length is below the catalog limit, while the
            // decompressed delegate bytes exceed it. This is real URLSession gzip.
            await #expect(throws: MapTileLoader.LoadingError.responseTooLarge) {
                try await bounded("decompressed catalog overflow") { try await MapHTTPClient.fetch(server.url("/gzip"), resource: .catalog) }
            }
            let terminalCount = Mutex(0)
            let pending = Task { [url = server.url("/slow")] in
                try await MapHTTPClient.fetch(url, resource: .tile,
                    onTerminalAcknowledgement: { terminalCount.withLock { $0 += 1 } })
            }
            defer { pending.cancel() }
            try await bounded("slow fixture request entered") {
                while true {
                    let status = try await MapHTTPClient.fetch(server.url("/started"), resource: .catalog)
                    if String(data: status.data, encoding: .utf8) == "true" { return }
                    try await Task.sleep(for: .milliseconds(10))
                }
            }
            pending.cancel()
            await #expect(throws: CancellationError.self) { try await bounded("in-flight cancellation acknowledgment") { try await pending.value } }
            #expect(terminalCount.withLock { $0 } == 1)
            do {
                _ = try await bounded("native resource timeout") { try await MapHTTPClient.fetch(server.url("/slow"), resource: .tile, timeout: 0.2) }
                Issue.record("Slow HTTP resource did not time out")
            } catch let error as URLError { #expect(error.code == .timedOut) }
            let cancelled = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                return try await MapHTTPClient.fetch(server.url("/empty"), resource: .tile)
            }
            await #expect(throws: CancellationError.self) { try await bounded("cancel before registration") { try await cancelled.value } }
        }
    }

    @Test("Cancellation queued before a redirect decision still acknowledges exactly once")
    func cancelledPendingRedirect() async throws {
        try await withServer { server in
            let control = RedirectGate()
            let acknowledgments = Mutex(0)
            let pending = Task { [url = server.url("/redirect")] in
                try await MapHTTPClient.fetch(url, resource: .tile,
                    onTerminalAcknowledgement: { acknowledgments.withLock { $0 += 1 } },
                    beforeRedirectDecision: { control.intercept($0) })
            }
            defer { pending.cancel(); control.release() }
            try await bounded("redirect callback entered") {
                while !control.hasEntered { try await Task.sleep(for: .milliseconds(1)) }
            }
            pending.cancel()
            // Observe the real Foundation task state, not a timed guess that caller
            // cancellation has reached the transport. The decision remains withheld.
            try await bounded("real pending-redirect transport cancellation") {
                while !control.isTransportCancelled { try await Task.sleep(for: .milliseconds(1)) }
            }
            control.release()
            await #expect(throws: CancellationError.self) {
                try await bounded("pending-redirect terminal acknowledgment") { try await pending.value }
            }
            #expect(acknowledgments.withLock { $0 } == 1)
        }
    }

    @Test("HTTP fixture cleanup awaits child exit even when its owner is cancelled")
    func cancelledFixtureCleanup() async throws {
        let server = try await Server()
        let cleanup = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await server.stop()
        }
        await cleanup.value
        #expect(!server.isRunning)
    }

    @Test("A throwing HTTP fixture operation awaits child cleanup")
    func throwingFixtureCleanup() async {
        let fixture = Mutex<Server?>(nil)
        await #expect(throws: WaitError.fixtureStartup("expected fixture operation failure")) {
            try await withServer { server in
                fixture.withLock { $0 = server }
                throw WaitError.fixtureStartup("expected fixture operation failure")
            }
        }
        #expect(fixture.withLock { $0?.isRunning } == false)
    }

    @Test("Same-origin redirects normalize implicit HTTP and HTTPS ports")
    func originComparison() {
        #expect(MapHTTPClient.sameOrigin(URL(string: "https://example.test/a")!, URL(string: "https://example.test:443/b")!))
        #expect(MapHTTPClient.sameOrigin(URL(string: "http://example.test/a")!, URL(string: "http://example.test:80/b")!))
        #expect(!MapHTTPClient.sameOrigin(URL(string: "http://example.test/a")!, URL(string: "https://example.test/b")!))
        #expect(!MapHTTPClient.sameOrigin(URL(string: "https://example.test/a")!, URL(string: "https://example.test:444/b")!))
    }

    @Test("Discovery chooses the first checked HTTPS OpenFreeMap template and retains observed provenance")
    func discovery() async throws {
        let catalog = Data(#"{"tiles":["https://other.test/{z}/{x}/{y}.pbf","https://tiles.openfreemap.org/bad\n/{z}/{x}/{y}.pbf","https://tiles.openfreemap.org/planet/observed/{z}/{x}/{y}.pbf"],"minzoom":0,"maxzoom":14}"#.utf8)
        let source = try await OpenMapTilesSource.fetchOpenFreeMap { url, resource in
            #expect(url.absoluteString == "https://tiles.openfreemap.org/planet")
            #expect(resource == .catalog)
            return MapHTTPClient.Response(data: catalog, headers: [:])
        }
        #expect(source.zoomRange == 0...14)
        #expect(source.metadata.sourceRevision == source.template)
        #expect(source.metadata.attribution.contains("OpenStreetMap"))
        #expect(source.metadata.license == "ODbL")
        for bad in [#"{"tiles":["http://tiles.openfreemap.org/{z}/{x}/{y}.pbf"],"minzoom":0,"maxzoom":14}"#,
                    #"{"tiles":["https://tiles.openfreemap.org/{z}/{x}/{y}.pbf"],"minzoom":15,"maxzoom":14}"#,
                    #"{"tiles":[],"minzoom":0,"maxzoom":14}"#, "garbage"] {
            await #expect(throws: MapTileLoader.LoadingError.invalidCatalog) {
                try await OpenMapTilesSource.fetchOpenFreeMap { _, _ in MapHTTPClient.Response(data: Data(bad.utf8), headers: [:]) }
            }
        }
    }

    private func withServer(_ operation: (Server) async throws -> Void) async throws {
        let server = try await Server()
        do {
            try await operation(server)
        } catch {
            // The operation's defers cancel pending HTTP tasks and release any
            // held redirect decision before this owner closes the child.
            await server.stop()
            throw error
        }
        await server.stop()
    }

    private func bounded<T: Sendable>(_ phase: String, timeout: Duration = .seconds(5),
                                     _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(operation: operation)
            group.addTask { try await Task.sleep(for: timeout); throw WaitError.timeout(phase) }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    private enum WaitError: Error, Equatable { case timeout(String), fixtureStartup(String) }

    private final class RedirectGate: Sendable {
        private let task = Mutex<URLSessionTask?>(nil)
        private let releaseSignal = DispatchSemaphore(value: 0)
        var hasEntered: Bool { task.withLock { $0 != nil } }
        var isTransportCancelled: Bool {
            task.withLock { $0?.state == .canceling || $0?.state == .completed }
        }
        func intercept(_ task: URLSessionTask) {
            self.task.withLock { $0 = task }
            if releaseSignal.wait(timeout: .now() + 5) != .success {
                Issue.record("Pending redirect fixture was not released within five seconds")
            }
        }
        func release() { releaseSignal.signal() }
    }

    /// Sole test owner of a localhost subprocess. Startup and teardown are bounded;
    /// handlers use daemon threads so disconnected clients cannot retain the child.
    private final class Server: @unchecked Sendable {
        private let process: Process
        private let base: URL
        private let errorHandle: FileHandle
        private let stopped = Mutex(false)
        init() async throws {
            try Task.checkCancellation()
            let process = Process(), pipe = Pipe(), errorPipe = Pipe()
            let errors = Mutex(Data())
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", "-u", "-c", Self.script]
            process.standardOutput = pipe
            process.standardError = errorPipe
            let command = "executable=/usr/bin/env; arguments=\(process.arguments!.debugDescription)"
            let handle = pipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading
            for input in [handle, errorHandle] {
                let flags = fcntl(input.fileDescriptor, F_GETFL)
                guard flags >= 0 else { throw WaitError.fixtureStartup("Could not read fixture pipe flags; \(command)") }
                let hasNonblockingPipe = fcntl(input.fileDescriptor, F_SETFL, flags | O_NONBLOCK) == 0
                guard hasNonblockingPipe else { throw WaitError.fixtureStartup("Could not make fixture pipe nonblocking; \(command)") }
            }
            do { try process.run() }
            catch { throw WaitError.fixtureStartup("Could not launch fixed Python HTTP fixture: \(error); \(command)") }
            errorHandle.readabilityHandler = { handle in
                guard let chunk = Self.readAvailable(from: handle, limit: 1_024) else { return }
                guard !chunk.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                errors.withLock { bytes in bytes.append(chunk.prefix(max(0, 8_192 - bytes.count))) }
            }
            let output = Mutex((bytes: Data(), isComplete: false))
            handle.readabilityHandler = { handle in
                guard let chunk = Self.readAvailable(from: handle, limit: 256) else { return }
                let isComplete = output.withLock { state in
                    state.bytes.append(chunk.prefix(max(0, 256 - state.bytes.count)))
                    let hasNewline = state.bytes.contains(10)
                    let hasReachedLimit = state.bytes.count == 256
                    state.isComplete = chunk.isEmpty || hasNewline || hasReachedLimit
                    return state.isComplete
                }
                if isComplete { handle.readabilityHandler = nil }
            }
            defer { handle.readabilityHandler = nil; try? handle.close() }
            do {
                // Yield the cooperative executor while Foundation dispatches pipe
                // readiness. No reader thread blocks waiting for the child output.
                let clock = ContinuousClock()
                let deadline = clock.now.advanced(by: .seconds(5))
                while !output.withLock({ $0.isComplete }) {
                    try Task.checkCancellation()
                    guard clock.now < deadline else { throw WaitError.timeout("Python HTTP fixture readiness after five seconds") }
                    try await Task.sleep(for: .milliseconds(10))
                }
                try Task.checkCancellation()
                let data = output.withLock { $0.bytes }
                let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: text) else { throw WaitError.fixtureStartup("Invalid readiness URL") }
                let isLocalhost = url.host == "127.0.0.1"
                guard isLocalhost else { throw WaitError.fixtureStartup("Readiness URL is not the localhost fixture") }
                self.process = process
                self.base = url
                self.errorHandle = errorHandle
            } catch {
                let status: String
                if process.isRunning { status = "still running" }
                else { status = "exited \(process.terminationStatus)" }
                let cleanupFailure = await Self.terminate(process)
                errorHandle.readabilityHandler = nil
                try? errorHandle.close()
                if let cleanupFailure { Issue.record("\(cleanupFailure)") }
                if error is CancellationError { throw error }
                let stdout = output.withLock { String(decoding: $0.bytes, as: UTF8.self) }
                let stderr = errors.withLock { String(decoding: $0, as: UTF8.self) }
                throw WaitError.fixtureStartup("Python HTTP fixture startup failed: \(error); child \(status); \(command); stdout=\(stdout.debugDescription); stderr=\(stderr.debugDescription)")
            }
        }
        func url(_ path: String) -> URL { URL(string: path, relativeTo: base)!.absoluteURL }
        var isRunning: Bool { process.isRunning }
        func stop() async {
            let shouldStop = stopped.withLock { value in if value { return false }; value = true; return true }
            if shouldStop {
                let cleanupFailure = await Self.terminate(process)
                errorHandle.readabilityHandler = nil
                try? errorHandle.close()
                if let cleanupFailure { Issue.record("\(cleanupFailure)") }
            }
        }
        deinit {
            guard !stopped.withLock({ $0 }) else { return }
            Issue.record("HTTP fixture owner omitted awaited cleanup")
            let process = process, errorHandle = errorHandle
            // The normal owner awaits stop(). This fallback retains only the
            // resources until bounded cleanup finishes, never the dying owner.
            Task.detached {
                _ = await Server.terminate(process)
                errorHandle.readabilityHandler = nil
                try? errorHandle.close()
            }
        }
        private static func readAvailable(from handle: FileHandle, limit: Int) -> Data? {
            // One nonblocking POSIX read cannot wait to fill a Foundation read's
            // requested length. A transient read error waits for the next event.
            var bytes = [UInt8](repeating: 0, count: limit)
            let count = bytes.withUnsafeMutableBytes { buffer in
                read(handle.fileDescriptor, buffer.baseAddress, buffer.count)
            }
            guard count >= 0 else { return nil }
            return Data(bytes.prefix(count))
        }
        private static func terminate(_ process: Process) async -> String? {
            // Cleanup must finish even if the HTTP test or startup is cancelled.
            // Foundation owns child reaping; observe its state without a second
            // waitUntilExit worker whose scheduling adds another completion gate.
            guard process.isRunning else { return nil }
            let clock = ContinuousClock()
            let start = clock.now
            let termDeadline = start.advanced(by: .seconds(3))
            let killDeadline = start.advanced(by: .seconds(5))
            let pid = process.processIdentifier
            let termResult = kill(pid, SIGTERM)
            let termError = termResult == 0 ? 0 : errno
            return await Task.detached {
                while process.isRunning && clock.now < termDeadline {
                    try? await clock.sleep(until: min(termDeadline, clock.now.advanced(by: .milliseconds(10))))
                }
                guard process.isRunning else { return nil as String? }
                let killResult = kill(pid, SIGKILL)
                let killError = killResult == 0 ? 0 : errno
                while process.isRunning && clock.now < killDeadline {
                    try? await clock.sleep(until: min(killDeadline, clock.now.advanced(by: .milliseconds(10))))
                }
                guard process.isRunning else { return nil }
                let probeResult = kill(pid, 0)
                let probeError = probeResult == 0 ? 0 : errno
                return "Local HTTP fixture failed to exit within five seconds; pid=\(pid); "
                    + "SIGTERM result=\(termResult) errno=\(termError); "
                    + "SIGKILL result=\(killResult) errno=\(killError); "
                    + "Foundation isRunning=\(process.isRunning); existence probe result=\(probeResult) errno=\(probeError)"
            }.value
        }
        private static let script = #"""
import sys
print('fixture: entered; python=%s' % sys.executable, file=sys.stderr, flush=True)
import gzip, http.server, json, socketserver, threading, time, urllib.parse
print('fixture: imports complete', file=sys.stderr, flush=True)
started = threading.Event()
redirect_hops = []
osrm_requests = []
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        path = self.path
        route = urllib.parse.urlsplit(path).path
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)
        if route == '/osrm-observed':
            body = json.dumps(osrm_requests).encode()
            self.send_response(200); self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        if route.startswith('/osrm-'):
            decoded_path = urllib.parse.unquote(route)
            parts = decoded_path.split('/', 2)
            mode = parts[1][len('osrm-'):]
            expected_query = {'geometries':['geojson'], 'overview':['full'], 'alternatives':['false'],
                              'steps':['false'], 'annotations':['false'], 'generate_hints':['false'], 'skip_waypoints':['true']}
            osrm_requests.append({'path':decoded_path,
                                  'query':urllib.parse.urlencode(sorted((key, value[0]) for key, value in query.items())),
                                  'userAgent':self.headers.get('User-Agent',''), 'accept':self.headers.get('Accept','')})
            has_expected_path = len(parts) == 3 and parts[2] == 'route/v1/driving/103.75,1.25;103.85,1.35'
            has_expected_headers = self.headers.get('User-Agent') == 'Chio Routing Tests' and self.headers.get('Accept') == 'application/json'
            if not (has_expected_path and query == expected_query and has_expected_headers): mode = 'invalid-query'
            geometry = {'type':'LineString', 'coordinates':[[103.751,1.251],[103.8,1.29],[103.849,1.349]]}
            document = {'code':'Ok', 'routes':[{'geometry':geometry, 'distance':1234.5, 'duration':321.25}]}
            status = 200
            if mode == 'no-route': status = 400; document = {'code':'NoRoute'}
            elif mode == 'no-segment': status = 400; document = {'code':'NoSegment'}
            elif mode == 'invalid-query': status = 400; document = {'code':'InvalidQuery'}
            elif mode == 'malformed': status = 400
            elif mode == 'bad-geometry': document['routes'][0]['geometry'] = {'type':'Point', 'coordinates':[103.751,1.251]}
            elif mode == 'wrong-status': document = {'code':'NoRoute'}
            elif mode == 'ok-error': status = 400
            elif mode == 'throttled': status = 429; document = {'code':'TooManyRequests'}
            body = b'not json' if mode == 'malformed' else json.dumps(document).encode()
            self.send_response(status); self.send_header('Content-Type','application/json')
            if mode == 'throttled': self.send_header('Retry-After','30')
            self.send_header('Content-Length',str(len(body))); self.end_headers()
            if mode == 'slow': started.set(); time.sleep(4)
            if mode == 'deadline': time.sleep(12)
            try: self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError): pass
            return
        if route == '/routing-response':
            status = int(query.get('status', ['200'])[0])
            body = b'{"code":"Ok"}' if status == 200 else b'{"code":"NoRoute"}'
            self.send_response(status); self.send_header('Content-Type','application/json')
            self.send_header('Retry-After','30')
            self.send_header('X-Observed-Accept', self.headers.get('Accept', ''))
            self.send_header('X-Observed-User-Agent', self.headers.get('User-Agent', ''))
            self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        if route == '/routing-deadline':
            body = b'{"code":"NoRoute"}'
            self.send_response(400); self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(body))); self.end_headers(); time.sleep(2)
            try: self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError): pass
            return
        if route == '/routing-gzip':
            body = gzip.compress(b' ' * (2*1024*1024+1))
            self.send_response(int(query.get('status', ['200'])[0]))
            self.send_header('Content-Type','application/json'); self.send_header('Content-Encoding','gzip')
            self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        if route == '/routing-stream':
            self.send_response(int(query.get('status', ['200'])[0]))
            self.send_header('Content-Type','application/json'); self.send_header('Transfer-Encoding','chunked'); self.end_headers()
            try:
                for i in range(33): self.wfile.write(b'10000\r\n' + b'x'*65536 + b'\r\n'); self.wfile.flush()
                self.wfile.write(b'0\r\n\r\n')
            except (BrokenPipeError, ConnectionResetError): pass
            return
        if route == '/redirect-hops':
            body = json.dumps(redirect_hops).encode()
            self.send_response(200); self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        if route == '/delayed-redirect':
            hop = int(query.get('hop', ['0'])[0]); redirect_hops.append(hop); time.sleep(0.75)
            if hop < 2:
                self.send_response(302); self.send_header('Location', '/delayed-redirect?hop=%s' % (hop+1))
                self.send_header('Content-Length','0'); self.end_headers(); return
            self.send_response(200); self.send_header('Content-Type','application/json')
            self.send_header('Content-Length','0'); self.end_headers(); return
        if route == '/photon-redirect':
            self.send_response(302); self.send_header('Location', '/photon?' + urllib.parse.urlsplit(path).query)
            self.send_header('Content-Length','0'); self.end_headers(); return
        if route == '/reverse-redirect':
            self.send_response(302); self.send_header('Location', '/custom/reverse?' + urllib.parse.urlsplit(path).query)
            self.send_header('Content-Length','0'); self.end_headers(); return
        if route == '/reverse-status':
            self.send_response(429); self.send_header('Retry-After','30')
            self.send_header('Content-Length','0'); self.end_headers(); return
        if route == '/custom/reverse':
            lat = query.get('lat', ['missing'])[0]; lon = query.get('lon', ['missing'])[0]
            limit = query.get('limit', ['missing'])[0]
            observed = 'lat=%s;lon=%s;limit=%s;keys=%s;ua=%s' % (lat, lon, limit, ','.join(sorted(query)), self.headers.get('User-Agent',''))
            first = {'type':'Feature','geometry':{'type':'Point','coordinates':[103.8,1.3]},
                     'properties':{'name':'Reverse','city':observed}}
            pole = {'type':'Feature','geometry':{'type':'Point','coordinates':[180,-90]},'properties':{'name':'Pole'}}
            features = [] if lat == '0.0' and lon == '0.0' else [first, pole, first][:int(limit)]
            body = json.dumps({'type':'FeatureCollection','features':features}).encode()
            self.send_response(200); self.send_header('Content-Type','application/geo+json')
            self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        if route == '/photon-status':
            self.send_response(429)
            if 'retry' in query: self.send_header('Retry-After', query['retry'][0])
            self.send_header('Content-Length','0'); self.end_headers(); return
        if route in ('/photon', '/photon-invalid', '/photon-slow', '/photon-deadline'):
            text = query.get('q', [''])[0]
            names = [] if text == 'empty' else [text, 'Second']
            features = [{'type':'Feature','geometry':{'type':'Point','coordinates':[103.8,1.3]},
                         'properties':{'name':name,'city':self.headers.get('User-Agent','')}} for name in names]
            body = json.dumps({'type':'FeatureCollection','features':features}).encode()
            if route == '/photon-invalid': body = b'not json'
            self.send_response(200); self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(body))); self.end_headers()
            if route == '/photon-slow': started.set(); time.sleep(4)
            if route == '/photon-deadline': time.sleep(12)
            try: self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError): pass
            return
        if route == '/photon-no-mime.json':
            body = b'{"features":[]}'
            self.send_response(200); self.send_header('Content-Length', str(len(body))); self.end_headers()
            self.wfile.write(body); return
        if route == '/geocoding-gzip':
            body = gzip.compress(b' ' * (512*1024+1))
            self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Content-Encoding','gzip')
            self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        if route == '/geocoding-stream':
            self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Transfer-Encoding','chunked'); self.end_headers()
            try:
                for i in range(9): self.wfile.write(b'10000\r\n' + b'x'*65536 + b'\r\n'); self.wfile.flush()
                self.wfile.write(b'0\r\n\r\n')
            except (BrokenPipeError, ConnectionResetError): pass
            return
        if route in ('/policy', '/policy.json'):
            query = urllib.parse.parse_qs(urllib.parse.urlsplit(path).query, keep_blank_values=True)
            size = int(query['bytes'][0])
            self.send_response(int(query.get('status', ['200'])[0]))
            if 'mime' in query: self.send_header('Content-Type', query['mime'][0])
            self.send_header('X-Observed-Accept', self.headers.get('Accept', ''))
            self.send_header('X-Observed-User-Agent', self.headers.get('User-Agent', ''))
            self.send_header('Content-Length', str(size)); self.end_headers()
            try: self.wfile.write(b'x' * size)
            except (BrokenPipeError, ConnectionResetError): pass
            return
        if route in ('/redirect', '/cross-host', '/scheme', '/loop'):
            location = {'/redirect':'/empty', '/loop':'/loop', '/cross-host':'http://localhost:%s/empty' % self.server.server_port, '/scheme':'https://127.0.0.1:%s/empty' % self.server.server_port}[route]
            self.send_response(302); self.send_header('Location', location); self.send_header('Content-Length','0'); self.end_headers(); return
        if path == '/oversize-header':
            self.send_response(200); self.send_header('Content-Type','application/octet-stream'); self.send_header('Content-Length',str(16*1024*1024+1)); self.end_headers(); return
        if path == '/oversize-stream':
            self.send_response(200); self.send_header('Content-Type','application/octet-stream'); self.end_headers()
            try:
                for i in range(257): self.wfile.write(b'\0'*65536); self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError): pass
            return
        if path == '/gzip':
            body = gzip.compress(b' '* (256*1024+1))
            self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Content-Encoding','gzip'); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        body = b'\x08\x00' if path == '/tile' else b''
        if path == '/started': body = b'true' if started.is_set() else b'false'
        self.send_response(503 if path == '/status' else 200)
        self.send_header('Content-Type','text/html' if path == '/mime' else ('application/json' if path == '/started' else 'application/octet-stream'))
        self.send_header('Cache-Control','max-age=60')
        self.send_header('Content-Length',str(1 if path == '/slow' else len(body))); self.end_headers()
        if path == '/slow': started.set(); time.sleep(4); body = b'x'
        try: self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError): pass
class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    def server_bind(self):
        # HTTPServer otherwise reverse-resolves even numeric loopback. This
        # fixture needs the bound address and port, with no DNS dependency.
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]
print('fixture: binding numeric loopback', file=sys.stderr, flush=True)
server = Server(('127.0.0.1',0), Handler)
print('fixture: ready', file=sys.stderr, flush=True)
print('http://127.0.0.1:%s/' % server.server_port, flush=True)
server.serve_forever()
"""#
    }
}
