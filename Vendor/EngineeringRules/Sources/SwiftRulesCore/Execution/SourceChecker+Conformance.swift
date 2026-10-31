import SwiftSyntax

extension SourceChecker {
    /// Local types and private nested types cannot be named by a file-scope
    /// extension without changing their access or lexical ownership.
    static func requiresInlineConformance(_ node: Syntax) -> Bool {
        var ancestor: Syntax? = node
        while let current = ancestor {
            let isFunctionBody = current.is(CodeBlockSyntax.self)
            let isClosureBody = current.is(ClosureExprSyntax.self)
            let isAccessorBody = current.is(AccessorBlockSyntax.self)
            if isFunctionBody || isClosureBody || isAccessorBody { return true }

            let isNominal = isNominalDeclaration(current)
            if isNominal, let modified = current.asProtocol(WithModifiersSyntax.self) {
                let isPrivate = modified.modifiers.contains { $0.name.text == "private" }
                if isPrivate && hasEnclosingType(current) { return true }
            }
            ancestor = current.parent
        }
        return false
    }

    private static func isNominalDeclaration(_ node: Syntax) -> Bool {
        switch node.kind {
        case .structDecl, .enumDecl, .classDecl, .actorDecl, .protocolDecl:
            return true
        default:
            return false
        }
    }

    private static func hasEnclosingType(_ node: Syntax) -> Bool {
        var ancestor = node.parent
        while let current = ancestor {
            if isNominalDeclaration(current) || current.is(ExtensionDeclSyntax.self) { return true }
            ancestor = current.parent
        }
        return false
    }

    static func checkConformances(
        _ tree: SourceFileSyntax, file: SourceFile, scope: RuleScope,
        converter: SourceLocationConverter
    ) -> [LintDiagnostic] {
        guard scope.enforceLayout else { return [] }
        let scan = ConformanceScan(file: file, converter: converter)
        scan.walk(tree)
        scan.checkOrder()
        return scan.diagnostics
    }
}

private final class ConformanceScan: SyntaxVisitor {
    struct ExtensionGroup {
        let owner: String
        let conditionalClauses: [Int]
    }

    private struct WrittenExtension {
        let node: ExtensionDeclSyntax
        let protocols: [String]
        let isEmpty: Bool
    }

    private let file: SourceFile
    private let converter: SourceLocationConverter
    private var extensions: [ExtensionGroup: [WrittenExtension]] = [:]
    private(set) var diagnostics: [LintDiagnostic] = []

    init(file: SourceFile, converter: SourceLocationConverter) {
        self.file = file
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        checkPlacement(node.inheritanceClause, declaration: Syntax(node), skipFirst: false)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        checkPlacement(node.inheritanceClause, declaration: Syntax(node), skipFirst: false)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        // Without name resolution the first item may name a superclass.
        checkPlacement(node.inheritanceClause, declaration: Syntax(node), skipFirst: true)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        // Without name resolution the first item may name the enum's raw type.
        checkPlacement(node.inheritanceClause, declaration: Syntax(node), skipFirst: true)
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let protocols = node.inheritanceClause?.inheritedTypes.flatMap { protocolSpellings($0.type) } ?? []
        if protocols.count > 1, let clause = node.inheritanceClause {
            report(clause, rule: "conformance_extension", message: "Declare each directly written protocol conformance in its own extension.")
        }
        let group = ExtensionGroup(owner: compact(node.extendedType), conditionalClauses: conditionalContext(Syntax(node)))
        let extended = WrittenExtension(node: node, protocols: protocols, isEmpty: node.memberBlock.members.isEmpty)
        extensions[group, default: []].append(extended)
        return .visitChildren
    }

    private func checkPlacement(_ clause: InheritanceClauseSyntax?, declaration: Syntax, skipFirst: Bool) {
        guard let clause, !SourceChecker.requiresInlineConformance(declaration) else { return }
        for (index, inherited) in clause.inheritedTypes.enumerated() {
            if skipFirst && index == 0 { continue }
            guard !protocolSpellings(inherited.type).isEmpty else { continue }
            report(inherited.type, rule: "conformance_placement", message: "Declare this protocol conformance in a dedicated extension.")
        }
    }

    private func protocolSpellings(_ type: TypeSyntax) -> [String] {
        if type.is(SuppressedTypeSyntax.self) { return [] }
        if let attributed = type.as(AttributedTypeSyntax.self) {
            return protocolSpellings(attributed.baseType)
        }
        if let composition = type.as(CompositionTypeSyntax.self) {
            return composition.elements.flatMap { protocolSpellings($0.type) }
        }
        return [compact(type)]
    }

    private func conditionalContext(_ node: Syntax) -> [Int] {
        var clauses: [Int] = []
        var ancestor = node.parent
        while let current = ancestor {
            if let clause = current.as(IfConfigClauseSyntax.self) {
                clauses.append(clause.position.utf8Offset)
            }
            ancestor = current.parent
        }
        return clauses.reversed()
    }

    func checkOrder() {
        for group in extensions.values {
            var previousNonemptyProtocol: String?
            var previousEmptyProtocol: String?
            var hasEmptyExtension = false
            for extended in group {
                let isConformance = !extended.protocols.isEmpty
                if !extended.isEmpty {
                    if hasEmptyExtension {
                        report(extended.node.extendedType, rule: "conformance_order", message: "Put empty extensions after nonempty extensions of the same owner.")
                    }
                    // Multiple written conformances already have a dedicated diagnostic.
                    if extended.protocols.count == 1, let spelling = extended.protocols.first {
                        if let previous = previousNonemptyProtocol, spelling < previous {
                            report(extended.node.extendedType, rule: "conformance_order", message: "Alphabetize nonempty conformance extensions by protocol spelling.")
                        }
                        previousNonemptyProtocol = spelling
                    }
                } else {
                    hasEmptyExtension = true
                    if isConformance, extended.protocols.count == 1, let spelling = extended.protocols.first {
                        if let previous = previousEmptyProtocol, spelling < previous {
                            report(extended.node.extendedType, rule: "conformance_order", message: "Alphabetize empty conformance extensions by protocol spelling.")
                        }
                        previousEmptyProtocol = spelling
                    }
                }
            }
        }
    }

    private func compact(_ node: some SyntaxProtocol) -> String {
        node.tokens(viewMode: .sourceAccurate).map(\.text).joined()
    }

    private func report(_ node: some SyntaxProtocol, rule: String, message: String) {
        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        diagnostics.append(LintDiagnostic(
            path: file.path, line: location.line, column: location.column,
            ruleID: rule, message: message,
            anchor: node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
        ))
    }
}

extension ConformanceScan.ExtensionGroup: Hashable {}
