@testable import DotMatrixStudy
import SwiftTUIRuntime
import Testing

@MainActor
struct DotMatrixRenderingTests {
    private let style = DotMatrixStyle(unlitColor: Color(hexRGB: 0x304050), shape: .round)

    @Test("Each LED retains its glyph and color without sharing a Braille cell")
    func directCells() throws {
        let frame = try DotMatrixFrame(rows: [[.on(.red), .on(.blue)], [.off, .on(.green)]])
        let result = DefaultRenderer().render(DotMatrix(frame: frame, style: style, label: "Signal"))
        #expect(result.rasterSurface.lines == ["● ●", "· ●"])
        let cells = result.rasterSurface.cells
        #expect(cells[0][0].style?.foregroundColor == .red)
        #expect(cells[0][2].style?.foregroundColor == .blue)
        #expect(cells[1][0].style?.foregroundColor == style.unlitColor)
        #expect(cells[1][2].style?.foregroundColor == .green)
        #expect(result.semanticSnapshot.accessibilityNodes.compactMap(\.label) == ["Signal"])
        #expect(result.semanticSnapshot.focusRegions.isEmpty)
    }

    @Test("Style changes alter glyphs without changing frame data or geometry")
    func shape() throws {
        let frame = try DotMatrixFrame(rows: [[.on(.red), .off]])
        let square = DotMatrixStyle(unlitColor: style.unlitColor, shape: .square)
        let result = DefaultRenderer().render(DotMatrix(frame: frame, style: square, label: "Signal"))
        #expect(result.rasterSurface.lines == ["■ ·"])
        #expect(frame.rows == [[.on(.red), .off]])
        #expect(result.rasterSurface.size == CellSize(width: 3, height: 1))
    }

    @Test("Exact fit keeps all dots; insufficient width or height uses authored text")
    func fitting() throws {
        let frame = try DotMatrixFrame(rows: [[.on(.red), .off], [.off, .on(.blue)]])
        let view = DotMatrix(frame: frame, style: style, label: "OK")
        let exact = DefaultRenderer().render(view, proposal: ProposedSize(width: 3, height: 2))
        #expect(exact.rasterSurface.lines == ["● ·", "· ●"])
        for size in [CellSize(width: 2, height: 2), CellSize(width: 3, height: 1),
                     CellSize(width: 0, height: 0), CellSize(width: 1, height: 1)] {
            let proposal = ProposedSize(width: size.width, height: size.height)
            let actual = DefaultRenderer().render(view, proposal: proposal)
            let expected = DefaultRenderer().render(Text("OK"), proposal: proposal)
            #expect(actual.rasterSurface == expected.rasterSurface)
        }
        let larger = DefaultRenderer().render(view, proposal: ProposedSize(width: 9, height: 6))
        let dots = larger.rasterSurface.cells.flatMap { $0 }.filter { "●·".contains($0.character) }
        #expect(dots.count == 4)
    }

    @Test("The fixture lettering has an independently expected dot mask")
    func lettering() throws {
        let frame = try MatrixLettering.frame("C", color: .green)
        let result = DefaultRenderer().render(DotMatrix(frame: frame, style: style, label: "C"))
        #expect(result.rasterSurface.lines == [
            "· ● ● ● ·", "● · · · ●", "● · · · ·", "● · · · ·",
            "● · · · ·", "● · · · ●", "· ● ● ● ·",
        ])
    }
}
