import Chio
import Foundation
import Testing

struct DotMatrixFrameTests {
    @Test("Public frame dimensions and maximum admit larger images than the study")
    func dimensionsAndBounds() throws {
        let pixel = SIMD4<Float>(1, 0.5, 0.25, 0.75)
        let rows = Array(repeating: Array(repeating: pixel, count: 65), count: 33)
        let frame = try DotMatrixFrame(rows: rows)
        #expect(frame.rows == rows)
        #expect(frame.columns == 65)
        #expect(frame.height == 33)
        #expect(DotMatrixFrame.maximumDotCount == 65_536)
        let maximum = try DotMatrixFrame(rows: [Array(repeating: pixel, count: 65_536)])
        #expect(maximum.columns == 65_536)
        let tall = try DotMatrixFrame(rows: Array(repeating: [pixel], count: 65_536))
        #expect(tall.height == 65_536)
    }

    @Test("Empty, ragged and excessive images are rejected at construction")
    func invalidDimensions() {
        let pixel = SIMD4<Float>(repeating: 1)
        #expect(throws: DotMatrixFrame.ValidationError.emptyRows) {
            try DotMatrixFrame(rows: [])
        }
        #expect(throws: DotMatrixFrame.ValidationError.emptyColumns) {
            try DotMatrixFrame(rows: [[]])
        }
        #expect(throws: DotMatrixFrame.ValidationError.unevenRows(rowIndex: 1)) {
            try DotMatrixFrame(rows: [[pixel], []])
        }
        #expect(throws: DotMatrixFrame.ValidationError.unevenRows(rowIndex: 1)) {
            try DotMatrixFrame(rows: [[pixel], [pixel, pixel]])
        }
        #expect(throws: DotMatrixFrame.ValidationError.dotLimitExceeded(limit: 65_536)) {
            try DotMatrixFrame(rows: [Array(repeating: pixel, count: 65_537)])
        }
        #expect(throws: DotMatrixFrame.ValidationError.dotLimitExceeded(limit: 65_536)) {
            try DotMatrixFrame(rows: Array(repeating: [pixel], count: 65_537))
        }
    }

    @Test("Every RGB and intensity channel rejects nonfinite and out-of-range input")
    func invalidChannels() {
        for channelIndex in 0..<4 {
            for invalid in [Float(-0.001), 1.001, .nan, .infinity, -.infinity] {
                var pixel = SIMD4<Float>(repeating: 0.5)
                pixel[channelIndex] = invalid
                #expect(throws: DotMatrixFrame.ValidationError.channelOutOfRange(
                    rowIndex: 0, columnIndex: 1, channelIndex: channelIndex
                )) {
                    try DotMatrixFrame(rows: [[SIMD4<Float>(repeating: 0), pixel]])
                }
            }
        }
    }

    @Test("Coding preserves channels, hashing and value semantics")
    func codingAndValues() throws {
        let rows = [[SIMD4<Float>(0, 1, 0.25, 0), SIMD4<Float>(1, 0, 0.5, 1)]]
        let frame = try DotMatrixFrame(rows: rows)
        let encoded = try JSONEncoder().encode(frame)
        let decoded = try JSONDecoder().decode(DotMatrixFrame.self, from: encoded)
        #expect(decoded == frame)
        #expect(Set([frame, decoded]).count == 1)
        #expect(decoded.rows == rows)
        let replacement = try DotMatrixFrame(rows: [[SIMD4<Float>(repeating: 1)]])
        #expect(replacement != frame)
        #expect(frame.rows == rows)
        func requiresSendable<Value: Sendable>(_: Value) {}
        requiresSendable(frame)
    }

    @Test("Decoding rejects invalid dimensions and all invalid channels through checked construction")
    func invalidDecoding() throws {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "infinity", negativeInfinity: "-infinity", nan: "nan"
        )
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "infinity", negativeInfinity: "-infinity", nan: "nan"
        )
        let pixel = SIMD4<Float>(repeating: 1)
        var malformed: [[[SIMD4<Float>]]] = [[], [[]], [[pixel], []],
                                            [Array(repeating: pixel, count: 65_537)]]
        for channelIndex in 0..<4 {
            for invalid in [Float(-0.001), 1.001, .nan, .infinity, -.infinity] {
                var dot = pixel
                dot[channelIndex] = invalid
                malformed.append([[dot]])
            }
        }
        for rows in malformed {
            let encoded = try encoder.encode(["rows": rows])
            #expect(throws: DecodingError.self) {
                try decoder.decode(DotMatrixFrame.self, from: encoded)
            }
        }
    }
}
