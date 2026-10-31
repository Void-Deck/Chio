import Foundation
import SwiftRulesCore
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@main
enum SwiftRulesCommand {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--version"] { print(ToolVersion.current); return }
        do { exit(try run(CommandRequest(arguments: arguments))) }
        catch {
            let message: String
            switch error {
            case ToolFailure.invalid(let reason): message = reason
            default: message = String(describing: error)
            }
            FileHandle.standardError.write(Data("swift-rules: \(message)\n".utf8))
            exit(2)
        }
    }

    static func run(_ request: CommandRequest) throws -> Int32 {
        let repository = try SourceRepository(path: request.root)
        let files = try repository.sourceFiles()
        for exclusion in repository.configuration.excludedPaths {
            FileHandle.standardError.write(Data("swift-rules: excluded \(exclusion.path); generator: \(exclusion.generator); freshness must be verified by the consuming gate\n".utf8))
        }
        switch request.action {
        case .analyzeWitnesses(let profile, let output):
            try CompilerEvidenceGate.analyze(profileName: profile, output: output, files: files, repository: repository)
            return 0
        case .reviewCandidates:
            return try reviewCandidates(files: files, asJSON: request.isJSON)
        case .lint(let action):
            return try runLint(action, request: request, repository: repository, files: files)
        }
    }

    private static func runLint(
        _ action: CommandRequest.LintAction,
        request: CommandRequest,
        repository: SourceRepository,
        files: [SourceFile]
    ) throws -> Int32 {
        var diagnostics = files.flatMap { SourceChecker.check($0, scope: repository.configuration.scope(for: $0.path)) }
        guard !diagnostics.contains(where: { ["parse_error", "lint_suppression"].contains($0.ruleID) }) else {
            try report(diagnostics, asJSON: request.isJSON)
            return 2
        }
        diagnostics += try SwiftLintGate.check(files: files, root: repository.root)
        let contextURL: URL?
        let aggregate: CompilerEvidenceGate.Aggregate?
        if repository.configuration.compilerProfiles != nil {
            guard request.compilerContext == nil else {
                throw ToolFailure.invalid("A compiler context override cannot bypass declared compiler profiles")
            }
            aggregate = try CompilerEvidenceGate.aggregate(paths: request.compilerEvidence, files: files, repository: repository)
            contextURL = nil
        } else if !request.compilerEvidence.isEmpty {
            throw ToolFailure.invalid("Compiler evidence requires declared compiler profiles")
        } else if let path = request.compilerContext {
            aggregate = nil
            contextURL = URL(fileURLWithPath: path, relativeTo: repository.root).standardizedFileURL
        } else if let path = repository.configuration.compilerContext {
            aggregate = nil
            contextURL = try repository.containedURL(path)
        } else {
            aggregate = nil
            contextURL = nil
        }
        if let aggregate { diagnostics += aggregate.diagnostics }
        if let contextURL {
            diagnostics += try CompilerWitnessGate.check(files: files, repository: repository, contextURL: contextURL)
        }
        diagnostics.sort {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.line != $1.line { return $0.line < $1.line }
            if $0.column != $1.column { return $0.column < $1.column }
            return $0.ruleID < $1.ruleID
        }
        switch action {
        case .baseline(let output, let reason):
            if let aggregate {
                guard output != ".swift-rules.json", aggregate.inputs.checkedSources[output] == nil,
                      aggregate.dependencies[output] == nil else {
                    throw ToolFailure.invalid("Baseline output cannot replace compiler evidence inputs")
                }
                try aggregate.verifyUnchanged()
            }
            let baseline = LintBaseline(diagnostics: diagnostics, reason: reason)
            let url = try repository.containedURL(output)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            var data = try encoder.encode(baseline)
            data.append(10)
            try data.write(to: url, options: .atomic)
            print("Recorded \(diagnostics.count) existing violations in \(output). Review before committing.")
            return 0
        case .check:
            let baseline: LintBaseline
            var baselineBytes: [String: Data] = [:]
            if let path = repository.configuration.baseline {
                let data = try Data(contentsOf: repository.containedURL(path))
                baselineBytes[path] = data
                baseline = try JSONDecoder().decode(LintBaseline.self, from: data).validated()
            } else { baseline = LintBaseline(diagnostics: [], reason: "No baseline") }
            let comparison = baseline.comparing(diagnostics)
            try aggregate?.verifyUnchanged()
            try aggregate?.inputs.verify(baselineBytes)
            try report(comparison.violations, asJSON: request.isJSON)
            for entry in comparison.staleEntries {
                FileHandle.standardError.write(Data("\(entry.identity.path): error: stale baseline entry [\(entry.identity.ruleID)]; prune the reviewed baseline\n".utf8))
            }
            let hasViolations = !comparison.violations.isEmpty
            let hasStaleEntries = !comparison.staleEntries.isEmpty
            guard !hasViolations, !hasStaleEntries else { return 1 }
            if !request.isJSON {
                print("SwiftRules \(ToolVersion.current): checked \(files.count) files; no new violations (\(diagnostics.count) tracked in baseline).")
                if aggregate != nil {
                    print("Compiler witness analysis passed across every declared native profile.")
                } else if contextURL == nil {
                    print("Compiler witness analysis was not requested; configure compilerContext or pass --compiler-context FILE to check witnesses.")
                } else {
                    print("Compiler witness analysis passed for the supplied build configurations.")
                }
            }
            return 0
        }
    }

    private static func report(_ diagnostics: [LintDiagnostic], asJSON: Bool) throws {
        if asJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            FileHandle.standardOutput.write(try encoder.encode(diagnostics))
            FileHandle.standardOutput.write(Data("\n".utf8))
        } else {
            for diagnostic in diagnostics { print("\(diagnostic.path):\(diagnostic.line):\(diagnostic.column): error: \(diagnostic.message) [\(diagnostic.ruleID)]") }
        }
    }
}
