import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax

extension SourceChecker {
    /// A narrow supplement to SwiftLint's exact type-name matching. This proves
    /// only a syntactic owner family, not type resolution or independent usefulness.
    public static func matchesExtensionFilename(_ file: SourceFile) -> Bool {
        guard let filename = file.path.split(separator: "/").last,
              filename.hasSuffix(".swift") else { return false }
        let portions = filename.dropLast(6).split(separator: "+", omittingEmptySubsequences: false)
        let hasPlainName = portions.count == 1
        let hasResponsibility = portions.count == 2 && !portions[1].isEmpty
        guard hasPlainName || hasResponsibility, let owner = portions.first, !owner.isEmpty else { return false }

        let tree = Parser.parse(source: file.content)
        let hasParseError = ParseDiagnosticsGenerator.diagnostics(for: tree).contains { $0.diagMessage.severity == .error }
        guard !hasParseError, let declarations = filenameDeclarations(in: tree.statements) else { return false }
        var helperNames = Set<String>()
        var importedModules = Set<String>()
        var extendedTypes: [TypeSyntax] = []
        for declaration in declarations {
            if let extended = declaration.as(ExtensionDeclSyntax.self) {
                extendedTypes.append(extended.extendedType)
                continue
            }
            if let imported = declaration.as(ImportDeclSyntax.self) {
                if let root = imported.path.first?.name.text { importedModules.insert(root) }
                continue
            }
            let syntax = Syntax(declaration)
            guard let named = syntax.asProtocol(NamedDeclSyntax.self),
                  let modified = syntax.asProtocol(WithModifiersSyntax.self) else { return false }
            let isPrivate = modified.modifiers.contains { $0.name.text == "private" || $0.name.text == "fileprivate" }
            let isSupportingType: Bool
            switch declaration.kind {
            case .structDecl, .enumDecl, .classDecl, .actorDecl, .protocolDecl, .typeAliasDecl:
                isSupportingType = true
            default:
                isSupportingType = false
            }
            guard isPrivate, isSupportingType else { return false }
            helperNames.insert(named.name.text)
        }

        var hasFilenameOwner = false
        for extended in extendedTypes {
            guard let root = filenameTypeRoot(extended) else { return false }
            // An imported root may name a module rather than a local owner.
            // Preserve SwiftLint's finding for this ambiguous qualified spelling.
            guard !importedModules.contains(root) else { return false }
            if root == owner {
                hasFilenameOwner = true
            } else if !helperNames.contains(root) {
                return false
            }
        }
        return hasFilenameOwner
    }

    private static func filenameDeclarations(in items: CodeBlockItemListSyntax) -> [DeclSyntax]? {
        var declarations: [DeclSyntax] = []
        for item in items {
            guard let declaration = item.item.as(DeclSyntax.self) else { return nil }
            if let conditional = declaration.as(IfConfigDeclSyntax.self) {
                for clause in conditional.clauses {
                    guard let elements = clause.elements else { continue }
                    guard let statements = elements.as(CodeBlockItemListSyntax.self),
                          let nested = filenameDeclarations(in: statements) else { return nil }
                    declarations.append(contentsOf: nested)
                }
            } else {
                declarations.append(declaration)
            }
        }
        return declarations
    }

    private static func filenameTypeRoot(_ type: TypeSyntax) -> String? {
        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.genericArgumentClause == nil {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self), member.genericArgumentClause == nil {
            return filenameTypeRoot(member.baseType)
        }
        return nil
    }
}
