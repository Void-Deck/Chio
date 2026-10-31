import Foundation
import SwiftRulesCore

struct CompilerWitnessGate {
    struct Analysis {
        let diagnostics: [LintDiagnostic]
        let compilerVersion: String
    }

    static func check(
        files: [SourceFile], repository: SourceRepository, contextURL: URL
    ) throws -> [LintDiagnostic] {
        let context = try CompilerContext.decode(Data(contentsOf: contextURL))
        let requiredPaths = Set(files.filter { repository.configuration.scope(for: $0.path).enforceLayout }.map(\.path))
        let coveredPaths = Set(context.modules.flatMap(\.sources))
        let missing = requiredPaths.subtracting(coveredPaths)
        guard missing.isEmpty else {
            throw ToolFailure.invalid("Compiler context does not cover checked sources: \(missing.sorted().joined(separator: ", "))")
        }
        return try analyze(files: files, repository: repository, context: context).diagnostics
    }

    // Partial coverage is permitted only for native evidence production. Callers
    // must aggregate every declared profile before applying a baseline.
    static func analyze(
        files: [SourceFile], repository: SourceRepository, context: CompilerContext
    ) throws -> Analysis {
        let compiler = URL(fileURLWithPath: context.compiler)
        let version = try ProcessRunner.run(executable: compiler, arguments: ["--version"], directory: repository.root)
        guard version.status == 0, CompilerContext.supports(version: version.text) else {
            throw ToolFailure.invalid("Compiler witness analysis requires a supported Swift 6.4 compiler")
        }
        let library: URL
        if let path = context.indexStoreLibrary {
            library = URL(fileURLWithPath: path)
        } else {
            #if os(macOS)
            let filename = "libIndexStore.dylib"
            #else
            let filename = "libIndexStore.so"
            #endif
            library = compiler.resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("lib").appendingPathComponent(filename)
        }
        try RuleConfiguration.validatePathSpellings(files.map(\.path) + context.modules.flatMap(\.sources))
        let checkedFiles = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0) })
        let coveredPaths = Set(context.modules.flatMap(\.sources))
        var inputFiles = checkedFiles
        for path in coveredPaths.sorted() where inputFiles[path] == nil {
            inputFiles[path] = try repository.sourceFile(path)
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("swift-rules-compiler-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: temporary) }
        var diagnostics: [LintDiagnostic] = []
        for (moduleIndex, module) in context.modules.enumerated() {
            let moduleDirectory = temporary.appendingPathComponent(String(moduleIndex))
            try FileManager.default.createDirectory(at: moduleDirectory, withIntermediateDirectories: true)
            let store = moduleDirectory.appendingPathComponent("index")
            let cache = temporary.appendingPathComponent("module-cache")
            let sourceURLs = try module.sources.map { try repository.containedURL($0) }
            let snapshots = module.sources.compactMap { inputFiles[$0] }
            try verifySnapshots(snapshots, urls: sourceURLs)
            var arguments = ["-frontend", "-typecheck", "-module-name", module.name]
            arguments += module.arguments
            arguments += ["-module-cache-path", cache.path, "-index-store-path", store.path]
            for sourceIndex in module.sources.indices {
                arguments += ["-index-unit-output-path", moduleDirectory.appendingPathComponent("unit-\(sourceIndex).o").path]
            }
            arguments += sourceURLs.map(\.path)
            let output = try ProcessRunner.run(executable: compiler, arguments: arguments, directory: repository.root)
            guard output.status == 0 else {
                throw ToolFailure.invalid("Compiler witness analysis failed for \(module.configuration) (compiler exit \(output.status)); no partial index was accepted")
            }
            try verifySnapshots(snapshots, urls: sourceURLs)
            let index = try CompilerIndexReader.read(store: store, library: library, root: repository.root)
            let unindexed = Set(module.sources).subtracting(index.sourcePaths)
            guard unindexed.isEmpty else {
                throw ToolFailure.invalid("Compiler index is incomplete for \(module.configuration): \(unindexed.sorted().joined(separator: ", "))")
            }
            let scopes = Dictionary(uniqueKeysWithValues: module.sources.compactMap { path -> (String, RuleScope)? in
                guard checkedFiles[path] != nil else { return nil }
                return (path, repository.configuration.scope(for: path))
            })
            let modulePaths = Set(module.sources)
            let moduleIndex = CompilerIndex(
                occurrences: index.occurrences.filter { modulePaths.contains($0.path) },
                sourcePaths: index.sourcePaths.filter { modulePaths.contains($0) }
            )
            diagnostics += try SourceChecker.checkWitnesses(snapshots, scopes: scopes, index: moduleIndex)
        }
        // Prevent a later configuration from invalidating evidence for an earlier
        // one, including files shared by more than one module/configuration.
        let allInputs = inputFiles.values.sorted { $0.path < $1.path }
        try verifySnapshots(allInputs, urls: try allInputs.map { try repository.containedURL($0.path) })
        var unique: [LintDiagnostic] = []
        for diagnostic in diagnostics where !unique.contains(diagnostic) { unique.append(diagnostic) }
        return Analysis(diagnostics: unique, compilerVersion: version.text)
    }

    private static func verifySnapshots(_ snapshots: [SourceFile], urls: [URL]) throws {
        for (file, url) in zip(snapshots, urls) {
            let current = try Data(contentsOf: url)
            guard current == Data(file.content.utf8) else {
                throw ToolFailure.invalid("Source changed during compiler analysis: \(file.path); retry against a stable source snapshot")
            }
        }
    }
}
