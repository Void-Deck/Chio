import Foundation

struct CommandRequest {
    enum Action {
        case lint(LintAction)
        case reviewCandidates
        case analyzeWitnesses(profile: String, output: String)
    }
    enum LintAction {
        case check
        case baseline(output: String, reason: String)
    }
    let action: Action
    let root: String
    let isJSON: Bool
    let compilerContext: String?
    let compilerEvidence: [String]

    init(arguments: [String]) throws {
        guard let command = arguments.first, ["check", "baseline", "review-candidates", "analyze-witnesses"].contains(command) else {
            throw ToolFailure.invalid("Usage: swift-rules check [--root PATH] [--format json] [--compiler-context FILE | --compiler-evidence FILE ...] | baseline --output FILE --reason TEXT [--root PATH] [--compiler-context FILE | --compiler-evidence FILE ...] | review-candidates [--root PATH] [--format json] | analyze-witnesses --profile NAME --output FILE [--root PATH]")
        }
        var values: [String: String] = [:]
        var evidence: [String] = []
        var index = 1
        while index < arguments.count {
            let key = arguments[index]
            let hasValue = index + 1 < arguments.count
            let isKnownOption = ["--root", "--format", "--output", "--reason", "--compiler-context", "--compiler-evidence", "--profile"].contains(key)
            guard hasValue, isKnownOption, values[key] == nil else { throw ToolFailure.invalid("Invalid or duplicate option: \(key)") }
            let value = arguments[index + 1]
            if key == "--compiler-evidence" {
                guard !value.isEmpty else { throw ToolFailure.invalid("Compiler evidence needs a file path") }
                evidence.append(value)
            } else {
                values[key] = value
            }
            index += 2
        }
        root = values["--root"] ?? "."
        if let format = values["--format"], format != "json" { throw ToolFailure.invalid("Only --format json is supported") }
        isJSON = values["--format"] == "json"
        compilerContext = values["--compiler-context"]
        compilerEvidence = evidence
        guard compilerContext == nil || compilerEvidence.isEmpty else {
            throw ToolFailure.invalid("Compiler context and compiler evidence cannot be combined")
        }
        if command != "analyze-witnesses", values["--profile"] != nil {
            throw ToolFailure.invalid("--profile requires analyze-witnesses")
        }
        switch command {
        case "check":
            guard values["--output"] == nil, values["--reason"] == nil else { throw ToolFailure.invalid("Baseline options require the baseline command") }
            action = .lint(.check)
        case "baseline":
            guard let output = values["--output"], let reason = values["--reason"], !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ToolFailure.invalid("Baseline creation requires --output and a nonempty --reason")
            }
            action = .lint(.baseline(output: output, reason: reason))
        case "review-candidates":
            guard values["--output"] == nil, values["--reason"] == nil, compilerContext == nil, compilerEvidence.isEmpty else {
                throw ToolFailure.invalid("review-candidates accepts only --root and --format; run check separately for lint and compiler evidence")
            }
            action = .reviewCandidates
        case "analyze-witnesses":
            guard let profile = values["--profile"], !profile.isEmpty,
                  let output = values["--output"], !output.isEmpty,
                  values["--format"] == nil, values["--reason"] == nil,
                  compilerContext == nil, compilerEvidence.isEmpty else {
                throw ToolFailure.invalid("analyze-witnesses requires --profile and --output, and accepts only --root in addition")
            }
            action = .analyzeWitnesses(profile: profile, output: output)
        default: preconditionFailure("Command was validated above")
        }
    }
}
