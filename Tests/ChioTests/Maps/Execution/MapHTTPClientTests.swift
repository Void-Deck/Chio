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

    private func bounded<T: Sendable>(_ phase: String, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(operation: operation)
            group.addTask { try await Task.sleep(for: .seconds(5)); throw WaitError.timeout(phase) }
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
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        path = self.path
        route = urllib.parse.urlsplit(path).path
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(path).query)
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
        if path.startswith('/policy?'):
            query = urllib.parse.parse_qs(urllib.parse.urlsplit(path).query, keep_blank_values=True)
            size = int(query['bytes'][0])
            self.send_response(200)
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
