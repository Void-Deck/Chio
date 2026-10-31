import Foundation
import SwiftRulesCore

struct CompilerEvidenceGate {
    struct Aggregate {
        let diagnostics: [LintDiagnostic]
        let inputs: Inputs
        let dependencies: [String: Data]

        func verifyUnchanged() throws {
            try inputs.verifyUnchanged()
            try inputs.verify(dependencies)
        }
    }

    static func analyze(
        profileName: String, output: String, files: [SourceFile], repository: SourceRepository
    ) throws {
        guard let profile = repository.configuration.compilerProfiles?.first(where: { $0.name == profileName }) else {
            throw ToolFailure.invalid("Analysis requires a declared compiler profile: \(profileName)")
        }
        #if os(macOS)
        let nativePlatform = CompilerProfile.Platform.macos
        #elseif os(Linux)
        let nativePlatform = CompilerProfile.Platform.linux
        #else
        throw ToolFailure.invalid("Native compiler evidence supports macOS and Linux only")
        #endif
        guard profile.platform == nativePlatform else {
            throw ToolFailure.invalid("Profile \(profile.name) does not match this native platform")
        }
        let reservedPaths = [".swift-rules.json"] + (repository.configuration.compilerProfiles ?? []).map(\.context)
            + (repository.configuration.baseline.map { [$0] } ?? [])
        guard !reservedPaths.contains(output),
              !repository.configuration.sourceRoots.contains(where: { RuleConfiguration.contains(output, under: $0) }) else {
            throw ToolFailure.invalid("Compiler evidence output cannot replace configuration, baseline or source inputs")
        }
        let destination = try repository.containedURL(output)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw ToolFailure.invalid("Compiler evidence output already exists; select a new output path")
        }
        let inputs = try Inputs.capture(files: files, repository: repository)
        let contextData = try Data(contentsOf: repository.containedURL(profile.context))
        let context = try CompilerContext.decode(contextData)
        try RuleConfiguration.validatePathSpellings(files.map(\.path) + context.modules.flatMap(\.sources))
        let paths = Set(context.modules.flatMap(\.sources)).sorted()
        let moduleSources = try inputs.read(paths)
        try inputs.verify(inputs.checkedSources)
        let defaultTarget = try compilerDefaultTarget(context, root: repository.root)
        let targets = try context.nativeTargets(defaultTarget: defaultTarget, platform: nativePlatform)
        let analysis = try CompilerWitnessGate.analyze(files: files, repository: repository, context: context)
        let diagnostics = try CompilerEvidence.merge(analysis.diagnostics)
        try SourceChecker.validateWitnessDiagnostics(diagnostics, files: files)
        let evidence = CompilerEvidence(
            schemaVersion: 1, outcome: "succeeded", toolVersion: ToolVersion.current,
            profile: profile, nativePlatform: nativePlatform, compilerVersion: analysis.compilerVersion,
            defaultTarget: defaultTarget, targets: targets,
            configurationSHA256: try digest(inputs.configurationData),
            checkedSourcesSHA256: try digest(encode(inputs.checkedSources)),
            moduleSourcesSHA256: try digest(encode(moduleSources)),
            checkedPaths: files.map(\.path), indexedPaths: paths, context: contextData, diagnostics: diagnostics
        )
        var data = try encode(evidence)
        data.append(10)
        try inputs.verifyUnchanged()
        try inputs.verify(moduleSources)
        try inputs.verify([profile.context: contextData])
        // A failed rerun cannot leave a previous successful result at this path.
        // Producers use a new filename for each attempt; readers reject truncation.
        try data.write(to: destination, options: .withoutOverwriting)
        print("Recorded partial native witness analysis for \(profile.name) in \(output). Run check with every declared profile before claiming a passing gate.")
    }

    static func aggregate(
        paths: [String], files: [SourceFile], repository: SourceRepository
    ) throws -> Aggregate {
        guard let profiles = repository.configuration.compilerProfiles, paths.count == profiles.count else {
            throw ToolFailure.invalid("Check requires exactly one compiler evidence file for every declared profile")
        }
        let inputs = try Inputs.capture(files: files, repository: repository)
        let configurationSHA256 = try digest(inputs.configurationData)
        let checkedSourcesSHA256 = try digest(encode(inputs.checkedSources))
        let checkedPaths = files.map(\.path)
        var seen: Set<String> = []
        var coverage: Set<String> = []
        var diagnostics: [LintDiagnostic] = []
        var dependencies: [String: Data] = [:]
        var modulePathSpellings = checkedPaths
        for path in paths {
            let data = try Data(contentsOf: repository.containedURL(path))
            let evidence = try CompilerEvidence.decode(data)
            guard let profile = profiles.first(where: { $0.name == evidence.profile.name }), profile == evidence.profile,
                  profile.platform == evidence.nativePlatform, seen.insert(profile.name).inserted else {
                throw ToolFailure.invalid("Unexpected, duplicate or mismatched compiler evidence profile")
            }
            guard evidence.configurationSHA256 == configurationSHA256,
                  evidence.checkedSourcesSHA256 == checkedSourcesSHA256,
                  evidence.checkedPaths == checkedPaths else {
                throw ToolFailure.invalid("Compiler evidence does not match current configuration or checked source bytes")
            }
            let contextData = try Data(contentsOf: repository.containedURL(profile.context))
            guard evidence.context == contextData else {
                throw ToolFailure.invalid("Compiler evidence does not match current context settings for \(profile.name)")
            }
            let context = try CompilerContext.decode(contextData)
            modulePathSpellings += context.modules.flatMap(\.sources)
            try RuleConfiguration.validatePathSpellings(modulePathSpellings + evidence.checkedPaths + evidence.indexedPaths)
            let targets = try context.nativeTargets(defaultTarget: evidence.defaultTarget, platform: profile.platform)
            guard targets == evidence.targets else { throw ToolFailure.invalid("Compiler evidence target mismatch") }
            let modulePaths = Set(context.modules.flatMap(\.sources)).sorted()
            guard modulePaths == evidence.indexedPaths else { throw ToolFailure.invalid("Incomplete compiler evidence index coverage") }
            let moduleSources = try inputs.read(modulePaths)
            guard try digest(encode(moduleSources)) == evidence.moduleSourcesSHA256 else {
                throw ToolFailure.invalid("Compiler evidence does not match current module source bytes")
            }
            for diagnostic in evidence.diagnostics {
                guard moduleSources[diagnostic.path] != nil, inputs.checkedSources[diagnostic.path] != nil,
                      repository.configuration.scope(for: diagnostic.path).enforceLayout else {
                    throw ToolFailure.invalid("Compiler evidence finding is outside checked module scope")
                }
            }
            try SourceChecker.validateWitnessDiagnostics(evidence.diagnostics, files: files)
            diagnostics += try CompilerEvidence.merge(evidence.diagnostics, rejectingDuplicates: true)
            coverage.formUnion(modulePaths)
            var additions = moduleSources
            for (name, bytes) in [(path, data), (profile.context, contextData)] {
                if let previous = additions[name], previous != bytes {
                    throw ToolFailure.invalid("Compiler evidence input paths overlap: \(name)")
                }
                additions[name] = bytes
            }
            for (name, bytes) in additions {
                if let previous = dependencies[name], previous != bytes {
                    throw ToolFailure.invalid("Compiler evidence inputs changed while aggregating: \(name)")
                }
                dependencies[name] = bytes
            }
        }
        let required = Set(files.filter { repository.configuration.scope(for: $0.path).enforceLayout }.map(\.path))
        let missing = required.subtracting(coverage)
        guard missing.isEmpty else {
            throw ToolFailure.invalid("Compiler evidence does not cover checked sources: \(missing.sorted().joined(separator: ", "))")
        }
        let result = Aggregate(diagnostics: try CompilerEvidence.merge(diagnostics), inputs: inputs, dependencies: dependencies)
        try result.verifyUnchanged()
        return result
    }

    private static func compilerDefaultTarget(_ context: CompilerContext, root: URL) throws -> String {
        let output = try ProcessRunner.run(executable: URL(fileURLWithPath: context.compiler), arguments: ["-print-target-info"], directory: root)
        guard output.status == 0,
              let object = try JSONSerialization.jsonObject(with: Data(output.text.utf8)) as? [String: Any],
              let target = object["target"] as? [String: Any], let triple = target["triple"] as? String else {
            throw ToolFailure.invalid("Cannot establish the compiler's default target")
        }
        return triple
    }
}
