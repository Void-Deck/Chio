// Spec-derived from the force-unwrap removal contract (C1–C3); separate author.
@testable import ChioDashboard
import Testing

struct AgentSimulationForceUnwrapSpecTests {
    @Test("C3: fraction plus step at or above one completes",
          arguments: [0.5, 0.75])
    func completionBoundary(_ step: Double) throws {
        let progress = try #require(Agent.RunningProgress(fraction: 0.5))
        let original = Agent(id: "running", name: "Runner", summary: "Boundary", phase: .running(progress: progress))
        let advanced = try #require(AgentSimulation.advance([original], step: step).first)
        #expect(advanced == Agent(id: "running", name: "Runner", summary: "Boundary", phase: .completed))
        #expect(original.phase == .running(progress: progress))
    }

    @Test("C3: just below one remains running at the exact sum")
    func justBelowCompletion() throws {
        let progress = try #require(Agent.RunningProgress(fraction: 0.5))
        let original = Agent(id: "running", name: "Runner", summary: "Boundary", phase: .running(progress: progress))
        let step = 0.5 - 0x1p-52
        let advanced = try #require(AgentSimulation.advance([original], step: step).first)
        let expected = try #require(Agent.RunningProgress(fraction: 1 - 0x1p-52))
        #expect(advanced == Agent(id: "running", name: "Runner", summary: "Boundary", phase: .running(progress: expected)))
        #expect(original.phase == .running(progress: progress))
    }

    @Test("C3: every non-running phase stays unchanged", arguments: [0.0, 0.5, 2.0])
    func nonRunningUnchanged(_ step: Double) {
        let original = [Agent(id: "idle", name: "Idle", summary: "Waiting", phase: .idle),
                        Agent(id: "done", name: "Done", summary: "Finished", phase: .completed),
                        Agent(id: "failed", name: "Failed", summary: "Stopped", phase: .failed)]
        #expect(AgentSimulation.advance(original, step: step) == original)
    }

    @Test("C3: zero progress has fraction zero")
    func zeroProgress() {
        #expect(Agent.RunningProgress.zero.fraction == 0)
    }
}
