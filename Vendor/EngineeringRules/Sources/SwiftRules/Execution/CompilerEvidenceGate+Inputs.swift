import Foundation
import SwiftRulesCore

extension CompilerEvidenceGate {
    struct Inputs {
        let repository: SourceRepository
        let configurationData: Data
        let checkedSources: [String: Data]

        static func capture(files: [SourceFile], repository: SourceRepository) throws -> Self {
            let expected = Dictionary(uniqueKeysWithValues: files.map { ($0.path, Data($0.content.utf8)) })
            let result = Self(repository: repository, configurationData: try encode(repository.configuration), checkedSources: expected)
            try result.verifyUnchanged()
            return result
        }

        func read(_ paths: [String]) throws -> [String: Data] {
            var result: [String: Data] = [:]
            for path in paths { result[path] = try Data(contentsOf: repository.containedURL(path)) }
            return result
        }

        func verify(_ expected: [String: Data]) throws {
            for (path, bytes) in expected {
                guard try Data(contentsOf: repository.containedURL(path)) == bytes else {
                    throw ToolFailure.invalid("Compiler evidence input changed during analysis: \(path)")
                }
            }
        }

        func verifyUnchanged() throws {
            let current = try SourceRepository(path: repository.root.path)
            guard try encode(current.configuration) == configurationData,
                  try current.sourceFiles().map(\.path) == checkedSources.keys.sorted() else {
                throw ToolFailure.invalid("Configuration or source inventory changed during compiler evidence analysis")
            }
            try verify(checkedSources)
        }
    }

    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    /// Hash canonical sorted-key JSON whose Data values encode the exact source
    /// bytes as base64. Paths and contents cannot collide through delimiters.
    static func digest(_ data: Data) throws -> String {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("swift-rules-hash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: temporary) }
        let input = temporary.appendingPathComponent("input")
        try data.write(to: input)
        #if os(macOS)
        let executable = URL(fileURLWithPath: "/usr/bin/shasum")
        let arguments = ["-a", "256", input.path]
        #else
        let executable = URL(fileURLWithPath: "/usr/bin/sha256sum")
        let arguments = [input.path]
        #endif
        let output = try ProcessRunner.run(executable: executable, arguments: arguments, directory: temporary)
        let digest = String(output.text.prefix(64))
        guard output.status == 0, digest.utf8.count == 64,
              digest.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              output.text == digest + "  " + input.path + "\n" else {
            throw ToolFailure.invalid("SHA256 tool failed or returned malformed output")
        }
        return digest
    }
}
