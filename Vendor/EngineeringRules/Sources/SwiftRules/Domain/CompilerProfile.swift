import Foundation

struct CompilerProfile {
    enum Platform: String {
        case macos
        case linux
    }

    let name: String
    let platform: Platform
    let context: String

    func validated() throws -> Self {
        let hasSimpleName = !name.isEmpty && name.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_")
        }
        guard hasSimpleName else {
            throw ToolFailure.invalid("Compiler profile names require ASCII letters, numbers, hyphens or underscores")
        }
        guard RuleConfiguration.isRelativePath(context), !context.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw ToolFailure.invalid("Compiler profile context needs a normalized relative path: \(context)")
        }
        return self
    }
}

extension CompilerProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, platform, context
    }

    private struct Field: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: Field.self)
        let allowed = Set(["name", "platform", "context"])
        guard Set(fields.allKeys.map(\.stringValue)).isSubset(of: allowed) else {
            throw ToolFailure.invalid("Unknown compiler profile key")
        }
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self = try CompilerProfile(
            name: values.decode(String.self, forKey: .name),
            platform: values.decode(Platform.self, forKey: .platform),
            context: values.decode(String.self, forKey: .context)
        ).validated()
    }
}

extension CompilerProfile: Equatable {}
extension CompilerProfile.Platform: Codable {}
