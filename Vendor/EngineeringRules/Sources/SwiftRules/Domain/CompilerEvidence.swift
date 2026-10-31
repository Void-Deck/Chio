import Foundation
import SwiftRulesCore

/// A trusted producer's successful, partial semantic analysis. Hashes bind
/// inputs; this document does not authenticate that a compiler executed.
struct CompilerEvidence {
    let schemaVersion: Int
    let outcome: String
    let toolVersion: String
    let profile: CompilerProfile
    let nativePlatform: CompilerProfile.Platform
    let compilerVersion: String
    let defaultTarget: String
    let targets: [String]
    let configurationSHA256: String
    let checkedSourcesSHA256: String
    let moduleSourcesSHA256: String
    let checkedPaths: [String]
    let indexedPaths: [String]
    let context: Data
    let diagnostics: [LintDiagnostic]

    static func decode(_ data: Data) throws -> Self {
        let keys: Set<String> = [
            "schemaVersion", "outcome", "toolVersion", "profile", "nativePlatform", "compilerVersion",
            "defaultTarget", "targets", "configurationSHA256", "checkedSourcesSHA256", "moduleSourcesSHA256",
            "checkedPaths", "indexedPaths", "context", "diagnostics",
        ]
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == keys, let diagnostics = object["diagnostics"] as? [[String: Any]],
              diagnostics.allSatisfy({ Set($0.keys) == ["path", "line", "column", "ruleID", "message", "anchor"] }) else {
            throw ToolFailure.invalid("Invalid compiler evidence fields")
        }
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard result.schemaVersion == 1, result.outcome == "succeeded", result.toolVersion == ToolVersion.current,
              CompilerContext.supports(version: result.compilerVersion) else {
            throw ToolFailure.invalid("Compiler evidence requires a successful supported analysis and matching tool version")
        }
        for digest in [result.configurationSHA256, result.checkedSourcesSHA256, result.moduleSourcesSHA256] {
            guard digest.utf8.count == 64, digest.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
                throw ToolFailure.invalid("Invalid compiler evidence SHA256")
            }
        }
        for paths in [result.checkedPaths, result.indexedPaths] {
            guard !paths.isEmpty, paths == paths.sorted(), Set(paths).count == paths.count,
                  paths.allSatisfy({ RuleConfiguration.isRelativePath($0) && $0.hasSuffix(".swift") }) else {
                throw ToolFailure.invalid("Compiler evidence needs unique sorted source paths")
            }
        }
        return result
    }

    static func merge(_ diagnostics: [LintDiagnostic], rejectingDuplicates: Bool = false) throws -> [LintDiagnostic] {
        var result: [Occurrence: LintDiagnostic] = [:]
        for diagnostic in diagnostics {
            let occurrence = Occurrence(diagnostic)
            if let previous = result[occurrence] {
                guard !rejectingDuplicates, previous == diagnostic else {
                    throw ToolFailure.invalid("Duplicate or inconsistent compiler evidence finding at \(diagnostic.path):\(diagnostic.line):\(diagnostic.column)")
                }
            }
            result[occurrence] = diagnostic
        }
        return result.values.sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.line != $1.line { return $0.line < $1.line }
            if $0.column != $1.column { return $0.column < $1.column }
            return $0.ruleID < $1.ruleID
        }
    }

    fileprivate struct Occurrence {
        let path: String
        let line: Int
        let column: Int
        let ruleID: String
        let anchor: String

        init(_ diagnostic: LintDiagnostic) {
            path = diagnostic.path
            line = diagnostic.line
            column = diagnostic.column
            ruleID = diagnostic.ruleID
            anchor = diagnostic.anchor
        }
    }
}

extension CompilerEvidence: Codable {}
extension CompilerEvidence.Occurrence: Hashable {}
