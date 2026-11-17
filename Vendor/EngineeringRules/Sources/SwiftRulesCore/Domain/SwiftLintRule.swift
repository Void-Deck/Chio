/// A pinned built-in SwiftLint rule that SwiftRules selects and protects from
/// source suppression.
public enum SwiftLintRule: String {
    case duplicateImports = "duplicate_imports"
    case fileName = "file_name"
    case forceUnwrapping = "force_unwrapping"
    case forceTry = "force_try"
    case forceCast = "force_cast"
    case implicitlyUnwrappedOptional = "implicitly_unwrapped_optional"

    /// The rule ID SwiftRules reports and baselines record.
    public var diagnosticID: String { "swiftlint." + rawValue }

    /// SwiftLint options beyond error severity. They remove SwiftLint's built-in
    /// exceptions, because the force rules have none.
    public var configurationOptions: [String] {
        switch self {
        case .duplicateImports, .fileName, .forceTry, .forceCast: []
        case .forceUnwrapping: ["ignored_literal_argument_functions: []"]
        case .implicitlyUnwrappedOptional: ["mode: all"]
        }
    }

    /// Force operations have no exception, so a baseline cannot record them.
    public var permitsBaselineEntry: Bool {
        switch self {
        case .duplicateImports, .fileName: true
        case .forceUnwrapping, .forceTry, .forceCast, .implicitlyUnwrappedOptional: false
        }
    }

    public static func permitsBaselineEntry(forDiagnosticID ruleID: String) -> Bool {
        allCases.first { $0.diagnosticID == ruleID }?.permitsBaselineEntry ?? true
    }
}

extension SwiftLintRule: CaseIterable {}
