/// A source scan either supplies names for human judgment or reports invalid syntax.
/// Candidates are observations, not lint violations or automatic rename requests.
public enum NamingReview {
    case candidates([Candidate])
    case invalidSource([LintDiagnostic])

    public struct Candidate {
        public let path: String
        public let line: Int
        public let column: Int
        public let name: String
        public let kind: Kind

        public init(path: String, line: Int, column: Int, name: String, kind: Kind) {
            self.path = path
            self.line = line
            self.column = column
            self.name = name
            self.kind = kind
        }
    }

    public enum Kind: String {
        case `struct`
        case `class`
        case `actor`
        case `enum`
        case `protocol`
        case `typealias`
        case `associatedtype`
    }
}

extension NamingReview: Equatable {}

extension NamingReview.Candidate: Codable {}

extension NamingReview.Candidate: Equatable {}

extension NamingReview.Kind: Codable {}
