import SwiftTUI

enum DashboardScenario: String {
    case normal
    case empty
    case noMatches = "no-matches"
    case failed
    case completed

    var agents: [Agent] {
        get throws {
            switch self {
            case .empty: []
            case .normal, .noMatches: try Agent.examples
            case .failed: try Agent.examples.map { $0.replacingPhase(.failed) }
            case .completed: try Agent.examples.map { $0.replacingPhase(.completed) }
            }
        }
    }

    var query: String {
        switch self {
        case .noMatches: "xyz"
        case .normal, .empty, .failed, .completed: ""
        }
    }

    var initialSelection: Agent.ID? {
        get throws {
            switch self {
            case .noMatches: nil
            case .normal, .empty, .failed, .completed: try agents.first?.id
            }
        }
    }
}

extension DashboardScenario: CaseIterable {}
extension DashboardScenario: ExpressibleByArgument {}
extension DashboardScenario: Hashable {}
extension DashboardScenario: Codable {}
extension DashboardScenario: Sendable {}
