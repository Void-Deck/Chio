import Chio
import Foundation

/// Owns the example's bounded submitted work, including cancellation acknowledgement.
@MainActor
final class MapPlaceSearch {
    private let provider: any MapGeocodingProvider
    private let reverseProvider: any MapReverseGeocodingProvider
    private var isActive = false
    private var generation = UUID()
    private var active: Task<Void, Never>?
    private var pending: Work?
    private var lastStarted: ContinuousClock.Instant?
    private var accepted: (request: Request, matches: MapPlaceMatches)?

    init(provider: any MapGeocodingProvider, reverseProvider: any MapReverseGeocodingProvider = MapFixtureGeocoder()) {
        self.provider = provider
        self.reverseProvider = reverseProvider
    }

    enum Request {
        case search(MapPlaceQuery)
        case reverse(MapPlaceLookup)

        var subject: String {
            switch self {
            case .search(let query): return query.text
            case .reverse(let query):
                return String(format: "Near %.4f, %.4f", query.coordinate.latitude, query.coordinate.longitude)
            }
        }
    }

    enum Phase {
        case idle
        case loading(Request)
        case matches(Request, MapPlaceMatches, response: UUID)
        case failed(text: String, message: String)
    }

    private struct Work {
        let request: Request
        let generation: UUID
        let publish: @MainActor (Phase) -> Void
    }

    /// Native task cancellation also covers hosted shutdown, which does not
    /// currently deliver onDisappear in the pinned SwiftTUI runtime.
    func observeLifetime() async {
        let cancellation = AsyncStream<Void> { _ in }
        for await _ in cancellation {}
        close()
    }

    func open() { isActive = true }

    func close() {
        // Invalidate publication before asking the resource owner to terminate.
        generation = UUID()
        isActive = false
        pending = nil
        accepted = nil
        active?.cancel()
    }

    func submit(text: String, publish: @escaping @MainActor (Phase) -> Void) {
        guard isActive else { return }
        do { submit(.search(try MapPlaceQuery(text: text)), publish: publish) }
        catch {
            invalidate()
            publish(.failed(text: text, message: "Enter a place name of at most 512 bytes, without control characters."))
        }
    }

    func lookup(coordinate: MapCoordinate, publish: @escaping @MainActor (Phase) -> Void) {
        guard isActive else { return }
        do { submit(.reverse(try MapPlaceLookup(coordinate: coordinate)), publish: publish) }
        catch {
            invalidate()
            publish(.failed(text: "Map centre", message: "Could not prepare the place lookup."))
        }
    }

    private func invalidate() {
        generation = UUID()
        pending = nil
        active?.cancel()
    }

    private func submit(_ request: Request, publish: @escaping @MainActor (Phase) -> Void) {
        invalidate()
        if let accepted, accepted.request == request {
            publish(.matches(request, accepted.matches, response: generation))
            return
        }
        let work = Work(request: request, generation: generation, publish: publish)
        publish(.loading(request))
        if active != nil { pending = work }
        else { start(work) }
    }

    private func start(_ work: Work) {
        active = Task { [self] in
            do {
                if let lastStarted {
                    let nextStart = lastStarted.advanced(by: .seconds(1))
                    if ContinuousClock.now < nextStart { try await ContinuousClock().sleep(until: nextStart) }
                }
                try Task.checkCancellation()
                lastStarted = ContinuousClock.now
                let matches: MapPlaceMatches
                switch work.request {
                case .search(let query): matches = try await provider.search(query)
                case .reverse(let query): matches = try await reverseProvider.reverse(query)
                }
                if isActive, generation == work.generation, !Task.isCancelled {
                    accepted = (work.request, matches)
                    work.publish(.matches(work.request, matches, response: work.generation))
                }
            } catch {
                if isActive, generation == work.generation, !Task.isCancelled {
                    work.publish(.failed(text: work.request.subject, message: message(for: error)))
                }
            }
            // Only this task clears ownership. Cancellation itself does not release the slot.
            active = nil
            guard isActive, let latest = pending else { return }
            pending = nil
            guard latest.generation == generation else { return }
            start(latest)
        }
    }

    private func message(for error: any Error) -> String {
        guard let error = error as? PhotonGeocoder.SearchError else {
            return "Search failed. Submit again to retry."
        }
        switch error {
        case .cancelled: return "Search cancelled."
        case .deadlineExceeded: return "Search timed out. Submit again to retry."
        case .httpStatus(let status, let retryAfter):
            let hint = retryAfter.isEmpty ? "" : " · Retry-After: \(retryAfter)"
            return "Search rejected (HTTP \(status))\(hint)"
        case .invalidResponse, .invalidData: return "Search returned invalid place data."
        case .responseTooLarge: return "Search response exceeded its size limit."
        case .unexpectedContentType: return "Search returned an unsupported content type."
        case .rejectedRedirect: return "Search redirect was rejected."
        case .transport: return "Could not reach the search endpoint."
        }
    }
}

extension MapPlaceSearch.Request: Hashable {}
extension MapPlaceSearch.Request: Sendable {}
