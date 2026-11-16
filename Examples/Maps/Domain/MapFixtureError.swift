import Foundation

enum MapFixtureError: Error {
    case invalidFixtureURL

    static func url(_ literal: String) throws -> URL {
        guard let url = URL(string: literal) else { throw Self.invalidFixtureURL }
        return url
    }
}
