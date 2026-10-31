public struct LintDiagnostic {
    public let path: String
    public let line: Int
    public let column: Int
    public let ruleID: String
    public let message: String
    public let anchor: String

    public init(path: String, line: Int, column: Int, ruleID: String, message: String, anchor: String) {
        self.path = path
        self.line = line
        self.column = column
        self.ruleID = ruleID
        self.message = message
        self.anchor = anchor
    }
}

extension LintDiagnostic: Codable {}

extension LintDiagnostic: Equatable {}
