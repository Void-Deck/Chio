enum AgentSimulation {
    /// Advances sample tasks by a fixed step. Elapsed wall time is not domain state.
    static func advance(_ agents: [Agent], step: Double = 0.04) -> [Agent] {
        precondition(step.isFinite && step >= 0)
        return agents.map { agent in
            guard case .running(let progress) = agent.phase else { return agent }
            // With a finite nonnegative step, an invalid fraction has reached completion.
            guard let next = Agent.RunningProgress(fraction: progress.fraction + step) else {
                return agent.replacingPhase(.completed)
            }
            return agent.replacingPhase(.running(progress: next))
        }
    }
}
