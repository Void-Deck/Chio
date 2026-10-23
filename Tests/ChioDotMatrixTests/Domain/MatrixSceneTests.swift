@testable import DotMatrixExample
import Chio
import Testing

struct MatrixSceneTests {
    @Test("Fixture lettering preserves independent expected pixels and rejects unsupported text")
    func lettering() throws {
        let green = SIMD4<Float>(0, 1, 0, 1)
        let frame = try MatrixLettering.frame("HI", color: green)
        #expect(frame.columns == 11)
        #expect(frame.height == 7)
        #expect(frame.matrix[0] == [green, .zero, .zero, .zero, green, .zero,
                                 green, green, green, green, green])
        #expect(throws: MatrixLettering.LetteringError.unsupportedCharacter("é")) {
            try MatrixLettering.frame("é", color: green)
        }
        for invalid in ["", String(repeating: "C", count: 11)] {
            #expect(throws: MatrixLettering.LetteringError.lengthOutOfBounds) {
                try MatrixLettering.frame(invalid, color: green)
            }
        }
    }

    @Test("App-owned intensity fixtures change intensity while preserving imagery and RGB")
    func intensity() throws {
        let scene = try MatrixScene()
        let original = scene.lettering(for: .amber, intensity: .full)
        let dim = scene.lettering(for: .amber, intensity: .dim)
        #expect(original.columns == 23)
        #expect(original.height == 7)
        #expect(original.matrix[0][1] == SIMD4<Float>(1, 188.0 / 255, 85.0 / 255, 1))
        #expect(dim.matrix[0][1] == SIMD4<Float>(1, 188.0 / 255, 85.0 / 255, 0.2))
        #expect(original.matrix[0][0] == .zero)
        #expect(dim.matrix[0][0] == .zero)
        #expect(scene.lettering(for: .amber, intensity: .full) == original)
        #expect(MatrixScene.Intensity.full.next.next.next == .full)
    }

    @Test("Four heart frames preserve shape, independent colors and the closed playback cycle")
    func iconFrames() throws {
        let scene = try MatrixScene()
        let frames = MatrixScene.Frame.allCases.map { scene.icon(at: $0, intensity: .full) }
        #expect(frames.allSatisfy { $0.columns == 8 && $0.height == 8 })
        #expect(frames[0] != frames[1])
        #expect(frames[1] != frames[2])
        #expect(MatrixScene.Frame.allCases.map(\.next) == [.second, .third, .fourth, .first])
        #expect(frames[0].matrix[0] == Array(repeating: SIMD4<Float>.zero, count: 8))
        #expect(frames[2].matrix[0][1] == SIMD4<Float>(1, 212.0 / 255, 155.0 / 255, 1))
        #expect(frames[2].matrix[3][5] == SIMD4<Float>(1, 111.0 / 255, 145.0 / 255, 1))
        #expect(scene.icon(at: .third, intensity: .half).matrix[3][5].w == 0.5)
    }

    @Test("Gap choices remain an app policy and preserve their ordered cycle")
    func gaps() throws {
        let scene = try MatrixScene()
        #expect(MatrixGaps.allCases.map(\.horizontal) == [0, 1, 3])
        #expect(MatrixGaps.allCases.map(\.vertical) == [0, 0, 1])
        #expect(MatrixGaps.regular.next.next.next == .regular)
        let style = scene.style(shape: .square, gaps: .open)
        #expect(style.shape == .square)
        #expect(style.horizontalGap == 3)
        #expect(style.verticalGap == 1)
        #expect(style.unlitColor == nil)
    }

    @Test("The viewport fixture has distinct RGB corners and exceeds the example viewport")
    func gradient() throws {
        let gradient = try MatrixScene().gradient
        #expect(gradient.columns == 64)
        #expect(gradient.height == 40)
        #expect(gradient.matrix[0][0] == SIMD4<Float>(0, 0, 1, 1))
        #expect(gradient.matrix[0][63] == SIMD4<Float>(1, 0, 0, 1))
        #expect(gradient.matrix[39][0] == SIMD4<Float>(0, 1, 1, 1))
        #expect(gradient.matrix[39][63] == SIMD4<Float>(1, 1, 0, 1))
    }
}
