import Chio
import Foundation

/// Owns one active request and at most the latest pending replacement.
@MainActor
final class MapExampleRouting {
    private let provider: any MapRoutingProvider
    private var isActive = true
    private var generation = UUID()
    private var active: Task<Void, Never>?
    private var pending: Work?

    init(provider: any MapRoutingProvider) { self.provider = provider }

    enum Phase {
        case idle
        case start(MapCoordinate)
        case loading(MapRouteRequest)
        case ready(MapRouteRequest, MapRouteResponse.Route, attributions: [MapAttribution], MapOverlays)
        case noRoute(MapRouteRequest, attributions: [MapAttribution])
        case failed(MapRouteRequest, message: String)

        var origin: MapCoordinate? {
            switch self {
            case .idle: nil
            case .start(let coordinate): coordinate
            case .loading(let request), .ready(let request, _, _, _), .noRoute(let request, _), .failed(let request, _): request.origin
            }
        }
    }

    private struct Work {
        let request: MapRouteRequest
        let generation: UUID
        let publish: @MainActor (Phase) -> Void
    }

    func observeLifetime() async {
        let cancellation = AsyncStream<Void> { _ in }
        for await _ in cancellation {}
        close()
    }

    func close() {
        isActive = false
        cancel()
    }

    func cancel() {
        generation = UUID()
        pending = nil
        active?.cancel()
    }

    func submit(_ request: MapRouteRequest, publish: @escaping @MainActor (Phase) -> Void) {
        guard isActive else { return }
        cancel()
        let work = Work(request: request, generation: generation, publish: publish)
        publish(.loading(request))
        if active != nil { pending = work }
        else { start(work) }
    }

    private func start(_ work: Work) {
        active = Task { [self] in
            do {
                let response = try await provider.route(work.request)
                try Task.checkCancellation()
                guard isActive, generation == work.generation else { return finish() }
                if let route = response.route {
                    let coordinates = route.path.coordinates
                    // Checked polylines always have at least two coordinates.
                    let overlays = try MapOverlays(markers: [
                        MapMarker(id: "routed-start", coordinate: coordinates[0], title: "Routed start"),
                        MapMarker(id: "routed-finish", coordinate: coordinates[coordinates.count - 1], title: "Routed finish")
                    ], routes: [MapRoute(id: "computed-route", path: route.path)])
                    work.publish(.ready(work.request, route, attributions: response.attributions, overlays))
                } else {
                    work.publish(.noRoute(work.request, attributions: response.attributions))
                }
            } catch {
                if isActive, generation == work.generation, !Task.isCancelled {
                    work.publish(.failed(work.request, message: message(for: error)))
                }
            }
            finish()
        }
    }

    private func finish() {
        // A cancelled operation retains its slot until it returns here.
        active = nil
        guard isActive, let latest = pending else { return }
        pending = nil
        guard latest.generation == generation else { return }
        start(latest)
    }

    private func message(for error: any Error) -> String {
        guard let error = error as? OSRMRouter.RouteError else { return "Routing failed. Press 2 or g to retry." }
        switch error {
        case .cancelled: return "Routing cancelled."
        case .deadlineExceeded: return "Routing timed out."
        case .invalidResponse, .invalidData: return "Router returned invalid route data."
        case .responseTooLarge: return "Route response exceeded its limit."
        case .unexpectedContentType: return "Router returned an unsupported content type."
        case .rejectedRedirect: return "Routing redirect was rejected."
        case .httpStatus(let status, let retryAfter):
            let hint = retryAfter.isEmpty ? "" : " · Retry-After: \(retryAfter)"
            return "Routing rejected (HTTP \(status))\(hint)"
        case .cannotSnap: return "Router could not match a requested location to its network."
        case .rejectedRequest: return "Router rejected this request."
        case .unsupportedGeometry: return "Router returned an unsupported zero-length path."
        case .transport: return "Could not reach the routing endpoint."
        }
    }
}
