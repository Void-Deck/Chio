import SwiftTUIRuntime

/// Observes the same public frame callback used by hosted applications.
@MainActor
final class HostedFrameRecorder {
    private(set) var latest: SemanticHostFrame?
    private var pending: PendingWait?
    private var deadline: Task<Void, Never>?
    private let started = ContinuousClock.now
    private var observations: [(elapsed: Duration, event: Observation)] = []

    func record(_ event: Observation) {
        observations.append((started.duration(to: .now), event))
        if observations.count > 64 { observations.removeFirst() }
    }

    func receive(_ frame: SemanticHostFrame) {
        record(.frame(frame))
        latest = frame
        guard let pending, pending.matches(frame) else { return }
        record(.matched(pending.description, sequence: frame.sequence))
        self.pending = nil
        deadline?.cancel()
        deadline = nil
        pending.continuation.resume(returning: frame)
    }

    func wait(
        after sequence: UInt64? = nil,
        description: String,
        matching predicate: @escaping @MainActor (SemanticHostFrame) -> Bool
    ) async throws -> SemanticHostFrame {
        record(.waiting(description, after: sequence))
        let matches: @MainActor (SemanticHostFrame) -> Bool = { frame in
            (sequence == nil || frame.sequence > sequence!) && predicate(frame)
        }
        if let latest, matches(latest) {
            record(.matched(description, sequence: latest.sequence))
            return latest
        }
        precondition(pending == nil, "A recorder supports one frame wait at a time")
        return try await withCheckedThrowingContinuation { continuation in
            pending = PendingWait(description: description, matches: matches, continuation: continuation)
            deadline = Task { @MainActor [weak self] in
                self?.record(.deadlineStarted(description))
                do { try await Task.sleep(for: .seconds(5)) }
                catch { return }
                guard let self, let pending = self.pending else { return }
                record(.timedOut(description))
                self.pending = nil
                self.deadline = nil
                let focusedIdentity = self.latest?.focusedIdentity
                let role = self.latest?.semantics.accessibilityNodes.first {
                    $0.identity == focusedIdentity
                }?.role
                let interactions = self.latest?.semantics.focusRegions.first {
                    $0.identity == focusedIdentity
                }?.focusInteractions
                pending.continuation.resume(throwing: FrameTimeout(
                    expectation: description,
                    focus: "identity=\(String(describing: focusedIdentity)); role=\(String(describing: role)); interactions=\(String(describing: interactions))",
                    lastFrame: self.latest?.raster.lines.joined(separator: "\n") ?? "No frame received",
                    history: observations.map { "\($0.elapsed): \($0.event.description)" }.joined(separator: "\n")
                ))
            }
        }
    }

    private struct PendingWait {
        let description: String
        let matches: @MainActor (SemanticHostFrame) -> Bool
        let continuation: CheckedContinuation<SemanticHostFrame, any Error>
    }

    enum Observation {
        case waiting(String, after: UInt64?)
        case deadlineStarted(String)
        case matched(String, sequence: UInt64)
        case timedOut(String)
        case frame(SemanticHostFrame)
        case focus(FocusPresentation)
        case runtimeIssue(RuntimeIssue)

        var description: String {
            switch self {
            case .waiting(let expectation, let sequence):
                return "wait: \(expectation), after=\(String(describing: sequence))"
            case .deadlineStarted(let expectation):
                return "five-second deadline started: \(expectation)"
            case .matched(let expectation, let sequence):
                return "matched frame \(sequence): \(expectation)"
            case .timedOut(let expectation):
                return "deadline fired: \(expectation)"
            case .frame(let frame):
                return "frame \(frame.sequence), focus=\(String(describing: frame.focusedIdentity?.path))\n\(frame.raster.lines.joined(separator: "\n"))"
            case .focus(let presentation):
                return "focus=\(String(describing: presentation.focusedIdentity?.path)), semantics=\(presentation.semantics)"
            case .runtimeIssue(let issue):
                return issue.description
            }
        }
    }

    private struct FrameTimeout: Error, CustomStringConvertible {
        let expectation: String
        let focus: String
        let lastFrame: String
        let history: String

        var description: String {
            "Timed out waiting for \(expectation). Last focus: \(focus). Recent observations (up to 64):\n\(history)\nLast raster:\n\(lastFrame)"
        }
    }
}
