import Chio
import Foundation
import Testing

struct DotMatrixFrameTests {
    @Test("Frame dimensions follow the supplied matrix beyond the former dot limit")
    func dimensions() throws {
        let pixel = SIMD4<Float>(1, 0.5, 0.25, 0.75)
        let matrix = Array(repeating: Array(repeating: pixel, count: 257), count: 256)
        let frame = try DotMatrixFrame(matrix: matrix)
        #expect(frame.matrix == matrix)
        #expect(frame.columns == 257)
        #expect(frame.height == 256)
        let wide = try DotMatrixFrame(matrix: [Array(repeating: pixel, count: 65_537)])
        #expect(wide.columns == 65_537)
        let tall = try DotMatrixFrame(matrix: Array(repeating: [pixel], count: 65_537))
        #expect(tall.height == 65_537)
    }

    @Test("Empty and ragged images are rejected at construction")
    func invalidDimensions() {
        let pixel = SIMD4<Float>(repeating: 1)
        #expect(throws: DotMatrixFrame.ValidationError.emptyRows) {
            try DotMatrixFrame(matrix: [])
        }
        #expect(throws: DotMatrixFrame.ValidationError.emptyColumns) {
            try DotMatrixFrame(matrix: [[]])
        }
        #expect(throws: DotMatrixFrame.ValidationError.unevenRows(rowIndex: 1)) {
            try DotMatrixFrame(matrix: [[pixel], []])
        }
        #expect(throws: DotMatrixFrame.ValidationError.unevenRows(rowIndex: 1)) {
            try DotMatrixFrame(matrix: [[pixel], [pixel, pixel]])
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
                    try DotMatrixFrame(matrix: [[SIMD4<Float>(repeating: 0), pixel]])
                }
            }
        }
    }

    @Test("Coding preserves channels, hashing and value semantics")
    func codingAndValues() throws {
        let matrix = [[SIMD4<Float>(0, 1, 0.25, 0), SIMD4<Float>(1, 0, 0.5, 1)]]
        let frame = try DotMatrixFrame(matrix: matrix)
        let encoded = try JSONEncoder().encode(frame)
        let payload = try JSONDecoder().decode([String: [[SIMD4<Float>]]].self, from: encoded)
        #expect(payload == ["rows": matrix])
        let decoded = try JSONDecoder().decode(DotMatrixFrame.self, from: encoded)
        #expect(decoded == frame)
        #expect(Set([frame, decoded]).count == 1)
        #expect(decoded.matrix == matrix)
        let replacement = try DotMatrixFrame(matrix: [[SIMD4<Float>(repeating: 1)]])
        #expect(replacement != frame)
        #expect(frame.matrix == matrix)
        func requiresSendable<Value: Sendable>(_: Value) {}
        requiresSendable(frame)
    }

    @Test("Decoding admits a matrix above the former dot limit with the existing coding key")
    func largeMatrixDecoding() throws {
        let pixel = SIMD4<Float>(0.25, 0.5, 1, 0.75)
        let matrix = Array(repeating: Array(repeating: pixel, count: 257), count: 256)
        let encoded = try JSONEncoder().encode(["rows": matrix])
        let frame = try JSONDecoder().decode(DotMatrixFrame.self, from: encoded)
        #expect(frame.columns == 257)
        #expect(frame.height == 256)
        #expect(frame.matrix == matrix)
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
        var malformed: [[[SIMD4<Float>]]] = [[], [[]], [[pixel], []]]
        for channelIndex in 0..<4 {
            for invalid in [Float(-0.001), 1.001, .nan, .infinity, -.infinity] {
                var dot = pixel
                dot[channelIndex] = invalid
                malformed.append([[dot]])
            }
        }
        for matrix in malformed {
            let encoded = try encoder.encode(["rows": matrix])
            #expect(throws: DecodingError.self) {
                try decoder.decode(DotMatrixFrame.self, from: encoded)
            }
        }
    }
}
