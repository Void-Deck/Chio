import SwiftOperators
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

public enum SourceChecker {
    public static func check(_ file: SourceFile, scope: RuleScope) -> [LintDiagnostic] {
        let tree = Parser.parse(source: file.content)
        let converter = SourceLocationConverter(fileName: file.path, tree: tree)
        let parseDiagnostics = ParseDiagnosticsGenerator.diagnostics(for: tree)
        let failures = parseDiagnostics.filter { $0.diagMessage.severity == .error }
        if !failures.isEmpty {
            return failures.map { diagnostic in
                let location = converter.location(for: diagnostic.position)
                return LintDiagnostic(
                    path: file.path, line: location.line, column: location.column,
                    ruleID: "parse_error", message: diagnostic.message,
                    anchor: diagnostic.node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
                )
            }
        }
        // Folding supplies ternary structure using standard and same-file operators.
        // Imported custom precedence is unavailable: its best-effort folding must
        // not suppress other syntax checks or be treated as semantic proof.
        var operators = OperatorTable.standardOperators
        operators.addSourceFile(tree) { _ in }
        let folded = operators.foldAll(tree) { _ in }
        let scan = SourceScan(file: file, scope: scope, converter: converter)
        scan.walk(folded)
        scan.checkLayout(tree)
        let conformanceDiagnostics = checkConformances(tree, file: file, scope: scope, converter: converter)
        return (scan.diagnostics + conformanceDiagnostics).sorted {
            if $0.line != $1.line { return $0.line < $1.line }
            if $0.column != $1.column { return $0.column < $1.column }
            return $0.ruleID < $1.ruleID
        }
    }
}

private final class SourceScan: SyntaxVisitor {
    private let file: SourceFile
    private let scope: RuleScope
    private let converter: SourceLocationConverter
    private(set) var diagnostics: [LintDiagnostic] = []
    private var primaryTypes: [(name: String, node: Syntax)] = []
    private var extensions: [(name: String, node: Syntax)] = []
    private var privateTypeNames: [String] = []
    private var importedModules: Set<String> = []

    init(file: SourceFile, scope: RuleScope, converter: SourceLocationConverter) {
        self.file = file
        self.scope = scope
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private func report(_ node: some SyntaxProtocol, rule: String, message: String, anchor explicitAnchor: String? = nil) {
        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        let anchor = explicitAnchor ?? node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
        diagnostics.append(LintDiagnostic(
            path: file.path, line: location.line, column: location.column,
            ruleID: rule, message: message, anchor: anchor
        ))
    }

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        checkSuppressions(token.leadingTrivia, startingAt: token.position)
        checkSuppressions(token.trailingTrivia, startingAt: token.endPositionBeforeTrailingTrivia)
        return .visitChildren
    }

    private func checkSuppressions(_ trivia: Trivia, startingAt position: AbsolutePosition) {
        var offset = position.utf8Offset
        for piece in trivia {
            switch piece {
            case .lineComment(let comment), .blockComment(let comment), .docLineComment(let comment), .docBlockComment(let comment):
                if suppressesSelectedRule(comment) {
                    let location = converter.location(for: AbsolutePosition(utf8Offset: offset))
                    diagnostics.append(LintDiagnostic(
                        path: file.path, line: location.line, column: location.column,
                        ruleID: "lint_suppression",
                        message: "Do not disable shared SwiftLint rules (duplicate_imports, file_name, or all) in source comments.",
                        anchor: comment
                    ))
                }
            default:
                break
            }
            offset += piece.sourceLength.utf8Length
        }
    }

    private func suppressesSelectedRule(_ comment: String) -> Bool {
        let directives = ["swiftlint:disable", "swiftlint:disable:next", "swiftlint:disable:this", "swiftlint:disable:previous"]
        let selectedRules = ["duplicate_imports", "file_name", "all"]
        for line in comment.split(whereSeparator: { $0.isNewline }) {
            let words = line.split(whereSeparator: { character in
                character.isWhitespace || character == "/" || character == "*" || character == ","
            }).map(String.init)
            for (index, word) in words.enumerated() where directives.contains(word) {
                let ruleWords = words.dropFirst(index + 1).prefix { word in
                    !word.hasPrefix("--") && !word.hasPrefix("swiftlint:")
                }
                if ruleWords.contains(where: { selectedRules.contains($0) }) { return true }
            }
        }
        return false
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self) {
            let isInferredInitializer = member.base == nil && member.declName.baseName.text == "init"
            if isInferredInitializer {
                report(node, rule: "explicit_constructor", message: "Spell out the concrete constructor type instead of .init(...).")
            }
        }
        if scope.isPure && isDirectEffect(node) {
            report(node, rule: "direct_effect", message: "Pass this clock, identity, random choice, or effect outcome into the pure scope explicitly.")
        }
        return .visitChildren
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        let spelling = compact(node)
        let effectProperties = ["Date.now", "Foundation.Date.now", "ProcessInfo.processInfo", "Foundation.ProcessInfo.processInfo", "FileManager.default", "Foundation.FileManager.default", "URLSession.shared", "Foundation.URLSession.shared", "FoundationNetworking.URLSession.shared"]
        if scope.isPure && effectProperties.contains(spelling) {
            report(node, rule: "direct_effect", message: "Read this live/shared value at an effect boundary and pass its outcome explicitly.")
        }
        return .visitChildren
    }

    private func isDirectEffect(_ node: FunctionCallExprSyntax) -> Bool {
        let spelling = compact(node.calledExpression)
        let constructors = ["Date", "Foundation.Date", "UUID", "Foundation.UUID"]
        if constructors.contains(spelling) { return node.arguments.isEmpty && node.trailingClosure == nil }
        let names = ["print", "Swift.print", "debugPrint", "Swift.debugPrint", "dump", "Swift.dump", "Thread.sleep", "Foundation.Thread.sleep", "Task.sleep", "_Concurrency.Task.sleep"]
        if names.contains(spelling) { return true }
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else { return false }
        // A member named random is the documented lexical approximation. No name
        // resolution is attempted, so a custom API with that spelling can match.
        return member.declName.baseName.text == "random"
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if scope.isApplication && isFileScope(Syntax(node)) {
            report(node.name, rule: "no_freestanding_function", message: "Put application operations on an explicit owning type.")
        }
        return .visitChildren
    }

    override func visit(_ node: CodeBlockItemSyntax) -> SyntaxVisitorContinueKind {
        let isExecutable = node.item.is(ExprSyntax.self) || node.item.is(StmtSyntax.self)
        if scope.isApplication && isExecutable && isFileScope(Syntax(node)) {
            report(node.item, rule: "no_freestanding_function", message: "Put top-level application execution on an explicit owning type.")
        }
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard scope.isPure, node.bindingSpecifier.text == "var", isStoredScope(Syntax(node)) else { return .visitChildren }
        for binding in node.bindings {
            var hasMutableStorage = true
            if let accessor = binding.accessorBlock {
                switch accessor.accessors {
                case .getter:
                    hasMutableStorage = false
                case .accessors(let accessors):
                    let names = accessors.map { $0.accessorSpecifier.text }
                    let hasSetter = names.contains("set") || names.contains("_modify")
                    let hasObservers = names.contains("willSet") || names.contains("didSet")
                    hasMutableStorage = hasSetter || hasObservers
                }
            }
            if hasMutableStorage {
                report(binding.pattern, rule: "immutable_domain", message: "Use immutable stored domain values and get-only computed properties in pure scopes.")
            }
        }
        return .visitChildren
    }

    override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind {
        if hasTernary(node.condition) || hasTernary(node.thenExpression) || hasTernary(node.elseExpression) {
            report(node, rule: "no_nested_ternary", message: "Replace nested ternary decisions with named values and explicit branches.")
        }
        return .visitChildren
    }

    private func hasTernary(_ node: some SyntaxProtocol) -> Bool {
        if node.is(TernaryExprSyntax.self) { return true }
        return node.children(viewMode: .sourceAccurate).contains { hasTernary($0) }
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if let root = node.path.first?.name.text { importedModules.insert(root) }
        if let allowed = scope.allowedImports, let root = node.path.first?.name.text, !allowed.contains(root) {
            report(node, rule: "allowed_import", message: "Import '\(root)' is outside this scope's explicit allowed imports.")
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        recordType(name: node.name.text, modifiers: node.modifiers, node: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        recordType(name: node.name.text, modifiers: node.modifiers, node: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        recordType(name: node.name.text, modifiers: node.modifiers, node: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        recordType(name: node.name.text, modifiers: node.modifiers, node: Syntax(node))
        if scope.isPure { report(node.name, rule: "immutable_domain", message: "Use value types for pure domain declarations; reference identity and mutation require an effect boundary.") }
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        recordType(name: node.name.text, modifiers: node.modifiers, node: Syntax(node))
        if scope.isPure { report(node.name, rule: "immutable_domain", message: "Actors own isolated mutable state and belong at an effect boundary.") }
        return .visitChildren
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        recordType(name: node.name.text, modifiers: node.modifiers, node: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if isFileScope(Syntax(node)) {
            extensions.append((name: compact(node.extendedType), node: Syntax(node.extendedType)))
        }
        return .visitChildren
    }

    private func compact(_ node: some SyntaxProtocol) -> String {
        node.tokens(viewMode: .sourceAccurate).map(\.text).joined()
    }

    private func recordType(name: String, modifiers: DeclModifierListSyntax, node: Syntax) {
        let isPrivate = modifiers.contains { $0.name.text == "private" || $0.name.text == "fileprivate" }
        guard isFileScope(node) else { return }
        if isPrivate {
            privateTypeNames.append(name)
        } else {
            let nameToken = node.tokens(viewMode: .sourceAccurate).first { $0.text == name }
            let anchorNode = nameToken.map { Syntax($0) } ?? node
            primaryTypes.append((name: name, node: anchorNode))
        }
    }

    private func isFileScope(_ node: Syntax) -> Bool {
        var ancestor = node.parent
        while let current = ancestor {
            let hasLocalOwner = current.is(CodeBlockSyntax.self) || current.is(ClosureExprSyntax.self)
            let hasTypeOwner = current.is(MemberBlockSyntax.self)
            if hasLocalOwner || hasTypeOwner { return false }
            if current.is(SourceFileSyntax.self) { return true }
            ancestor = current.parent
        }
        return false
    }

    private func isStoredScope(_ node: Syntax) -> Bool {
        var ancestor = node.parent
        while let current = ancestor {
            if current.is(CodeBlockSyntax.self) || current.is(ClosureExprSyntax.self) { return false }
            // Implicit getter bodies contain code-block items without a CodeBlockSyntax.
            if let accessor = current.as(AccessorBlockSyntax.self), case .getter = accessor.accessors { return false }
            if let members = current.as(MemberBlockSyntax.self) {
                return members.parent?.is(ProtocolDeclSyntax.self) != true
            }
            if current.is(SourceFileSyntax.self) { return true }
            ancestor = current.parent
        }
        return false
    }

    func checkLayout(_ tree: SourceFileSyntax) {
        guard scope.enforceLayout else { return }
        let components = file.path.split(separator: "/").map(String.init)
        guard components.first == "Sources" else { return }
        let ownedPath = Array(components.dropFirst())
        guard let filename = ownedPath.last, filename.hasSuffix(".swift") else { return }
        let directories = Array(ownedPath.dropLast())
        if directories.count > scope.maximumDepth {
            report(tree, rule: "source_layout", message: "Source path exceeds the configured directory depth of \(scope.maximumDepth) beneath Sources.", anchor: file.path)
        }
        switch scope.layout {
        case .responsibilityFirst:
            if let responsibility = scope.layout.responsibility(in: directories), !scope.responsibilityGroups.contains(responsibility) {
                report(tree, rule: "source_layout", message: "Use a configured responsibility group immediately beneath the target.", anchor: file.path)
            }
        case .componentFirst:
            let hasResponsibility = scope.layout.responsibility(in: directories).map { scope.responsibilityGroups.contains($0) } ?? false
            if !hasResponsibility {
                report(tree, rule: "source_layout", message: "Use a configured responsibility group immediately beneath the target's component.", anchor: file.path)
            }
        }
        let stem = String(filename.dropLast(6))
        let uniqueNames = Set(primaryTypes.map(\.name))
        if uniqueNames.count > 1 {
            report(primaryTypes[1].node, rule: "source_layout", message: "Give each independently useful top-level type its own matching file.")
        }
        if let primary = primaryTypes.first(where: { $0.name == stem }) ?? primaryTypes.first {
            if stem != primary.name {
                report(primary.node, rule: "source_layout", message: "Name the primary type's file '\(primary.name).swift'.")
            }
            let ownerNames = primaryTypes.map(\.name) + privateTypeNames
            if let unrelated = extensions.first(where: { extended in
                !ownerNames.contains { isOwnerFamily(extended.name, owner: $0) }
            }) {
                report(unrelated.node, rule: "source_layout", message: "Keep extensions with their primary type or its supporting vocabulary; give unrelated owners their own files.")
            }
        } else if !extensions.isEmpty {
            let portions = stem.split(separator: "+", omittingEmptySubsequences: false)
            let hasResponsibilitySuffix = portions.count == 2 && !portions[1].isEmpty
            let ownerName = hasResponsibilitySuffix ? String(portions[0]) : stem
            let ownerNames = extensionFileOwners(named: ownerName) + privateTypeNames
            if let unrelated = extensions.first(where: { extended in
                !ownerNames.contains { isOwnerFamily(extended.name, owner: $0) }
            }) {
                report(unrelated.node, rule: "source_layout", message: "Name extension files 'Type.swift' or 'Type+Responsibility.swift' for their extended owner and nested vocabulary.")
            }
        }
    }

    private func isOwnerFamily(_ extendedName: String, owner: String) -> Bool {
        let isExactOwner = extendedName == owner
        let isNestedVocabulary = extendedName.hasPrefix(owner + ".")
        return isExactOwner || isNestedVocabulary
    }

    private func extensionFileOwners(named owner: String) -> [String] {
        for extended in extensions {
            let components = extended.name.split(separator: ".", maxSplits: 1)
            guard components.count == 2 else { continue }
            let module = String(components[0])
            guard importedModules.contains(module) else { continue }
            let qualifiedOwner = module + "." + owner
            if isOwnerFamily(extended.name, owner: qualifiedOwner) {
                // Keep the first explicit qualified identity. Another imported
                // module's same-named type is not part of this owner's family.
                return [owner, qualifiedOwner]
            }
        }
        return [owner]
    }
}
