import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

extension SourceChecker {
    /// Validates source locations and canonical diagnostic shape in trusted native
    /// evidence. This does not prove compiler witness selection or that a first
    /// inherited type is a protocol; the native compiler run supplies that evidence.
    public static func validateWitnessDiagnostics(
        _ diagnostics: [LintDiagnostic], files: [SourceFile]
    ) throws(CompilerIndex.MappingError) {
        var sources: [String: WitnessSource] = [:]
        for file in files {
            guard sources[file.path] == nil else { throw .duplicateSource(file.path) }
            sources[file.path] = try WitnessSource(file: file)
        }
        for diagnostic in diagnostics {
            guard let source = sources[diagnostic.path], source.file.path.utf8.elementsEqual(diagnostic.path.utf8) else {
                throw .missingSource(diagnostic.path)
            }
            try source.validate(diagnostic)
        }
    }

    public static func checkWitnesses(
        _ files: [SourceFile], scopes: [String: RuleScope], index: CompilerIndex
    ) throws(CompilerIndex.MappingError) -> [LintDiagnostic] {
        var sources: [String: WitnessSource] = [:]
        for file in files {
            guard sources[file.path] == nil else { throw .duplicateSource(file.path) }
            sources[file.path] = try WitnessSource(file: file)
        }
        let compiledPaths = Set(index.sourcePaths)
        for path in compiledPaths where sources[path] == nil { throw .missingSource(path) }
        for file in files where scopes[file.path]?.enforceLayout == true {
            guard compiledPaths.contains(file.path) else { throw .missingSource(file.path) }
        }

        let definitions = Dictionary(grouping: index.occurrences.filter {
            $0.hasRole(CompilerIndex.Role.definition) && !$0.hasRole(CompilerIndex.Role.implicit)
        }, by: { $0.symbol.usr })
        var extensionTargets: [String: Set<String>] = [:]
        for occurrence in index.occurrences {
            for extended in occurrence.relatedSymbols(role: CompilerIndex.Role.extendedBy) {
                extensionTargets[extended.usr, default: []].insert(occurrence.symbol.usr)
            }
        }
        let edges = index.occurrences.filter {
            CompilerIndex.Kind.isWitnessMember($0.symbol.kind)
                && !$0.hasRole(CompilerIndex.Role.accessorOf)
                && !$0.relatedSymbols(role: CompilerIndex.Role.overrideOf).isEmpty
        }
        var requirements: [String: Set<String>] = [:]
        var contexts: [String: Set<String>] = [:]
        for edge in edges {
            if edge.hasRole(CompilerIndex.Role.definition) && edge.hasRole(CompilerIndex.Role.implicit) { continue }
            requirements[edge.symbol.usr, default: []].formUnion(edge.relatedSymbols(role: CompilerIndex.Role.overrideOf).map(\.usr))
            let role = edge.hasRole(CompilerIndex.Role.implicit) ? CompilerIndex.Role.containedBy : CompilerIndex.Role.childOf
            contexts[edge.symbol.usr, default: []].formUnion(edge.relatedSymbols(role: role).map(\.usr))
        }

        var diagnostics: [LintDiagnostic] = []
        var reported: Set<String> = []
        for edge in edges {
            if edge.hasRole(CompilerIndex.Role.definition) && edge.hasRole(CompilerIndex.Role.implicit) { continue }
            // Explicit occurrences already put their declaration in the selected context.
            if !edge.hasRole(CompilerIndex.Role.implicit) {
                if scopes[edge.path]?.enforceLayout == true {
                    guard let source = sources[edge.path] else { throw .missingSource(edge.path) }
                    _ = try source.member(at: edge)
                }
                continue
            }
            let conformanceContexts = edge.relatedSymbols(role: CompilerIndex.Role.containedBy)
            guard conformanceContexts.count == 1, let context = conformanceContexts.first else {
                throw .missingOwner(edge.symbol.usr)
            }
            guard scopes[edge.path]?.enforceLayout == true else { continue }
            let isSharedRequirement = (requirements[edge.symbol.usr]?.count ?? 0) > 1
            let isSharedContext = (contexts[edge.symbol.usr]?.count ?? 0) > 1
            let isSharedWitness = isSharedRequirement || isSharedContext
            guard let candidates = definitions[edge.symbol.usr] else {
                // A complete index can reference an imported default/inherited witness
                // without defining it in the current module. It has no local declaration to move.
                continue
            }
            let uniqueCandidates = uniqueLocations(candidates)
            guard uniqueCandidates.count == 1, let definition = uniqueCandidates.first else {
                throw .ambiguousDefinition(edge.symbol.usr)
            }
            guard let source = sources[definition.path] else { throw .missingSource(definition.path) }
            let member = try source.member(at: definition)
            if member.isLocal || member.isStoredInstance || member.isOverride { continue }
            let owners = definition.relatedSymbols(role: CompilerIndex.Role.childOf)
            guard owners.count == 1, let owner = owners.first else { throw .missingOwner(definition.symbol.usr) }
            if owner.kind == CompilerIndex.Kind.protocol { continue }
            let declaredNominal = try nominalOwner(owner, extensionTargets: extensionTargets)
            let conformingNominal = try nominalOwner(context, extensionTargets: extensionTargets)
            // Defaults on protocol extensions and inherited superclass declarations
            // have a different owner from the directly conforming type.
            guard declaredNominal == conformingNominal else { continue }
            if isSharedWitness {
                let isPrimaryBody = owner.usr == conformingNominal
                let isSelectedConformanceExtension = owner.kind == CompilerIndex.Kind.extension
                    && contexts[edge.symbol.usr]?.contains(owner.usr) == true
                if isPrimaryBody || isSelectedConformanceExtension { continue }
            }
            guard owner.usr != context.usr else { continue }
            guard scopes[definition.path]?.enforceLayout == true else { continue }
            guard reported.insert(definition.symbol.usr).inserted else { continue }
            diagnostics.append(source.witnessDiagnostic(member.anchor))
        }

        // Syntax alone cannot tell whether a class's or enum's first inherited
        // type names a protocol, superclass, or raw-value type.
        for occurrence in index.occurrences where occurrence.symbol.kind == CompilerIndex.Kind.protocol {
            guard scopes[occurrence.path]?.enforceLayout == true else { continue }
            for owner in occurrence.relatedSymbols(role: CompilerIndex.Role.baseOf) {
                guard owner.kind == CompilerIndex.Kind.class || owner.kind == CompilerIndex.Kind.enum else { continue }
                guard let source = sources[occurrence.path] else { throw .missingSource(occurrence.path) }
                if let inherited = try source.firstInheritedType(at: occurrence) {
                    diagnostics.append(source.placementDiagnostic(inherited))
                }
            }
        }
        return diagnostics.sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.line != $1.line { return $0.line < $1.line }
            if $0.column != $1.column { return $0.column < $1.column }
            return $0.ruleID < $1.ruleID
        }
    }

    private static func nominalOwner(
        _ owner: CompilerIndex.Symbol, extensionTargets: [String: Set<String>]
    ) throws(CompilerIndex.MappingError) -> String {
        guard owner.kind == CompilerIndex.Kind.extension else { return owner.usr }
        guard let targets = extensionTargets[owner.usr], targets.count == 1, let target = targets.first else {
            throw .ambiguousExtensionTarget(owner.usr)
        }
        return target
    }

    private static func uniqueLocations(_ occurrences: [CompilerIndex.Occurrence]) -> [CompilerIndex.Occurrence] {
        var locations: Set<String> = []
        return occurrences.filter { locations.insert("\($0.path):\($0.line):\($0.column)").inserted }
    }
}

private struct WitnessMember {
    let anchor: Syntax
    let range: Range<Int>
    let isLocal: Bool
    let isStoredInstance: Bool
    let isOverride: Bool
    let hasWitnessOwner: Bool
}

private struct WitnessInheritance {
    let type: TypeSyntax
    let range: Range<Int>
}

private struct WitnessSource {
    let file: SourceFile
    let converter: SourceLocationConverter
    let lineStarts: [Int]
    let byteCount: Int
    let members: [WitnessMember]
    let inheritedTypes: [WitnessInheritance]

    init(file: SourceFile) throws(CompilerIndex.MappingError) {
        let tree = Parser.parse(source: file.content)
        let hasParseError = ParseDiagnosticsGenerator.diagnostics(for: tree).contains { $0.diagMessage.severity == .error }
        guard !hasParseError else { throw .invalidSyntax(file.path) }
        self.file = file
        converter = SourceLocationConverter(fileName: file.path, tree: tree)
        let bytes = Array(file.content.utf8)
        byteCount = bytes.count
        var starts = [0]
        for (offset, byte) in bytes.enumerated() where byte == 10 { starts.append(offset + 1) }
        lineStarts = starts
        let scan = WitnessSyntaxScan()
        scan.walk(tree)
        members = scan.members
        inheritedTypes = scan.inheritedTypes
    }

    func offset(at occurrence: CompilerIndex.Occurrence) throws(CompilerIndex.MappingError) -> Int {
        try offset(line: occurrence.line, column: occurrence.column)
    }

    private func offset(line: Int, column: Int) throws(CompilerIndex.MappingError) -> Int {
        guard line > 0, column > 0, lineStarts.indices.contains(line - 1) else {
            throw .invalidLocation(path: file.path, line: line, column: column)
        }
        let start = lineStarts[line - 1]
        let end = line < lineStarts.count ? lineStarts[line] : byteCount
        guard column <= end - start else {
            throw .invalidLocation(path: file.path, line: line, column: column)
        }
        return start + column - 1
    }

    func member(at occurrence: CompilerIndex.Occurrence) throws(CompilerIndex.MappingError) -> WitnessMember {
        let offset = try offset(at: occurrence)
        let matches = members.filter { $0.range.contains(offset) }
        guard let match = matches.first else {
            throw .missingDeclaration(path: file.path, line: occurrence.line, column: occurrence.column)
        }
        guard matches.count == 1 else {
            throw .ambiguousDeclaration(path: file.path, line: occurrence.line, column: occurrence.column)
        }
        return match
    }

    func firstInheritedType(at occurrence: CompilerIndex.Occurrence) throws(CompilerIndex.MappingError) -> TypeSyntax? {
        let offset = try offset(at: occurrence)
        return inheritedTypes.first { $0.range.contains(offset) }?.type
    }

    func validate(_ diagnostic: LintDiagnostic) throws(CompilerIndex.MappingError) {
        _ = try offset(line: diagnostic.line, column: diagnostic.column)
        let matchesSource: Bool
        switch diagnostic.ruleID {
        case "conformance_witness":
            matchesSource = members.contains { member in
                let isPermitted = member.hasWitnessOwner && !member.isLocal
                    && !member.isStoredInstance && !member.isOverride
                return isPermitted && witnessDiagnostic(member.anchor) == diagnostic
            }
        case "conformance_placement":
            matchesSource = inheritedTypes.contains { placementDiagnostic($0.type) == diagnostic }
        default:
            matchesSource = false
        }
        guard matchesSource else {
            throw .missingDeclaration(path: file.path, line: diagnostic.line, column: diagnostic.column)
        }
    }

    func witnessDiagnostic(_ anchor: Syntax) -> LintDiagnostic {
        diagnostic(
            anchor, ruleID: "conformance_witness",
            message: "Put this compiler-selected protocol witness in the extension declaring its conformance."
        )
    }

    func placementDiagnostic(_ type: TypeSyntax) -> LintDiagnostic {
        diagnostic(
            Syntax(type), ruleID: "conformance_placement",
            message: "Declare this protocol conformance in a dedicated extension."
        )
    }

    private func diagnostic(_ anchor: Syntax, ruleID: String, message: String) -> LintDiagnostic {
        let location = converter.location(for: anchor.positionAfterSkippingLeadingTrivia)
        return LintDiagnostic(
            path: file.path, line: location.line, column: location.column,
            ruleID: ruleID, message: message,
            anchor: anchor.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
        )
    }
}

private final class WitnessSyntaxScan: SyntaxVisitor {
    private(set) var members: [WitnessMember] = []
    private(set) var inheritedTypes: [WitnessInheritance] = []

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        members.append(WitnessMember(
            anchor: Syntax(node.name), range: sourceRange(node.name), isLocal: isLocal(Syntax(node)),
            isStoredInstance: false, isOverride: node.modifiers.contains { $0.name.text == "override" },
            hasWitnessOwner: hasWitnessOwner(Syntax(node))
        ))
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let isStatic = node.modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }
        for binding in node.bindings {
            let isStored: Bool
            if let accessor = binding.accessorBlock {
                switch accessor.accessors {
                case .getter: isStored = false
                case .accessors(let accessors):
                    isStored = accessors.allSatisfy { $0.accessorSpecifier.text == "willSet" || $0.accessorSpecifier.text == "didSet" }
                }
            } else {
                isStored = true
            }
            members.append(WitnessMember(
                anchor: Syntax(binding.pattern), range: sourceRange(binding.pattern), isLocal: isLocal(Syntax(node)),
                isStoredInstance: isStored && !isStatic,
                isOverride: node.modifiers.contains { $0.name.text == "override" },
                hasWitnessOwner: hasWitnessOwner(Syntax(node))
            ))
        }
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        recordFirstInheritance(node.inheritanceClause, declaration: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        recordFirstInheritance(node.inheritanceClause, declaration: Syntax(node))
        return .visitChildren
    }

    private func recordFirstInheritance(_ clause: InheritanceClauseSyntax?, declaration: Syntax) {
        guard !SourceChecker.requiresInlineConformance(declaration), let first = clause?.inheritedTypes.first else { return }
        guard !isSuppressed(first.type) else { return }
        inheritedTypes.append(WitnessInheritance(type: first.type, range: sourceRange(first.type)))
    }

    private func isSuppressed(_ type: TypeSyntax) -> Bool {
        if type.is(SuppressedTypeSyntax.self) { return true }
        if let attributed = type.as(AttributedTypeSyntax.self) { return isSuppressed(attributed.baseType) }
        return false
    }

    private func sourceRange(_ node: some SyntaxProtocol) -> Range<Int> {
        node.positionAfterSkippingLeadingTrivia.utf8Offset..<node.endPositionBeforeTrailingTrivia.utf8Offset
    }

    private func hasWitnessOwner(_ node: Syntax) -> Bool {
        var ancestor = node.parent
        while let current = ancestor {
            if current.is(ProtocolDeclSyntax.self) { return false }
            let isNominal = current.is(StructDeclSyntax.self) || current.is(ClassDeclSyntax.self)
                || current.is(EnumDeclSyntax.self) || current.is(ActorDeclSyntax.self)
            if isNominal || current.is(ExtensionDeclSyntax.self) { return true }
            ancestor = current.parent
        }
        return false
    }

    private func isLocal(_ node: Syntax) -> Bool {
        var ancestor = node.parent
        while let current = ancestor {
            let isFunctionBody = current.is(CodeBlockSyntax.self)
            let isClosureBody = current.is(ClosureExprSyntax.self)
            let isAccessorBody = current.is(AccessorBlockSyntax.self)
            if isFunctionBody || isClosureBody || isAccessorBody { return true }
            ancestor = current.parent
        }
        return false
    }
}
