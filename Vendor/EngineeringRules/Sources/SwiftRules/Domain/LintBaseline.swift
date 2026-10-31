import Foundation
import SwiftRulesCore

struct LintBaseline {
    struct Identity {
        let path: String
        let ruleID: String
        let anchor: String
        init(_ diagnostic: LintDiagnostic) {
            path = diagnostic.path
            ruleID = diagnostic.ruleID
            anchor = diagnostic.anchor
        }
    }
    struct Entry {
        let identity: Identity
        let count: Int
        let reason: String
    }
    struct Comparison {
        let violations: [LintDiagnostic]
        let staleEntries: [Entry]
    }
    let schemaVersion: Int
    let entries: [Entry]

    init(diagnostics: [LintDiagnostic], reason: String) {
        schemaVersion = 1
        let grouped = Dictionary(grouping: diagnostics, by: Identity.init)
        entries = grouped.map { Entry(identity: $0.key, count: $0.value.count, reason: reason) }.sorted {
            let left = [$0.identity.path, $0.identity.ruleID, $0.identity.anchor]
            let right = [$1.identity.path, $1.identity.ruleID, $1.identity.anchor]
            return left.lexicographicallyPrecedes(right)
        }
    }

    func validated() throws -> Self {
        let hasUniqueEntries = Set(entries.map(\.identity)).count == entries.count
        let hasValidCountsAndReasons = entries.allSatisfy { $0.count > 0 && !$0.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasSafePaths = entries.allSatisfy { RuleConfiguration.isRelativePath($0.identity.path) }
        let hasNoParseFailures = entries.allSatisfy { !["parse_error", "lint_suppression"].contains($0.identity.ruleID) }
        guard schemaVersion == 1, hasUniqueEntries, hasValidCountsAndReasons, hasSafePaths, hasNoParseFailures else {
            throw ToolFailure.invalid("Malformed baseline: require unique entries, positive counts, reasons, and no parse failures")
        }
        return self
    }

    func comparing(_ diagnostics: [LintDiagnostic]) -> Comparison {
        let allowance = Dictionary(uniqueKeysWithValues: entries.map { ($0.identity, $0.count) })
        var seen: [Identity: Int] = [:]
        var violations: [LintDiagnostic] = []
        for diagnostic in diagnostics {
            let key = Identity(diagnostic)
            seen[key, default: 0] += 1
            if seen[key, default: 0] > allowance[key, default: 0] { violations.append(diagnostic) }
        }
        let stale = entries.filter { seen[$0.identity, default: 0] < $0.count }
        return Comparison(violations: violations, staleEntries: stale)
    }
}
extension LintBaseline: Codable {}
extension LintBaseline.Identity: Codable {}
extension LintBaseline.Identity: Hashable {}
extension LintBaseline.Entry: Codable {}
