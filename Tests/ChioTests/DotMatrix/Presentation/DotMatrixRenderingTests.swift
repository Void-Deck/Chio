import Chio
import SwiftTUIRuntime
import Testing

@MainActor
struct DotMatrixRenderingTests {
    @Test("Independent RGB channels and intensity reach one native cell per LED")
    func directCells() throws {
        let frame = try DotMatrixFrame(rows: [[SIMD4(1, 0, 0, 1), SIMD4(0, 0, 1, 0.5)],
                                             [SIMD4(0.5, 1, 0.25, 0.5), SIMD4(1, 1, 1, 0)]])
        let style = try DotMatrixStyle(unlitColor: .cyan)
        let result = DefaultRenderer().render(DotMatrix(frame: frame, label: "Signal").dotMatrixStyle(style))
        #expect(result.rasterSurface.lines == ["● ●", "● ·"])
        let cells = result.rasterSurface.cells
        #expect(cells[0][0].style?.foregroundColor == Color(red: 1, green: 0, blue: 0))
        #expect(cells[0][2].style?.foregroundColor == Color(red: 0, green: 0, blue: 0.5))
        #expect(cells[1][0].style?.foregroundColor == Color(red: 0.25, green: 0.5, blue: 0.125))
        #expect(cells[1][2].style?.foregroundColor == .cyan)
        #expect(result.semanticSnapshot.accessibilityNodes.compactMap(\.label) == ["Signal"])
        #expect(result.semanticSnapshot.focusRegions.isEmpty)
        #expect(frame.rows[0][1] == SIMD4(0, 0, 1, 0.5))
    }

    @Test("Black RGB and zero intensity paint the inactive glyph with inherited muted color")
    func inactiveDots() throws {
        let frame = try DotMatrixFrame(rows: [[SIMD4(0, 0, 0, 1), SIMD4(1, 0.5, 0.25, 0)]])
        let theme = ChioStyle.default.replacing(colors: ChioStyle.default.colors.replacing(mutedText: .yellow))
        let surface = DefaultRenderer().render(DotMatrix(frame: frame, label: "Off").style(theme)).rasterSurface
        #expect(surface.lines == ["· ·"])
        #expect(surface.cells[0][0].style?.foregroundColor == .yellow)
        #expect(surface.cells[0][2].style?.foregroundColor == .yellow)
    }

    @Test("Gaps change pitch without adding an outer margin or altering frame data")
    func gapGeometry() throws {
        let frame = try DotMatrixFrame(rows: [[SIMD4(1, 0, 0, 1), SIMD4(0, 0, 0, 0)],
                                             [SIMD4(0, 0, 0, 0), SIMD4(0, 1, 0, 1)]])
        let wide = try DotMatrixStyle(shape: .square, horizontalGap: 2, verticalGap: 1)
        let surface = DefaultRenderer().render(DotMatrix(frame: frame, label: "Wide").dotMatrixStyle(wide)).rasterSurface
        #expect(surface.lines == ["■  ·", "", "·  ■"])
        #expect(surface.size == CellSize(width: 4, height: 3))
        #expect(surface.cells[1].allSatisfy { $0.character == " " })
        let packed = try DotMatrixStyle(horizontalGap: 0)
        let tight = DefaultRenderer().render(DotMatrix(frame: frame, label: "Packed").dotMatrixStyle(packed)).rasterSurface
        #expect(tight.lines == ["●·", "·●"])
        #expect(frame.height == 2)
        #expect(frame.columns == 2)
    }

    @Test("Nearest complete matrix style overrides while siblings inherit the ancestor")
    func inheritedStyle() throws {
        let frame = try DotMatrixFrame(rows: [[SIMD4(1, 0, 0, 1), SIMD4(0, 0, 0, 0)]])
        let root = try DotMatrixStyle(shape: .square, horizontalGap: 0, unlitColor: .cyan)
        let child = try DotMatrixStyle(horizontalGap: 2, unlitColor: .yellow)
        let result = DefaultRenderer().render(
            VStack(alignment: .leading, spacing: 0) {
                DotMatrix(frame: frame, label: "Root")
                DotMatrix(frame: frame, label: "Child").dotMatrixStyle(child)
                DotMatrix(frame: frame, label: "Sibling")
            }.dotMatrixStyle(root)
        )
        #expect(result.rasterSurface.lines == ["■·", "●  ·", "■·"])
        #expect(result.rasterSurface.size == CellSize(width: 4, height: 3))
        #expect(result.rasterSurface.cells[0][1].style?.foregroundColor == .cyan)
        #expect(result.rasterSurface.cells[1][3].style?.foregroundColor == .yellow)
        #expect(result.rasterSurface.cells[2][1].style?.foregroundColor == .cyan)
        var environment = EnvironmentValues()
        #expect(environment.dotMatrixStyle == (try DotMatrixStyle()))
        environment.dotMatrixStyle = child
        #expect(environment.dotMatrixStyle == child)
    }

    @Test("Complete fixed-pitch drawing fits exactly and authored text replaces any undersized matrix")
    func fittingAndFallback() throws {
        let frame = try DotMatrixFrame(rows: [[SIMD4(1, 0, 0, 1), SIMD4(0, 0, 0, 0)],
                                             [SIMD4(0, 0, 0, 0), SIMD4(0, 0, 1, 1)]])
        let view = DotMatrix(frame: frame, label: "OK")
        let exact = DefaultRenderer().render(view, proposal: ProposedSize(width: 3, height: 2))
        #expect(exact.rasterSurface.lines == ["● ·", "· ●"])
        for size in [CellSize(width: 2, height: 2), CellSize(width: 3, height: 1),
                     CellSize(width: 0, height: 0), CellSize(width: 1, height: 1)] {
            let proposal = ProposedSize(width: size.width, height: size.height)
            let actual = DefaultRenderer().render(view, proposal: proposal)
            let expected = DefaultRenderer().render(Text(verbatim: "OK"), proposal: proposal)
            #expect(actual.rasterSurface == expected.rasterSurface)
            #expect(actual.semanticSnapshot.focusRegions.isEmpty)
        }
        let fallback = DefaultRenderer().render(view, proposal: ProposedSize(width: 2, height: 1))
        #expect(fallback.semanticSnapshot.accessibilityNodes.compactMap(\.label) == ["OK"])
        let larger = DefaultRenderer().render(view, proposal: ProposedSize(width: 9, height: 6))
        let dots = larger.rasterSurface.cells.flatMap { $0 }.filter { "●·".contains($0.character) }
        #expect(dots.count == 4)
    }

    @Test("Total drawing area including gaps admits its bound and rejects larger canvases")
    func drawingAreaBound() throws {
        // 74 LEDs with six gaps occupy exactly 512 columns; 512 rows make 262,144 cells.
        let pixel = SIMD4<Float>(1, 0, 0, 1)
        let style = try DotMatrixStyle(horizontalGap: 6)
        let admitted = try DotMatrixFrame(rows: Array(repeating: Array(repeating: pixel, count: 74), count: 512))
        let result = DefaultRenderer().render(DotMatrix(frame: admitted, label: "Boundary").dotMatrixStyle(style))
        #expect(result.rasterSurface.size == CellSize(width: 512, height: 512))
        #expect(result.rasterSurface.cells[511][511].character == "●")
        let excessive = try DotMatrixFrame(rows: Array(repeating: Array(repeating: pixel, count: 75), count: 512))
        let fallback = DefaultRenderer().render(DotMatrix(frame: excessive, label: "Limit").dotMatrixStyle(style))
        #expect(fallback.rasterSurface.lines == ["Limit"])
        #expect(fallback.semanticSnapshot.accessibilityNodes.compactMap(\.label) == ["Limit"])
        let longest = try DotMatrixFrame(rows: [Array(repeating: pixel, count: 65_536)])
        let maximumGap = try DotMatrixStyle(horizontalGap: 8, verticalGap: 8)
        let bounded = DefaultRenderer().render(DotMatrix(frame: longest, label: "Large").dotMatrixStyle(maximumGap))
        #expect(bounded.rasterSurface.lines == ["Large"])
    }
}
