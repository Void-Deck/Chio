import Foundation

/// Checked display credit shared by independently attributed map services.
public struct MapAttribution {
    public let text: String
    public let link: URL

    public init(text: String, link: URL) throws(ValidationError) {
        let hasVisibleText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isWithinTextLimit = text.utf8.count <= 1_024
        let hasNoControls = !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        guard hasVisibleText, isWithinTextLimit, hasNoControls else { throw .invalidText }
        let hasSupportedScheme = ["http", "https"].contains(link.scheme?.lowercased() ?? "")
        let hasHost = !(link.host ?? "").isEmpty
        let hasNoCredentials = link.user == nil && link.password == nil
        let isWithinURLLimit = link.absoluteString.utf8.count <= 2_048
        let isAbsolute = link.baseURL == nil
        guard hasSupportedScheme, hasHost, hasNoCredentials, isWithinURLLimit, isAbsolute
        else { throw .invalidLink }
        self.text = text
        self.link = link
    }

    public enum ValidationError { case invalidText, invalidLink }
}

extension MapAttribution: Codable {
    private enum CodingKeys: String, CodingKey { case text, link }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(text: values.decode(String.self, forKey: .text),
                      link: values.decode(URL.self, forKey: .link))
    }
}

extension MapAttribution: Hashable {}
extension MapAttribution: Sendable {}
extension MapAttribution.ValidationError: Equatable {}
extension MapAttribution.ValidationError: Error {}
extension MapAttribution.ValidationError: Sendable {}
