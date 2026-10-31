import Foundation
import SwiftRulesCore

struct SourceRepository {
    let root: URL
    let configuration: RuleConfiguration

    init(path: String) throws {
        root = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
        let data = try Data(contentsOf: root.appendingPathComponent(".swift-rules.json"))
        guard let keys = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?.keys else { throw ToolFailure.invalid("Configuration must be an object") }
        let known = Set(["schemaVersion", "toolVersion", "sourceRoots", "excludedPaths", "applicationRoots", "pureGroups", "pureTargets", "componentFirstTargets", "layoutRoots", "responsibilityGroups", "importPolicies", "baseline", "compilerContext", "compilerProfiles"])
        guard Set(keys).isSubset(of: known) else { throw ToolFailure.invalid("Unknown configuration key") }
        configuration = try JSONDecoder().decode(RuleConfiguration.self, from: data).validated()
        try validateExclusions()
    }

    private func validateExclusions() throws {
        for (index, exclusion) in configuration.excludedPaths.enumerated() {
            do {
                let directory = try containedURL(exclusion.path)
                let generator = try containedURL(exclusion.generator)
                let manager = FileManager.default
                let directoryType = try manager.attributesOfItem(atPath: directory.path)[.type] as? FileAttributeType
                let generatorType = try manager.attributesOfItem(atPath: generator.path)[.type] as? FileAttributeType
                guard directoryType == .typeDirectory else {
                    throw ToolFailure.invalid("Exclusion must be an existing directory")
                }
                guard generatorType == .typeRegular else {
                    throw ToolFailure.invalid("Generator must be an existing regular file")
                }
            } catch {
                throw ToolFailure.invalid("excludedPaths[\(index)] (\(exclusion.path), generator: \(exclusion.generator)): \(error)")
            }
        }
    }

    func sourceFiles() throws -> [SourceFile] {
        var result: [String: SourceFile] = [:]
        let manager = FileManager.default
        let rootComponents = root.standardizedFileURL.pathComponents
        for sourceRoot in configuration.sourceRoots {
            let url = try containedURL(sourceRoot)
            var isDirectory: ObjCBool = false
            guard manager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw ToolFailure.invalid("Missing source directory: \(sourceRoot)") }
            var enumerationFailure: Error?
            guard let enumerator = manager.enumerator(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey], options: [], errorHandler: { _, error in enumerationFailure = error; return false }) else {
                throw ToolFailure.invalid("Cannot enumerate \(sourceRoot)")
            }
            for case let fileURL as URL in enumerator {
                // Enumeration may use a different macOS /private alias than the root.
                // Keep the original URL for symlink checks and source reads.
                let fileComponents = fileURL.standardizedFileURL.pathComponents
                guard fileComponents.starts(with: rootComponents), fileComponents.count > rootComponents.count else {
                    throw ToolFailure.invalid("Enumerated source path is outside repository root: \(fileURL.path)")
                }
                let relative = fileComponents.dropFirst(rootComponents.count).joined(separator: "/")
                guard RuleConfiguration.isRelativePath(relative) else { throw ToolFailure.invalid("Expected normalized source path: \(relative)") }
                if configuration.excludedPaths.contains(where: { RuleConfiguration.contains(relative, under: $0.path) }) { enumerator.skipDescendants(); continue }
                let properties = try fileURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
                guard properties.isSymbolicLink != true else { throw ToolFailure.invalid("Symlink in checked source tree: \(relative)") }
                if properties.isDirectory == true { continue }
                guard fileURL.pathExtension == "swift" else { continue }
                let isApplication = configuration.applicationRoots.contains { RuleConfiguration.contains(relative, under: $0) }
                let hasImportPolicy = configuration.importPolicies.contains { RuleConfiguration.contains(relative, under: $0.path) }
                guard !isApplication || hasImportPolicy else { throw ToolFailure.invalid("Application source needs an explicit import policy: \(relative)") }
                if let previous = result[relative] {
                    try RuleConfiguration.validatePathSpellings([previous.path, relative])
                }
                result[relative] = try sourceFile(relative)
            }
            if let enumerationFailure { throw enumerationFailure }
        }
        guard !result.isEmpty else { throw ToolFailure.invalid("No Swift files found in configured roots") }
        return result.values.sorted { $0.path < $1.path }
    }

    func sourceFile(_ path: String) throws -> SourceFile {
        let data = try Data(contentsOf: containedURL(path))
        guard String(data: data, encoding: .utf8) != nil else {
            throw ToolFailure.invalid("Source is not valid UTF-8: \(path)")
        }
        return SourceFile(path: path, content: String(decoding: data, as: UTF8.self))
    }

    func containedURL(_ path: String) throws -> URL {
        guard RuleConfiguration.isRelativePath(path) else { throw ToolFailure.invalid("Expected relative path: \(path)") }
        var url = root
        for component in path.split(separator: "/") {
            url.appendPathComponent(String(component))
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                guard attributes[.type] as? FileAttributeType != .typeSymbolicLink else {
                    throw ToolFailure.invalid("Symlink in configured path: \(path)")
                }
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
                // A new baseline output may not exist yet; source roots are checked separately.
                continue
            }
        }
        guard url.path.hasPrefix(root.path + "/") else { throw ToolFailure.invalid("Path escapes repository: \(path)") }
        return url
    }
}
