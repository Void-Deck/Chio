import Foundation
import SwiftRulesCore

struct SwiftLintGate {
    private struct Violation: Decodable {
        let file: String
        let line: Int?
        let character: Int?
        let reason: String
        let rule_id: String
    }
    static func check(files: [SourceFile], root: URL) throws -> [LintDiagnostic] {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.resolvingSymlinksInPath().deletingLastPathComponent().appendingPathComponent("swiftlint")
        let version = try ProcessRunner.run(executable: executable, arguments: ["version"], directory: root)
        guard version.status == 0, version.text.trimmingCharacters(in: .whitespacesAndNewlines) == ToolVersion.swiftLint else { throw ToolFailure.invalid("Require sibling SwiftLint \(ToolVersion.swiftLint); run the shared installer") }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("swift-rules-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: temporary) }
        let configURL = temporary.appendingPathComponent("swiftlint.yml")
        let config = """
        only_rules:
          - duplicate_imports
          - file_name
        file_name:
          severity: error
        duplicate_imports:
          severity: error
        check_for_updates: false
        allow_zero_lintable_files: false
        """
        try config.write(to: configURL, atomically: true, encoding: .utf8)
        var environment = ProcessInfo.processInfo.environment
        environment["SCRIPT_INPUT_FILE_COUNT"] = String(files.count)
        var sources: [String: SourceFile] = [:]
        for (index, file) in files.enumerated() {
            let snapshot = temporary.appendingPathComponent(file.path)
            try FileManager.default.createDirectory(at: snapshot.deletingLastPathComponent(), withIntermediateDirectories: true)
            try file.content.write(to: snapshot, atomically: true, encoding: .utf8)
            environment["SCRIPT_INPUT_FILE_\(index)"] = snapshot.path
            sources[snapshot.path] = file
        }
        let output = try ProcessRunner.run(executable: executable, arguments: ["lint", "--config", configURL.path, "--use-script-input-files", "--reporter", "json", "--quiet", "--no-cache"], environment: environment, directory: temporary)
        guard [0, 2].contains(output.status), let data = output.text.data(using: .utf8) else { throw ToolFailure.invalid("SwiftLint failed with status \(output.status)") }
        let violations = try JSONDecoder().decode([Violation].self, from: data)
        if output.status != 0 && violations.isEmpty { throw ToolFailure.invalid("SwiftLint failed without diagnostics") }
        return try violations.compactMap { violation in
            guard let source = sources[violation.file] else { throw ToolFailure.invalid("SwiftLint returned an unchecked path") }
            let line = violation.line ?? 1
            let lines = source.content.components(separatedBy: .newlines)
            guard line > 0, line <= lines.count else { throw ToolFailure.invalid("SwiftLint returned an invalid line") }
            // SwiftLint requires an exact declared name; the shared layout
            // contract also permits one owner's nested vocabulary in its file.
            // Validate the diagnostic before reconciling only this known case.
            if violation.rule_id == "file_name", SourceChecker.matchesExtensionFilename(source) {
                return nil
            }
            let anchor = lines[line - 1].split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return LintDiagnostic(path: source.path, line: line, column: violation.character ?? 1, ruleID: "swiftlint." + violation.rule_id, message: violation.reason, anchor: anchor)
        }
    }
}
