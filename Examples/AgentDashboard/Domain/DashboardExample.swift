/// One resolved example; command-line flags are only an input representation.
enum DashboardExample {
    case dashboard
    case choices
    case textEntry
    case feedback
    case files
    case keyboardHelp
    case tabs
    case pagination
    case viewport
    case tree
    case forms
    case timers
    case metrics
    case instruments
    case inbox
    case diff
    case appearance

    var isFocusedExample: Bool {
        switch self {
        case .dashboard:
            false
        case .choices, .textEntry, .feedback, .files, .keyboardHelp, .tabs,
             .pagination, .viewport, .tree, .forms, .timers, .metrics, .instruments, .inbox, .diff, .appearance:
            true
        }
    }

    var supportsDirectory: Bool {
        switch self {
        case .files: true
        case .dashboard, .choices, .textEntry, .feedback, .keyboardHelp, .tabs,
             .pagination, .viewport, .tree, .forms, .timers, .metrics, .instruments, .inbox, .diff, .appearance: false
        }
    }

    var supportsSnapshot: Bool {
        switch self {
        case .files: false
        case .dashboard, .choices, .textEntry, .feedback, .keyboardHelp, .tabs,
             .pagination, .viewport, .tree, .forms, .timers, .metrics, .instruments, .inbox, .diff, .appearance: true
        }
    }

    var defaultTheme: ExampleTheme {
        switch self {
        case .metrics:
            .btop
        case .dashboard, .choices, .textEntry, .feedback, .files, .keyboardHelp,
             .tabs, .pagination, .viewport, .tree, .forms, .timers, .instruments, .inbox, .diff, .appearance:
            .default
        }
    }
}

extension DashboardExample: Hashable {}
extension DashboardExample: Codable {}
extension DashboardExample: Sendable {}
