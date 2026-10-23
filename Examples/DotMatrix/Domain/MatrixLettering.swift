import Chio

/// A deliberately small fixture font, not a public typography or localization API.
enum MatrixLettering {
    enum LetteringError {
        case lengthOutOfBounds
        case unsupportedCharacter(Character)
    }

    static func frame(_ text: String, color: SIMD4<Float>) throws -> DotMatrixFrame {
        let characters = Array(text.prefix(11))
        guard (1...10).contains(characters.count) else { throw LetteringError.lengthOutOfBounds }
        let glyphs = try characters.map { character in
            guard let rows = font[character] else { throw LetteringError.unsupportedCharacter(character) }
            return rows
        }
        return try DotMatrixFrame(rows: (0..<7).map { row in
            glyphs.enumerated().flatMap { index, glyph -> [SIMD4<Float>] in
                let gap: [SIMD4<Float>] = index == 0 ? [] : [SIMD4<Float>.zero]
                return gap + glyph[row].map { $0 == "#" ? color : SIMD4<Float>.zero }
            }
        })
    }

    private static let font: [Character: [String]] = [
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "#....", "####.", "....#", "....#", "####."],
        "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
        ":": [".", "#", "#", ".", "#", "#", "."],
    ]
}

extension MatrixLettering.LetteringError: Equatable {}
extension MatrixLettering.LetteringError: Error {}
