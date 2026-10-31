import Foundation

/// Explicit build settings for fresh semantic analysis. These are compiler
/// arguments, never a shell command or a request to build/download dependencies.
struct CompilerContext {
    struct Module {
        let name: String
        let configuration: String
        let sources: [String]
        let arguments: [String]
    }

    let schemaVersion: Int
    let compiler: String
    let indexStoreLibrary: String?
    let modules: [Module]

    static func supports(version: String) -> Bool {
        version.contains("Swift version 6.4 ") || version.contains("Swift version 6.4.")
    }

    static func decode(_ data: Data) throws -> Self {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolFailure.invalid("Compiler context must be an object")
        }
        let allowedKeys = Set(["schemaVersion", "compiler", "indexStoreLibrary", "modules"])
        guard Set(object.keys).isSubset(of: allowedKeys), let rawModules = object["modules"] as? [[String: Any]] else {
            throw ToolFailure.invalid("Unknown compiler context key or invalid modules")
        }
        let moduleKeys = Set(["name", "configuration", "sources", "arguments"])
        guard rawModules.allSatisfy({ Set($0.keys).isSubset(of: moduleKeys) }) else {
            throw ToolFailure.invalid("Unknown compiler module key")
        }
        let context = try JSONDecoder().decode(Self.self, from: data)
        guard context.schemaVersion == 1, context.compiler.hasPrefix("/"), !context.modules.isEmpty else {
            throw ToolFailure.invalid("Compiler context needs schema 1, an absolute swiftc path and nonempty modules")
        }
        if let library = context.indexStoreLibrary, !library.hasPrefix("/") {
            throw ToolFailure.invalid("indexStoreLibrary must be an absolute toolchain library path")
        }
        let configurations = context.modules.map(\.configuration)
        guard Set(configurations).count == configurations.count else {
            throw ToolFailure.invalid("Compiler configuration labels must be unique")
        }
        for module in context.modules {
            let hasName = !module.name.isEmpty && module.name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
            let hasConfiguration = !module.configuration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasUniqueSources = !module.sources.isEmpty && Set(module.sources).count == module.sources.count
            let hasSourcePaths = module.sources.allSatisfy { RuleConfiguration.isRelativePath($0) && $0.hasSuffix(".swift") }
            guard hasName, hasConfiguration, hasUniqueSources, hasSourcePaths else {
                throw ToolFailure.invalid("Compiler modules need a name, configuration label and unique relative Swift source paths")
            }
            try validate(arguments: module.arguments)
        }
        try RuleConfiguration.validatePathSpellings(context.modules.flatMap(\.sources))
        return context
    }

    func nativeTargets(defaultTarget: String, platform: CompilerProfile.Platform) throws -> [String] {
        guard Self.matches(target: defaultTarget, platform: platform) else {
            throw ToolFailure.invalid("Compiler default target does not match the declared native platform")
        }
        return try modules.map { module in
            var targets: [String] = []
            var position = 0
            while position < module.arguments.count {
                let argument = module.arguments[position]
                if argument == "-target" { targets.append(module.arguments[position + 1]) }
                if argument.hasPrefix("-target=") { targets.append(String(argument.dropFirst(8))) }
                if argument == "-Xcc" || Self.argumentValueOptions.contains(argument) {
                    position += 2
                } else {
                    position += 1
                }
            }
            guard Set(targets).count <= 1 else {
                throw ToolFailure.invalid("Conflicting compiler targets in \(module.configuration)")
            }
            let target = targets.first ?? defaultTarget
            guard Self.matches(target: target, platform: platform) else {
                throw ToolFailure.invalid("Compiler target does not match the declared native platform: \(target)")
            }
            return target
        }
    }

    private static func matches(target: String, platform: CompilerProfile.Platform) -> Bool {
        let components = target.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count >= 3, !components[0].isEmpty, !components[1].isEmpty else { return false }
        switch platform {
        case .linux:
            return components[2] == "linux"
        case .macos:
            guard components[1] == "apple", components[2].hasPrefix("macosx") else { return false }
            return components[2].dropFirst(6).allSatisfy { $0.isASCII && ($0.isNumber || $0 == ".") }
        }
    }

    private static let argumentValueOptions: Set<String> = [
        "-sdk", "-target", "-I", "-F", "-Fsystem", "-D", "-swift-version", "-package-name",
        "-enable-upcoming-feature", "-enable-experimental-feature", "-strict-concurrency",
        "-default-isolation", "-resource-dir", "-import-objc-header",
        "-load-plugin-executable", "-load-plugin-library", "-plugin-path", "-external-plugin-path",
        "-module-alias", "-cxx-interoperability-mode", "-enforce-exclusivity", "-clang-target", "-entry-point-function-name",
    ]

    private static func validate(arguments: [String]) throws {
        // Keep action, inputs, outputs, indexing and caches under the gate's
        // control. Unsupported settings fail rather than silently lose semantics.
        for argument in arguments {
            let isResponseFile = argument.hasPrefix("@")
            let hasInvalidByte = argument.contains("\0")
            let isOverlay = argument.hasPrefix("-vfsoverlay") || argument.hasPrefix("-ivfsoverlay")
            guard !isResponseFile, !hasInvalidByte, !isOverlay else {
                throw ToolFailure.invalid("Compiler response files, source overlays and NUL bytes are unsupported")
            }
        }
        let switches: Set<String> = [
            "-parse-as-library", "-enable-testing", "-enable-bare-slash-regex", "-enable-objc-interop",
            "-disable-objc-interop", "-enable-library-evolution", "-enable-actor-data-race-checks",
            "-application-extension", "-disable-availability-checking", "-warnings-as-errors", "-disable-sandbox",
            "-Onone", "-O", "-Osize", "-whole-module-optimization",
        ]
        var clangArguments: [String] = []
        var position = 0
        while position < arguments.count {
            let argument = arguments[position]
            if argument == "-Xcc" {
                guard position + 1 < arguments.count, !arguments[position + 1].isEmpty else {
                    throw ToolFailure.invalid("Missing compiler argument value for -Xcc")
                }
                clangArguments.append(arguments[position + 1])
                position += 2
                continue
            }
            if switches.contains(argument) {
                position += 1
                continue
            }
            if argumentValueOptions.contains(argument) {
                guard position + 1 < arguments.count, !arguments[position + 1].isEmpty,
                      !arguments[position + 1].contains("\0") else {
                    throw ToolFailure.invalid("Missing compiler argument value for \(argument)")
                }
                position += 2
                continue
            }
            let joinedPath = ["-I", "-F", "-D"].contains { argument.hasPrefix($0) && argument.count > $0.count }
            let equalsParts = argument.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let joinedValue = equalsParts.count == 2 && !equalsParts[1].isEmpty && argumentValueOptions.contains(String(equalsParts[0]))
            guard joinedPath || joinedValue else {
                throw ToolFailure.invalid("Unsupported compiler context argument: \(argument)")
            }
            position += 1
        }
        try validateClang(arguments: clangArguments)
    }

    private static func validateClang(arguments: [String]) throws {
        // Forwarded options share one Clang argument stream. Accept only known
        // semantic inputs; Clang output/cache/action flags must not escape the
        // private destinations supplied by CompilerWitnessGate.
        let valueOptions: Set<String> = [
            "-I", "-F", "-D", "-U", "-isystem", "-iquote", "-iframework", "-isysroot",
            "-target", "-include", "-imacros",
        ]
        let switches: Set<String> = [
            "-fPIC", "-fpic", "-g", "-fno-omit-frame-pointer", "-fblocks", "-fmodules", "-fno-modules",
            "-fobjc-arc", "-fno-objc-arc", "-fshort-wchar", "-funsigned-char", "-fsigned-char",
        ]
        let equalsOptions: Set<String> = ["-fmodule-map-file", "-fmodule-file", "-std", "-stdlib"]
        var position = 0
        while position < arguments.count {
            let argument = arguments[position]
            if switches.contains(argument) {
                position += 1
                continue
            }
            if valueOptions.contains(argument) {
                guard position + 1 < arguments.count, !arguments[position + 1].isEmpty,
                      !arguments[position + 1].hasPrefix("-") else {
                    throw ToolFailure.invalid("Missing Clang argument value for \(argument)")
                }
                position += 2
                continue
            }
            let joinedValue = ["-I", "-F", "-D", "-U"].contains { argument.hasPrefix($0) && argument.count > $0.count }
            let parts = argument.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let equalsValue = parts.count == 2 && !parts[1].isEmpty && equalsOptions.contains(String(parts[0]))
            guard joinedValue || equalsValue else {
                throw ToolFailure.invalid("Unsupported forwarded Clang context argument: \(argument)")
            }
            position += 1
        }
    }
}

extension CompilerContext: Decodable {}
extension CompilerContext.Module: Decodable {}
