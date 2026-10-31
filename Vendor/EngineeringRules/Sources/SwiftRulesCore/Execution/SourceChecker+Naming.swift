import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

extension SourceChecker {
    /// Collects owned type declaration names containing case-sensitive `Context`
    /// followed by the end of the name or a character that is not lowercase.
    /// This lexical approximation does not require a preceding word boundary,
    /// infer naming quality, resolve references, or expand generated declarations.
    /// Every written conditional branch participates, in source order.
    public static func reviewCandidates(_ file: SourceFile) -> NamingReview {
        let tree = Parser.parse(source: file.content)
        let converter = SourceLocationConverter(fileName: file.path, tree: tree)
        let failures = ParseDiagnosticsGenerator.diagnostics(for: tree).filter { $0.diagMessage.severity == .error }
        if !failures.isEmpty {
            return .invalidSource(failures.map { diagnostic in
                let location = converter.location(for: diagnostic.position)
                return LintDiagnostic(
                    path: file.path, line: location.line, column: location.column,
                    ruleID: "parse_error", message: diagnostic.message,
                    anchor: diagnostic.node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
                )
            })
        }
        let scan = NamingScan(path: file.path, converter: converter)
        scan.walk(tree)
        return .candidates(scan.candidates)
    }
}

private final class NamingScan: SyntaxVisitor {
    private let path: String
    private let converter: SourceLocationConverter
    private(set) var candidates: [NamingReview.Candidate] = []

    init(path: String, converter: SourceLocationConverter) {
        self.path = path
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name, kind: .struct)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name, kind: .class)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name, kind: .actor)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name, kind: .enum)
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name, kind: .protocol)
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name, kind: .typealias)
        return .visitChildren
    }

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name, kind: .associatedtype)
        return .visitChildren
    }

    private func record(_ token: TokenSyntax, kind: NamingReview.Kind) {
        let spelling = token.text
        let name: String
        if spelling.first == "`", spelling.last == "`" {
            name = String(spelling.dropFirst().dropLast())
        } else {
            name = spelling
        }
        guard containsContextComponent(name) else { return }
        let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
        candidates.append(NamingReview.Candidate(
            path: path, line: location.line, column: location.column, name: name, kind: kind
        ))
    }

    private func containsContextComponent(_ name: String) -> Bool {
        for index in name.indices where name[index...].hasPrefix("Context") {
            let end = name.index(index, offsetBy: "Context".count)
            if end == name.endIndex || !name[end].isLowercase { return true }
        }
        return false
    }
}
