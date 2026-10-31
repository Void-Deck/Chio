import Foundation
import SwiftRulesCore

struct RuleConfiguration {
    struct Exclusion {
        let path: String
        let generator: String
        let reason: String
    }
    struct ImportPolicy {
        let path: String
        let allowed: [String]
    }
    let schemaVersion: Int
    let toolVersion: String
    let sourceRoots: [String]
    let excludedPaths: [Exclusion]
    let applicationRoots: [String]
    let pureGroups: [String]
    let pureTargets: [String]
    let componentFirstTargets: [String]
    let layoutRoots: [String]
    let responsibilityGroups: [String]
    let importPolicies: [ImportPolicy]
    let baseline: String?
    let compilerContext: String?
    let compilerProfiles: [CompilerProfile]?

    init(
        schemaVersion: Int, toolVersion: String, sourceRoots: [String], excludedPaths: [Exclusion],
        applicationRoots: [String], pureGroups: [String], pureTargets: [String], componentFirstTargets: [String],
        layoutRoots: [String], responsibilityGroups: [String], importPolicies: [ImportPolicy],
        baseline: String?, compilerContext: String?, compilerProfiles: [CompilerProfile]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.toolVersion = toolVersion
        self.sourceRoots = sourceRoots
        self.excludedPaths = excludedPaths
        self.applicationRoots = applicationRoots
        self.pureGroups = pureGroups
        self.pureTargets = pureTargets
        self.componentFirstTargets = componentFirstTargets
        self.layoutRoots = layoutRoots
        self.responsibilityGroups = responsibilityGroups
        self.importPolicies = importPolicies
        self.baseline = baseline
        self.compilerContext = compilerContext
        self.compilerProfiles = compilerProfiles
    }

    func validated() throws -> Self {
        guard schemaVersion == 2, toolVersion == ToolVersion.current else {
            throw ToolFailure.invalid("Configuration requires schema 2 (including empty excludedPaths) and SwiftRules \(ToolVersion.current); requested schema \(schemaVersion), tool \(toolVersion); excludedPaths: \(excludedPaths.map(\.path))")
        }
        guard !sourceRoots.isEmpty, !responsibilityGroups.isEmpty else { throw ToolFailure.invalid("Source roots and responsibility groups must be nonempty") }
        let hasSupportedApplicationLayout = applicationRoots.allSatisfy { $0 == "Sources" }
        let hasSupportedLayoutRoot = layoutRoots.allSatisfy { $0 == "Sources" }
        let names = pureGroups + pureTargets + componentFirstTargets + responsibilityGroups
        let hasSimpleGroupNames = names.allSatisfy { Self.isRelativePath($0) && !$0.contains("/") }
        guard hasSupportedApplicationLayout, hasSupportedLayoutRoot, hasSimpleGroupNames else {
            throw ToolFailure.invalid("SwiftRules requires application/layout roots named Sources and single-component target/group names")
        }
        let paths = sourceRoots + applicationRoots + layoutRoots + importPolicies.map(\.path) + (baseline.map { [$0] } ?? []) + (compilerContext.map { [$0] } ?? [])
        for path in paths where !Self.isRelativePath(path) { throw ToolFailure.invalid("Expected a normalized relative path: \(path)") }
        for (index, exclusion) in excludedPaths.enumerated() {
            let entry = "excludedPaths[\(index)] (\(exclusion.path), generator: \(exclusion.generator))"
            guard Self.isRelativePath(exclusion.path) else {
                throw ToolFailure.invalid("\(entry): expected a normalized relative directory path")
            }
            guard exclusion.path.split(separator: "/").last == "Generated" else {
                throw ToolFailure.invalid("\(entry): path must name exactly a Generated directory")
            }
            guard Self.isRelativePath(exclusion.generator),
                  !exclusion.generator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !exclusion.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ToolFailure.invalid("\(entry): generator must be a normalized relative path and reason must be nonempty")
            }
            guard sourceRoots.contains(where: { Self.contains(exclusion.path, under: $0) }) else {
                throw ToolFailure.invalid("\(entry): exclusion must lie inside a configured source root")
            }
            guard !Self.contains(exclusion.generator, under: exclusion.path) else {
                throw ToolFailure.invalid("\(entry): generator must lie outside the excluded directory")
            }
            for previous in excludedPaths.prefix(index) {
                guard !Self.contains(exclusion.path, under: previous.path),
                      !Self.contains(previous.path, under: exclusion.path) else {
                    throw ToolFailure.invalid("\(entry): duplicate or nested exclusion with \(previous.path)")
                }
            }
        }
        let policyPaths = importPolicies.map(\.path)
        guard Set(policyPaths).count == policyPaths.count else { throw ToolFailure.invalid("Duplicate import policy path") }
        guard Set(componentFirstTargets).count == componentFirstTargets.count else { throw ToolFailure.invalid("Duplicate component-first target") }
        if let compilerProfiles {
            guard compilerContext == nil else {
                throw ToolFailure.invalid("compilerContext and compilerProfiles cannot be configured together")
            }
            guard !compilerProfiles.isEmpty else { throw ToolFailure.invalid("Compiler profiles must be nonempty when configured") }
            for profile in compilerProfiles { _ = try profile.validated() }
            let hasUniqueNames = Set(compilerProfiles.map(\.name)).count == compilerProfiles.count
            let hasUniqueContexts = Set(compilerProfiles.map(\.context)).count == compilerProfiles.count
            guard hasUniqueNames, hasUniqueContexts else {
                throw ToolFailure.invalid("Compiler profiles require unique names and context paths")
            }
        }
        return self
    }

    func scope(for path: String) -> RuleScope {
        let parts = path.split(separator: "/").map(String.init)
        let targetIsPure = parts.count > 1 && pureTargets.contains(parts[1])
        let layout: RuleScope.Layout
        if parts.count > 1 && componentFirstTargets.contains(parts[1]) {
            layout = .componentFirst
        } else {
            layout = .responsibilityFirst
        }
        let directories = Array(parts.dropFirst().dropLast())
        let groupIsPure = layout.responsibility(in: directories).map { pureGroups.contains($0) } ?? false
        let isApplication = applicationRoots.contains { Self.contains(path, under: $0) }
        let policy = importPolicies.filter { Self.contains(path, under: $0.path) }.max { $0.path.count < $1.path.count }
        return RuleScope(isApplication: isApplication, isPure: isApplication && (targetIsPure || groupIsPure),
                         allowedImports: policy?.allowed, enforceLayout: layoutRoots.contains { Self.contains(path, under: $0) },
                         responsibilityGroups: responsibilityGroups, layout: layout)
    }

    // Swift String equality folds canonical Unicode spellings; filesystem paths
    // can distinguish them. Reject ambiguity before using String-keyed indexes.
    static func validatePathSpellings(_ paths: [String]) throws {
        var spellings: [String: String] = [:]
        for path in paths {
            if let previous = spellings[path], !previous.utf8.elementsEqual(path.utf8) {
                throw ToolFailure.invalid("Canonically equivalent source paths are unsupported: \(previous), \(path)")
            }
            spellings[path] = path
        }
    }

    static func contains(_ path: String, under prefix: String) -> Bool { path == prefix || path.hasPrefix(prefix + "/") }
    static func isRelativePath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return !parts.isEmpty && parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") && !$0.contains("\n") }
    }
}
extension RuleConfiguration: Decodable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, toolVersion, sourceRoots, excludedPaths, applicationRoots
        case pureGroups, pureTargets, componentFirstTargets, layoutRoots, responsibilityGroups
        case importPolicies, baseline, compilerContext, compilerProfiles
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        toolVersion = try values.decode(String.self, forKey: .toolVersion)
        sourceRoots = try values.decode([String].self, forKey: .sourceRoots)
        excludedPaths = try values.decode([Exclusion].self, forKey: .excludedPaths)
        applicationRoots = try values.decode([String].self, forKey: .applicationRoots)
        pureGroups = try values.decode([String].self, forKey: .pureGroups)
        pureTargets = try values.decode([String].self, forKey: .pureTargets)
        if values.contains(.componentFirstTargets) {
            componentFirstTargets = try values.decode([String].self, forKey: .componentFirstTargets)
        } else {
            componentFirstTargets = []
        }
        layoutRoots = try values.decode([String].self, forKey: .layoutRoots)
        responsibilityGroups = try values.decode([String].self, forKey: .responsibilityGroups)
        importPolicies = try values.decode([ImportPolicy].self, forKey: .importPolicies)
        baseline = try values.decodeIfPresent(String.self, forKey: .baseline)
        if values.contains(.compilerContext) {
            compilerContext = try values.decode(String.self, forKey: .compilerContext)
        } else {
            compilerContext = nil
        }
        if values.contains(.compilerProfiles) {
            compilerProfiles = try values.decode([CompilerProfile].self, forKey: .compilerProfiles)
        } else {
            compilerProfiles = nil
        }
    }
}
extension RuleConfiguration: Encodable {
    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(toolVersion, forKey: .toolVersion)
        try values.encode(sourceRoots, forKey: .sourceRoots)
        try values.encode(excludedPaths, forKey: .excludedPaths)
        try values.encode(applicationRoots, forKey: .applicationRoots)
        try values.encode(pureGroups, forKey: .pureGroups)
        try values.encode(pureTargets, forKey: .pureTargets)
        try values.encode(componentFirstTargets, forKey: .componentFirstTargets)
        try values.encode(layoutRoots, forKey: .layoutRoots)
        try values.encode(responsibilityGroups, forKey: .responsibilityGroups)
        try values.encode(importPolicies, forKey: .importPolicies)
        try values.encode(baseline, forKey: .baseline)
        try values.encodeIfPresent(compilerContext, forKey: .compilerContext)
        try values.encodeIfPresent(compilerProfiles, forKey: .compilerProfiles)
    }
}
extension RuleConfiguration.Exclusion: Decodable {
    private enum CodingKeys: String, CodingKey { case path, generator, reason }

    init(from decoder: any Decoder) throws {
        let entry = decoder.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined()
        do {
            let fields = try decoder.singleValueContainer().decode([String: String].self)
            guard Set(fields.keys) == Set(["path", "generator", "reason"]) else {
                throw ToolFailure.invalid("Expected exactly path, generator and reason")
            }
            let values = try decoder.container(keyedBy: CodingKeys.self)
            path = try values.decode(String.self, forKey: .path)
            generator = try values.decode(String.self, forKey: .generator)
            reason = try values.decode(String.self, forKey: .reason)
        } catch {
            throw ToolFailure.invalid("\(entry): exclusion requires path, generator and reason strings: \(error)")
        }
    }
}
extension RuleConfiguration.Exclusion: Encodable {}
extension RuleConfiguration.ImportPolicy: Codable {}
