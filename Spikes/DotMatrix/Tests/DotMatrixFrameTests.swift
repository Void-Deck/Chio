@testable import DotMatrixStudy
import Foundation
import SwiftTUIRuntime
import Testing

struct DotMatrixFrameTests {
    @Test("A frame has a fixed bounded rectangle, including all-off frames")
    func dimensions() throws {
        let frame = try DotMatrixFrame(rows: [[.off, .on(.red)], [.on(.blue), .off]])
        #expect(frame.columns == 2)
        #expect(frame.height == 2)
        #expect(frame.cellWidth == 3)
        #expect(try DotMatrixFrame(rows: [[.off]]).cellWidth == 1)
        let largest = try DotMatrixFrame(rows: Array(repeating: Array(repeating: .off, count: 64), count: 32))
        #expect(largest.cellWidth == 127)
        #expect(largest.height == 32)
        #expect(throws: DotMatrixFrame.ValidationError.heightOutOfBounds) {
            try DotMatrixFrame(rows: [])
        }
        #expect(throws: DotMatrixFrame.ValidationError.heightOutOfBounds) {
            try DotMatrixFrame(rows: Array(repeating: [.off], count: 33))
        }
        #expect(throws: DotMatrixFrame.ValidationError.widthOutOfBounds) {
            try DotMatrixFrame(rows: [[]])
        }
        #expect(throws: DotMatrixFrame.ValidationError.widthOutOfBounds) {
            try DotMatrixFrame(rows: [Array(repeating: .off, count: 65)])
        }
        #expect(throws: DotMatrixFrame.ValidationError.unevenRows) {
            try DotMatrixFrame(rows: [[.off], [.off, .off]])
        }
    }

    @Test("Decoding enforces geometry while retaining supplied colors")
    func coding() throws {
        let original = try DotMatrixFrame(rows: [[.on(.red), .off], [.off, .on(.blue)]])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DotMatrixFrame.self, from: data)
        #expect(decoded == original)
        #expect(Set([original, decoded]).count == 1)
        for rows: [[DotMatrixFrame.Dot]] in [[], [[]], [[.off], [.off, .off]],
                                           [Array(repeating: .off, count: 65)],
                                           Array(repeating: [.off], count: 33)] {
            let malformed = try JSONEncoder().encode(["rows": rows])
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(DotMatrixFrame.self, from: malformed)
            }
        }
    }

    @Test("Lettering is a pure producer of the same frame type used by icons")
    func lettering() throws {
        let frame = try MatrixLettering.frame("HI", color: .green)
        #expect(frame.columns == 11)
        #expect(frame.height == 7)
        #expect(frame.rows[0] == [.on(.green), .off, .off, .off, .on(.green), .off,
                                 .on(.green), .on(.green), .on(.green), .on(.green), .on(.green)])
        #expect(try MatrixLettering.frame("HI", color: .green) == frame)
        #expect(throws: MatrixLettering.LetteringError.unsupportedCharacter("é")) {
            try MatrixLettering.frame("é", color: .green)
        }
        #expect(throws: MatrixLettering.LetteringError.lengthOutOfBounds) {
            try MatrixLettering.frame(String(repeating: "C", count: 11), color: .green)
        }
        #expect(throws: MatrixLettering.LetteringError.lengthOutOfBounds) {
            try MatrixLettering.frame("", color: .green)
        }
    }

    @Test("Animation frames preserve dimensions and a closed four-frame cycle")
    func iconFrames() throws {
        let scene = try MatrixScene()
        let frames = MatrixScene.Frame.allCases.map { scene.icon(at: $0) }
        #expect(frames.allSatisfy { $0.columns == 8 && $0.height == 8 })
        #expect(frames[0] != frames[1])
        #expect(frames[1] != frames[2])
        #expect(MatrixScene.Frame.allCases.map(\.next) == [.second, .third, .fourth, .first])
        #expect(MatrixScene.Frame.first.next.next.next.next == .first)
        #expect(frames[0].rows[0] == Array(repeating: .off, count: 8))
        #expect(frames[2].rows[0][1] == .on(Color(hexRGB: 0xFFD49B)))
    }
}
