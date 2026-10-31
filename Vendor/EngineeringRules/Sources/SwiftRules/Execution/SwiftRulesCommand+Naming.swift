import Foundation
import SwiftRulesCore

extension SwiftRulesCommand {
    static func reviewCandidates(files: [SourceFile], asJSON: Bool) throws -> Int32 {
        var candidates: [NamingReview.Candidate] = []
        var failures: [LintDiagnostic] = []
        for file in files {
            switch SourceChecker.reviewCandidates(file) {
            case .candidates(let collected): candidates += collected
            case .invalidSource(let diagnostics): failures += diagnostics
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard failures.isEmpty else {
            if asJSON {
                FileHandle.standardError.write(try encoder.encode(failures))
                FileHandle.standardError.write(Data("\n".utf8))
            } else {
                for failure in failures {
                    let line = "\(failure.path):\(failure.line):\(failure.column): error: \(failure.message) [\(failure.ruleID)]\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
            }
            return 2
        }
        if asJSON {
            let report = NamingInventory(filesScanned: files.count, candidates: candidates)
            FileHandle.standardOutput.write(try encoder.encode(report))
            FileHandle.standardOutput.write(Data("\n".utf8))
        } else {
            for candidate in candidates {
                print("\(candidate.path):\(candidate.line):\(candidate.column): review: \(candidate.kind.rawValue) \(candidate.name) uses Context; judge its meaning and compatibility before renaming.")
            }
            print("Collected \(candidates.count) naming review candidates from \(files.count) files. Candidates are not violations; lint and compiler checks were not run.")
        }
        return 0
    }

    private struct NamingInventory: Encodable {
        let schemaVersion = 1
        let filesScanned: Int
        let candidates: [NamingReview.Candidate]
    }
}
