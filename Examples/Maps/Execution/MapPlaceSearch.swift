import Chio
import Foundation

/// Owns the example's bounded submitted work, including cancellation acknowledgement.
@MainActor
final class MapPlaceSearch {
    private let provider: any MapGeocodingProvider
    private var isActive = false
    private var generation = UUID()
    private var active: Task<Void, Never>?
    private var pending: Work?
    private var lastStarted: ContinuousClock.Instant?
    private var accepted: (query: MapPlaceQuery, matches: MapPlaceMatches)?

    init(provider: any MapGeocodingProvider) { self.provider = provider }

    enum Phase {
        case idle
        case loading(MapPlaceQuery)
        case matches(MapPlaceQuery, MapPlaceMatches, response: UUID)
        case failed(text: String, message: String)
    }

    private struct Work {
        let query: MapPlaceQuery
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
        generation = UUID()
        pending = nil
        active?.cancel()
        let query: MapPlaceQuery
        do { query = try MapPlaceQuery(text: text) }
        catch {
            publish(.failed(text: text, message: "Enter a place name of at most 512 bytes, without control characters."))
            return
        }
        if let accepted, accepted.query == query {
            publish(.matches(query, accepted.matches, response: generation))
            return
        }
        let work = Work(query: query, generation: generation, publish: publish)
        publish(.loading(query))
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
                let matches = try await provider.search(work.query)
                if isActive, generation == work.generation, !Task.isCancelled {
                    accepted = (work.query, matches)
                    work.publish(.matches(work.query, matches, response: work.generation))
                }
            } catch {
                if isActive, generation == work.generation, !Task.isCancelled {
                    work.publish(.failed(text: work.query.text, message: message(for: error)))
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
