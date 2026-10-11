import Chio
import SwiftTUIRuntime
import Testing

@MainActor
struct MeasurementGaugeTests {
    private func render(_ position: Double?, style: MeasurementGauge.Style = .bar,
                        width: Int = 20, height: Int = 5) -> RenderSnapshot {
        DefaultRenderer().render(MeasurementGauge(position: position, style: style),
                                 proposal: ProposedSize(width: width, height: height))
    }

    private func render(_ position: Double?, targetBand: MeasurementGauge.TargetBand?,
                        style: MeasurementGauge.Style = .bar,
                        width: Int = 20, height: Int = 5) -> RenderSnapshot {
        DefaultRenderer().render(MeasurementGauge(position: position, targetBand: targetBand, style: style),
                                 proposal: ProposedSize(width: width, height: height))
    }

    private func render(_ position: Double?, referenceMarks: MeasurementGauge.ReferenceMarks,
                        targetBand: MeasurementGauge.TargetBand? = nil,
                        style: MeasurementGauge.Style = .bar,
                        width: Int = 20, height: Int = 12) -> RenderSnapshot {
        DefaultRenderer().render(
            MeasurementGauge(position: position, referenceMarks: referenceMarks, targetBand: targetBand, style: style),
            proposal: ProposedSize(width: width, height: height))
    }

    private func glyphs(_ frame: RenderSnapshot) -> String {
        String(frame.rasterSurface.cells.flatMap { $0 }.map(\.character).filter { $0 != " " })
    }

    private func characters(_ frame: RenderSnapshot) -> [[Character]] {
        frame.rasterSurface.cells.map { $0.map(\.character) }
    }

    // Inspect the public braille raster rather than the drawing's geometry helpers.
    private func pixels(_ frame: RenderSnapshot) -> Set<CellPoint> {
        let dots = [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (0, 3), (1, 3)]
        var result: Set<CellPoint> = []
        for (y, row) in frame.rasterSurface.lines.enumerated() {
            for (x, character) in row.enumerated() {
                guard let scalar = character.unicodeScalars.first,
                      (0x2800...0x28FF).contains(scalar.value) else { continue }
                let mask = scalar.value - 0x2800
                for (bit, dot) in dots.enumerated() where mask & (1 << bit) != 0 {
                    result.insert(CellPoint(x: x * 2 + dot.0, y: y * 4 + dot.1))
                }
            }
        }
        return result
    }

    @Test("The segmented bar distinguishes zero, midpoint, upper endpoint and missing readings")
    func barPositions() {
        #expect(glyphs(render(0, width: 10)) == "▱▱▱▱▱▱▱▱▱▱")
        #expect(glyphs(render(0.5, width: 10)) == "▰▰▰▰▰▱▱▱▱▱")
        #expect(glyphs(render(1, width: 10)) == "▰▰▰▰▰▰▰▰▰▰")
        #expect(glyphs(render(nil, width: 10)) == "··········")
    }

    @Test("The missing dial preserves its arc; known positions add the correctly directed needle")
    func dialPositions() {
        let arc = pixels(render(nil, style: .dial))
        #expect(!arc.isEmpty)
        // A twenty-column, five-row semicircle reaches both ends and the top.
        #expect(arc.contains { $0.x == 0 && $0.y == 19 })
        #expect(arc.contains { $0.x == 39 && $0.y == 19 })
        #expect(arc.contains { $0.y == 0 })
        let needleSamples = [CellPoint(x: 10, y: 19), CellPoint(x: 20, y: 10), CellPoint(x: 30, y: 19)]
        for (position, sample) in zip([0.0, 0.5, 1.0], needleSamples) {
            let indicated = pixels(render(position, style: .dial))
            #expect(arc.isSubset(of: indicated))
            #expect(!arc.contains(sample))
            #expect(indicated.contains(sample))
            #expect(indicated.count > arc.count)
        }
    }

    @Test("Native proposals determine bar width, with a bounded drawing and useful ideal sizes")
    func allocation() {
        for width in [1, 3, 9, 27, 512] {
            let frame = render(0.5, width: width)
            let filled = Int((Double(width) / 2).rounded())
            let expected = String(repeating: "▰", count: filled)
                + String(repeating: "▱", count: width - filled)
            #expect(glyphs(frame) == expected)
        }
        #expect(glyphs(render(0.5, width: 700)).count == 512)
        let idealBar = DefaultRenderer().render(MeasurementGauge(position: 0))
        let idealDial = DefaultRenderer().render(MeasurementGauge(position: nil, style: .dial))
        #expect(idealBar.rasterSurface.size == CellSize(width: 20, height: 1))
        #expect(idealDial.rasterSurface.size == CellSize(width: 20, height: 5))
    }

    @Test("Wide and tall allocations center a complete dial without stretching its braille geometry")
    func dialAspectAndCentering() {
        let original = pixels(render(0.5, style: .dial))
        for width in [20, 32, 64, 512] {
            for height in [1, 4, 5, 12] {
                let frame = render(0.5, style: .dial, width: width, height: height)
                let offset = (width - 20) / 2 * 2
                let expected = Set(original.map { CellPoint(x: $0.x + offset, y: $0.y) })
                #expect(pixels(frame) == expected)
                #expect(frame.rasterSurface.size == CellSize(width: width, height: max(5, height)))
            }
        }
        #expect(pixels(render(0.5, style: .dial, width: 19, height: 4)) == original)
        #expect(render(0.5, style: .dial, width: 19, height: 4).rasterSurface.size
            == CellSize(width: 20, height: 5))
    }

    @Test("Passive native fitting rejects incomplete dial dimensions and preserves the application-selected style")
    func nativeStyleFittingAndRecovery() {
        let renderer = DefaultRenderer()
        let presentation = ViewThatFits {
            MeasurementGauge(position: 0.5, style: .dial)
            MeasurementGauge(position: 0.5, style: .bar)
            Text("Numeric")
        }
        let wide = ProposedSize(width: 20, height: 5)
        let first = renderer.render(presentation, proposal: wide)
        #expect(!pixels(first).isEmpty)
        let short = renderer.render(presentation, proposal: ProposedSize(width: 20, height: 4))
        #expect(pixels(short).isEmpty)
        #expect(glyphs(short).contains("▰"))
        let narrow = renderer.render(presentation, proposal: ProposedSize(width: 19, height: 5))
        #expect(glyphs(narrow) == "Numeric")
        #expect(renderer.render(presentation, proposal: wide).rasterSurface == first.rasterSurface)
        let selectedBar = DefaultRenderer().render(
            MeasurementGauge(position: 0.5, style: .bar), proposal: wide)
        #expect(pixels(selectedBar).isEmpty)
        #expect(glyphs(selectedBar).contains("▰"))
    }

    @Test("Whole annotated measurements fit only when every plot track and caption fits")
    func annotatedFitting() throws {
        let target = try MeasurementGauge.TargetBand(lowerBound: 0, upperBound: 1)
        let references = try MeasurementGauge.ReferenceMarks([
            MeasurementGauge.ReferenceMark(id: "first", label: "First", position: 0),
            MeasurementGauge.ReferenceMark(id: "second", label: "Second", position: 1),
        ])
        let presentation = ViewThatFits {
            MeasurementGauge(position: nil, referenceMarks: references, targetBand: target, style: .dial)
            MeasurementGauge(position: nil, referenceMarks: references, targetBand: target, style: .bar)
            Text("Numeric")
        }
        let renderer = DefaultRenderer()
        let complete = renderer.render(presentation, proposal: ProposedSize(width: 20, height: 7))
        #expect(!pixels(complete).isEmpty)
        #expect(complete.rasterSurface.lines.contains { $0.contains("1 First") })
        #expect(complete.rasterSurface.lines.contains { $0.contains("2 Second") })
        let bar = renderer.render(presentation, proposal: ProposedSize(width: 20, height: 5))
        #expect(bar.rasterSurface.lines == ["····················", "╞══════════════════╡",
            "1                  2", "1 First", "2 Second"])
        let short = renderer.render(presentation, proposal: ProposedSize(width: 20, height: 4))
        #expect(glyphs(short) == "Numeric")
        #expect(renderer.render(presentation, proposal: ProposedSize(width: 20, height: 7)).rasterSurface
            == complete.rasterSurface)
    }

    @Test("Wrapped references use available width and retain units despite inherited line limits")
    func wrappedReferenceFitting() throws {
        let references = try MeasurementGauge.ReferenceMarks([
            MeasurementGauge.ReferenceMark(id: "first", label: "First recorded value 20 °C", position: 0),
            MeasurementGauge.ReferenceMark(id: "second", label: "Second recorded value 40 °C", position: 1),
        ])
        for style in [MeasurementGauge.Style.bar, .dial] {
            let plotRows = style == .bar ? 2 : 5
            let presentation = ViewThatFits(in: .vertical) {
                MeasurementGauge(position: nil, referenceMarks: references, style: style)
                Text("Numeric")
            }
            .lineLimit(1)
            let wrapped = DefaultRenderer().render(presentation,
                proposal: ProposedSize(width: 20, height: plotRows + 4))
            #expect(wrapped.rasterSurface.lines.contains { $0.contains("value 20 °C") })
            #expect(wrapped.rasterSurface.lines.contains { $0.contains("value 40 °C") })
            let short = DefaultRenderer().render(presentation,
                proposal: ProposedSize(width: 20, height: plotRows + 3))
            #expect(glyphs(short) == "Numeric")
            let wide = DefaultRenderer().render(presentation,
                proposal: ProposedSize(width: 40, height: plotRows + 2))
            #expect(wide.rasterSurface.lines.contains { $0.contains("1 First recorded value 20 °C") })
            #expect(wide.rasterSurface.lines.contains { $0.contains("2 Second recorded value 40 °C") })
            if style == .dial {
                #expect(wide.rasterSurface.cells[4][10].character == "1")
                #expect(wide.rasterSurface.cells[4][29].character == "2")
            }
        }
    }

    @Test("Native minimums retain complete plots while forced frames use native clipping")
    func narrowFrames() {
        for style in [MeasurementGauge.Style.bar, .dial] {
            let plotHeight = style == .bar ? 1 : 5
            let minimumWidth = style == .bar ? 1 : 20
            let minimum = render(0, style: style, width: 0, height: 0)
            #expect(minimum.rasterSurface.size == CellSize(width: minimumWidth, height: plotHeight))
            #expect(!glyphs(minimum).isEmpty)
            for width in [0, 1, 2, 3] {
                let frame = DefaultRenderer().render(
                    MeasurementGauge(position: 0, style: style)
                        .frame(width: width, height: 1, alignment: .topLeading).clipped(),
                    proposal: ProposedSize(width: width, height: 1))
                if width == 0 {
                    #expect(frame.rasterSurface.size == .zero)
                    #expect(glyphs(frame).isEmpty)
                } else {
                    #expect(frame.rasterSurface.size == CellSize(width: width, height: 1))
                    #expect(frame.rasterSurface.cells.count == 1)
                    #expect(frame.rasterSurface.cells.allSatisfy { $0.count == width })
                    if style == .bar { #expect(glyphs(frame) == String(repeating: "▱", count: width)) }
                }
            }
        }
    }

    @Test("Every reading uses the environment accent without implying completion or adding focus")
    func themeAndSemantics() {
        for theme in [ChioTheme.default, .light, .btop] {
            for style in [MeasurementGauge.Style.bar, .dial] {
                for position in [0, 0.5, 1, nil] as [Double?] {
                    let frame = DefaultRenderer().render(
                        MeasurementGauge(position: position, style: style).chioTheme(theme),
                        proposal: ProposedSize(width: 20, height: 5))
                    let painted = frame.rasterSurface.cells.flatMap { $0 }.filter { $0.character != " " }
                    #expect(!painted.isEmpty)
                    #expect(painted.allSatisfy { $0.style?.foregroundColor == theme.colors.accent })
                    #expect(frame.semanticSnapshot.focusRegions.isEmpty)
                    #expect(!frame.semanticSnapshot.accessibilityNodes.contains { $0.role == .progressBar })
                    let expected: String
                    if let position { expected = "Measurement position: \(position) of 1." }
                    else { expected = "Measurement: missing reading." }
                    #expect(frame.semanticSnapshot.accessibilityNodes.contains {
                        $0.role == .image && $0.label == expected
                    })
                }
            }
        }
    }

    @Test("Callers can replace the default measurement label with scale and units")
    func accessibilityOverride() {
        for style in [MeasurementGauge.Style.bar, .dial] {
            let frame = DefaultRenderer().render(
                MeasurementGauge(position: 0.5, style: style)
                    .accessibilityLabel("Temperature: 18 degrees Celsius")
                    .frame(width: 20, height: 5),
                proposal: ProposedSize(width: 20, height: 5))
            let labels = frame.semanticSnapshot.accessibilityNodes.compactMap(\.label)
            #expect(labels.contains("Temperature: 18 degrees Celsius"))
            #expect(!labels.contains("Measurement position: 0.5 of 1."))
            #expect(frame.semanticSnapshot.focusRegions.isEmpty)
        }
    }

    @Test("Construction rejects nonfinite and out-of-scale positions")
    func invalidInput() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = MeasurementGauge(position: .nan) }
        }
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = MeasurementGauge(position: .infinity) }
        }
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = MeasurementGauge(position: -.infinity, style: .dial) }
        }
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = MeasurementGauge(position: -Double.leastNonzeroMagnitude) }
        }
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = MeasurementGauge(position: Double(1).nextUp, style: .dial) }
        }
    }

    @Test("The existing initializer reference and explicit absent target preserve all no-band contracts")
    func noBandCompatibility() {
        let initializer: (Double?, MeasurementGauge.Style) -> MeasurementGauge = MeasurementGauge.init(position:style:)
        for style in [MeasurementGauge.Style.bar, .dial] {
            for position in [0, 0.5, 1, nil] as [Double?] {
                for width in [0, 1, 2, 3, 20, 512, 700] {
                    for height in [0, 1, 3, 5] {
                        let old = DefaultRenderer().render(initializer(position, style),
                            proposal: ProposedSize(width: width, height: height))
                        let explicit = render(position, targetBand: nil, style: style, width: width, height: height)
                        #expect(old.rasterSurface == explicit.rasterSurface)
                        #expect(old.semanticSnapshot.accessibilityNodes.map(\.label)
                            == explicit.semanticSnapshot.accessibilityNodes.map(\.label))
                        #expect(explicit.semanticSnapshot.focusRegions.isEmpty)
                    }
                }
            }
        }
    }

    @Test("The target bar is a separate bracket track independent of the reading")
    func barTargets() throws {
        let bands = try [
            MeasurementGauge.TargetBand(lowerBound: 0, upperBound: 1),
            MeasurementGauge.TargetBand(lowerBound: 0.2, upperBound: 0.6),
            MeasurementGauge.TargetBand(lowerBound: 0, upperBound: 0.1),
            MeasurementGauge.TargetBand(lowerBound: 0.9, upperBound: 1),
            MeasurementGauge.TargetBand(lowerBound: 0.5, upperBound: Double(0.5).nextUp),
        ]
        let expected = ["╞════════╡", "  ╞══╡    ", "╞╡        ", "        ╞╡", "     ╪    "]
        for (band, track) in zip(bands, expected) {
            for position in [0, 0.5, 1, nil] as [Double?] {
                let frame = render(position, targetBand: band, width: 10)
                #expect(frame.rasterSurface.size == CellSize(width: 10, height: 5))
                #expect(frame.rasterSurface.lines[0] == render(position, width: 10).rasterSurface.lines[0])
                #expect(String(frame.rasterSurface.cells[1].map(\.character)) == track)
                #expect(frame.rasterSurface.cells.dropFirst(2).flatMap { $0 }.allSatisfy { $0.character == " " })
            }
        }
        let ideal = DefaultRenderer().render(MeasurementGauge(position: nil, targetBand: bands[0]))
        #expect(ideal.rasterSurface.size == CellSize(width: 20, height: 2))
    }

    @Test("Dial targets add a distinct inner arc and radial endpoint marks in the five-row budget")
    func dialTargets() throws {
        let bands = try [
            MeasurementGauge.TargetBand(lowerBound: 0, upperBound: 1),
            MeasurementGauge.TargetBand(lowerBound: 0.25, upperBound: 0.75),
            MeasurementGauge.TargetBand(lowerBound: 0, upperBound: 0.1),
            MeasurementGauge.TargetBand(lowerBound: 0.9, upperBound: 1),
            MeasurementGauge.TargetBand(lowerBound: 0.5, upperBound: Double(0.5).nextUp),
        ]
        for band in bands {
            for position in [0, band.range.lowerBound, band.range.upperBound, 1, nil] as [Double?] {
                let ordinary = pixels(render(position, style: .dial))
                let frame = render(position, targetBand: band, style: .dial)
                let targeted = pixels(frame)
                #expect(frame.rasterSurface.size == CellSize(width: 20, height: 5))
                #expect(ordinary.isSubset(of: targeted))
                #expect(targeted.count > ordinary.count)
            }
        }
        let full = pixels(render(nil, targetBand: bands[0], style: .dial))
        #expect(full.contains(CellPoint(x: 20, y: 7))) // inner arc top
        #expect(full.contains(CellPoint(x: 5, y: 19))) // lower radial endpoint
        #expect(full.contains(CellPoint(x: 34, y: 19))) // upper radial endpoint
        let narrow = pixels(render(nil, targetBand: bands[4], style: .dial))
        #expect(narrow.contains(CellPoint(x: 20, y: 5)))
        #expect(narrow.contains(CellPoint(x: 20, y: 10)))
        let coincident = pixels(render(0.5, targetBand: bands[4], style: .dial))
        #expect(coincident.contains(CellPoint(x: 19, y: 7)))
        #expect(!pixels(render(0.5, style: .dial)).contains(CellPoint(x: 19, y: 7)))
        #expect(pixels(render(nil, targetBand: bands[1], style: .dial))
            != pixels(render(0, targetBand: bands[1], style: .dial)))
    }

    @Test("Target drawing respects empty, tiny, exact-limit and extreme native allocations")
    func targetAllocations() throws {
        let band = try MeasurementGauge.TargetBand(lowerBound: 0, upperBound: 1)
        for style in [MeasurementGauge.Style.bar, .dial] {
            for width in [0, 1, 2, 3, 20, 512, 700, 4096] {
                for height in [0, 1, 2, 3, 5] {
                    let frame = render(nil, targetBand: band, style: style, width: width, height: height)
                    #expect(!glyphs(frame).isEmpty)
                    let minimumWidth = style == .bar ? 1 : 20
                    #expect(frame.rasterSurface.size.width == max(minimumWidth, width))
                    let plotHeight = style == .bar ? 2 : 5
                    for (y, row) in frame.rasterSurface.cells.enumerated() {
                        for (x, cell) in row.enumerated() where cell.character != " " {
                            #expect(x < 512 && y < plotHeight)
                        }
                    }
                    let drawing = pixels(frame)
                    #expect(drawing.allSatisfy {
                        $0.x >= 0 && $0.x < min(max(width, style == .bar ? 1 : 20), 512) * 2
                            && $0.y >= 0 && $0.y < plotHeight * 4
                    })
                    if style == .bar, width >= 512, height >= 2 {
                        #expect(frame.rasterSurface.cells[1][511].character == "╡")
                    }
                }
            }
            let plotHeight = style == .bar ? 2 : 5
            _ = DefaultRenderer().render(
                ExtremeGaugeProposalLayout(expectedHeight: plotHeight) {
                    MeasurementGauge(position: nil, targetBand: band, style: style)
                }, proposal: ProposedSize(width: 512, height: plotHeight))
        }
        #expect(render(nil, targetBand: band, width: 1, height: 2).rasterSurface.lines == ["·", "╪"])
        #expect(render(nil, targetBand: band, width: 2, height: 2).rasterSurface.lines == ["··", "╞╡"])
        #expect(render(nil, targetBand: band, width: 3, height: 1).rasterSurface.lines == ["···", "╞═╡"])
    }

    @Test("Target geometry is independent of theme paint and semantics remain passive and overrideable")
    func targetThemesAndSemantics() throws {
        let band = try MeasurementGauge.TargetBand(lowerBound: 0.45, upperBound: 0.6)
        let custom = ChioTheme.default.replacing(colors: ChioTheme.default.colors.replacing(
            accent: Color(hexRGB: 0xAC24DA)))
        let monochrome = ChioTheme.default.replacing(colors: ChioTheme.default.colors.replacing(
            accent: Color(hexRGB: 0xFFFFFF)))
        for style in [MeasurementGauge.Style.bar, .dial] {
            for position in [0, 0.45, 0.6, 1, nil] as [Double?] {
                let reference = render(position, targetBand: band, style: style)
                for theme in [ChioTheme.default, .light, .btop, custom, monochrome] {
                    let frame = DefaultRenderer().render(
                        MeasurementGauge(position: position, targetBand: band, style: style).chioTheme(theme),
                        proposal: ProposedSize(width: 20, height: 5))
                    #expect(characters(frame) == characters(reference))
                    let painted = frame.rasterSurface.cells.flatMap { $0 }.filter { $0.character != " " }
                    #expect(painted.allSatisfy { $0.style?.foregroundColor == theme.colors.accent })
                    #expect(frame.semanticSnapshot.focusRegions.isEmpty)
                    #expect(!frame.semanticSnapshot.accessibilityNodes.contains { $0.role == .progressBar })
                    let reading: String
                    if let position { reading = "Measurement position: \(position) of 1." }
                    else { reading = "Measurement: missing reading." }
                    #expect(frame.semanticSnapshot.accessibilityNodes.contains {
                        $0.role == .image && $0.label == reading + " Target band: 0.45 to 0.6 of 1."
                    })
                }
            }
            let override = DefaultRenderer().render(
                MeasurementGauge(position: nil, targetBand: band, style: style)
                    .accessibilityLabel("Reservoir: reading unavailable. Desired level: 45 to 60 percent."))
            #expect(override.semanticSnapshot.accessibilityNodes.contains {
                $0.label == "Reservoir: reading unavailable. Desired level: 45 to 60 percent."
            })
            #expect(!override.semanticSnapshot.accessibilityNodes.contains {
                $0.label == "Measurement: missing reading. Target band: 0.45 to 0.6 of 1."
            })
        }
    }

    @Test("A retained renderer clears and restores target pixels and recovers after resize")
    func retainedTargetReplacement() throws {
        let band = try MeasurementGauge.TargetBand(lowerBound: 0.25, upperBound: 0.75)
        for style in [MeasurementGauge.Style.bar, .dial] {
            let renderer = DefaultRenderer()
            let proposal = ProposedSize(width: 20, height: 5)
            let targeted = MeasurementGauge(position: nil, targetBand: band, style: style)
                .frame(width: 20, height: 5, alignment: .topLeading)
            let first = renderer.render(targeted, proposal: proposal)
            let ordinary = MeasurementGauge(position: nil, targetBand: nil, style: style)
                .frame(width: 20, height: 5, alignment: .topLeading)
            let cleared = renderer.render(ordinary, proposal: proposal)
            let expected = DefaultRenderer().render(ordinary, proposal: proposal)
            #expect(cleared.rasterSurface == expected.rasterSurface)
            #expect(cleared.rasterSurface != first.rasterSurface)
            #expect(!cleared.semanticSnapshot.accessibilityNodes.contains {
                $0.label?.contains("Target band") == true
            })
            let restored = renderer.render(targeted, proposal: proposal)
            #expect(restored.rasterSurface == first.rasterSurface)
            _ = renderer.render(
                MeasurementGauge(position: nil, targetBand: band, style: style)
                    .frame(width: 2, height: 1, alignment: .topLeading),
                proposal: ProposedSize(width: 2, height: 1))
            let recovered = renderer.render(targeted, proposal: proposal)
            #expect(recovered.rasterSurface == first.rasterSurface)
        }
    }

    @Test("The target overload retains the legacy reading preconditions")
    func invalidTargetedPosition() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = MeasurementGauge(position: .nan, targetBand: nil) }
        }
        await #expect(processExitsWith: .failure) {
            await MainActor.run { _ = MeasurementGauge(position: Double(1).nextUp, targetBand: nil, style: .dial) }
        }
        await #expect(processExitsWith: .failure) {
            let empty = try MeasurementGauge.ReferenceMarks([])
            await MainActor.run { _ = MeasurementGauge(position: .nan, referenceMarks: empty) }
        }
    }

    @Test("Explicit empty references preserve the target and legacy no-reference contracts")
    func emptyReferences() throws {
        let empty = try MeasurementGauge.ReferenceMarks([])
        let target = try MeasurementGauge.TargetBand(lowerBound: 0.2, upperBound: 0.8)
        for style in [MeasurementGauge.Style.bar, .dial] {
            for band in [nil, target] {
                for position in [0, 1, nil] as [Double?] {
                    let old = render(position, targetBand: band, style: style)
                    let explicit = render(position, referenceMarks: empty, targetBand: band, style: style, height: 5)
                    #expect(old.rasterSurface == explicit.rasterSurface)
                    #expect(old.semanticSnapshot.accessibilityNodes.map(\.label)
                        == explicit.semanticSnapshot.accessibilityNodes.map(\.label))
                }
            }
        }
    }

    @Test("Supplied mean and maximum references retain their ordinal captions with missing or present readings")
    func referenceFacts() throws {
        let mean = try MeasurementGauge.ReferenceMark(id: "mean", label: "Mean 220 W", position: 220.0 / 600)
        let maximum = try MeasurementGauge.ReferenceMark(id: "maximum", label: "Max 410 W", position: 410.0 / 600)
        let references = try MeasurementGauge.ReferenceMarks([mean, maximum])
        let reversed = try MeasurementGauge.ReferenceMarks([maximum, mean])
        let reordered = render(nil, referenceMarks: reversed)
        #expect(String(reordered.rasterSurface.cells[1].map(\.character)) == "       2     1      ")
        #expect(reordered.rasterSurface.lines.contains { $0.contains("1 Max 410 W") })
        #expect(reordered.rasterSurface.lines.contains { $0.contains("2 Mean 220 W") })
        let target = try MeasurementGauge.TargetBand(lowerBound: 0.3, upperBound: 0.5)
        for style in [MeasurementGauge.Style.bar, .dial] {
            for position in [nil, 0, 250.0 / 600, 1] as [Double?] {
                let frame = render(position, referenceMarks: references, targetBand: target, style: style)
                let lines = frame.rasterSurface.lines
                #expect(lines.contains { $0.contains("1 Mean 220 W") })
                #expect(lines.contains { $0.contains("2 Max 410 W") })
                #expect(frame.semanticSnapshot.focusRegions.isEmpty)
                #expect(!frame.semanticSnapshot.accessibilityNodes.contains { $0.role == .progressBar })
                let summary = try #require(frame.semanticSnapshot.accessibilityNodes.first { $0.role == .image }?.label)
                #expect(summary.contains("Target band: 0.3 to 0.5 of 1."))
                #expect(summary.contains("Reference 1: Mean 220 W (\(mean.position) of 1)."))
                #expect(summary.contains("Reference 2: Max 410 W (\(maximum.position) of 1)."))
                #expect(!summary.contains("healthy"))
                #expect(!summary.contains("complete"))
                if position == nil { #expect(summary.contains("missing reading")) }
                if style == .bar {
                    #expect(String(frame.rasterSurface.cells[2].map(\.character)) == "       1     2      ")
                    #expect(lines[1] == render(position, targetBand: target).rasterSurface.lines[1])
                }
            }
        }
    }

    @Test("Shared cells use a collision marker while captions preserve both identities and caller order")
    func referenceCollisionsAndRenumbering() throws {
        let first = try MeasurementGauge.ReferenceMark(id: "first", label: "First 20 °C", position: 0.5)
        let second = try MeasurementGauge.ReferenceMark(id: "second", label: "Second 20 °C", position: Double(0.5).nextUp)
        let both = try MeasurementGauge.ReferenceMarks([first, second])
        let remaining = try MeasurementGauge.ReferenceMarks([second])
        for style in [MeasurementGauge.Style.bar, .dial] {
            let frame = render(0.5, referenceMarks: both, style: style)
            let plotRows = style == .bar ? 2 : 5
            #expect(frame.rasterSurface.lines.prefix(plotRows).joined().filter { $0 == "*" }.count == 1)
            #expect(frame.rasterSurface.lines.contains { $0.contains("1 First 20 °C") })
            #expect(frame.rasterSurface.lines.contains { $0.contains("2 Second 20 °C") })
            let replaced = render(0.5, referenceMarks: remaining, style: style)
            #expect(!replaced.rasterSurface.lines.prefix(plotRows).joined().contains("*"))
            #expect(replaced.rasterSurface.lines.contains { $0.contains("1 Second 20 °C") })
            #expect(!replaced.rasterSurface.lines.contains { $0.contains("First 20 °C") })
            #expect(replaced.semanticSnapshot.accessibilityNodes.contains {
                $0.label?.contains("Reference 1: Second 20 °C") == true
            })
        }
    }

    @Test("Dial ordinal cells have predictable whole-cell priority over arc, needle and target geometry")
    func dialReferencePriority() throws {
        let zero = try MeasurementGauge.ReferenceMark(id: "zero", label: "Lower endpoint", position: 0)
        let middle = try MeasurementGauge.ReferenceMark(id: "middle", label: "Midpoint", position: 0.5)
        let full = try MeasurementGauge.TargetBand(lowerBound: 0, upperBound: 1)
        let references = try MeasurementGauge.ReferenceMarks([zero, middle])
        for position in [nil, 0, 0.5] as [Double?] {
            let frame = render(position, referenceMarks: references, targetBand: full, style: .dial)
            #expect(frame.rasterSurface.cells[4][0].character == "1")
            #expect(frame.rasterSurface.cells[0][10].character == "2")
            #expect(frame.rasterSurface.lines.contains { $0.contains("1 Lower endpoint") })
            #expect(frame.rasterSurface.lines.contains { $0.contains("2 Midpoint") })
        }
    }

    @Test("Reference geometry is monochrome-readable and caption wrapping stays outside the plot height bound")
    func referenceThemesAndWrapping() throws {
        let first = try MeasurementGauge.ReferenceMark(id: "mean", label: "Mean 20.8 °C", position: 0.3)
        let second = try MeasurementGauge.ReferenceMark(id: "max", label: "Max 40.7 °C", position: 0.7)
        let references = try MeasurementGauge.ReferenceMarks([first, second])
        let monochrome = ChioTheme.default.replacing(colors: ChioTheme.default.colors.replacing(
            accent: Color(hexRGB: 0xFFFFFF), mutedText: Color(hexRGB: 0xFFFFFF)))
        for style in [MeasurementGauge.Style.bar, .dial] {
            let reference = render(nil, referenceMarks: references, style: style)
            for theme in [ChioTheme.default, .light, .btop, monochrome] {
                let frame = DefaultRenderer().render(
                    MeasurementGauge(position: nil, referenceMarks: references, style: style).chioTheme(theme),
                    proposal: ProposedSize(width: 20, height: 12))
                #expect(characters(frame) == characters(reference))
                let plotRows = style == .bar ? 2 : 5
                let plotCells = frame.rasterSurface.cells.prefix(plotRows).flatMap { $0 }.filter { $0.character != " " }
                #expect(plotCells.allSatisfy { $0.style?.foregroundColor == theme.colors.accent })
            }
            let wrapped = DefaultRenderer().render(
                MeasurementGauge(position: nil, referenceMarks: references, style: style).frame(width: 8))
            let plotRows = style == .bar ? 2 : 5
            if style == .bar { #expect(wrapped.rasterSurface.size.height > plotRows + 2) }
            else { #expect(wrapped.rasterSurface.size.height == plotRows + 2) }
            #expect(wrapped.semanticSnapshot.accessibilityNodes.contains {
                $0.label?.contains("Mean 20.8 °C") == true && $0.label?.contains("Max 40.7 °C") == true
            })
            let overridden = DefaultRenderer().render(
                MeasurementGauge(position: nil, referenceMarks: references, style: style)
                    .accessibilityLabel("Custom scale and supplied references"))
            #expect(overridden.semanticSnapshot.accessibilityNodes.contains {
                $0.role == .image && $0.label == "Custom scale and supplied references"
            })
            #expect(!overridden.semanticSnapshot.accessibilityNodes.contains {
                $0.label?.contains("Reference 1:") == true
            })
        }
    }

    @Test("References remain bounded under tiny and extreme allocations and clear in retained rendering")
    func referenceAllocationsAndClearing() throws {
        let first = try MeasurementGauge.ReferenceMark(id: "first", label: "First", position: 0)
        let second = try MeasurementGauge.ReferenceMark(id: "second", label: "Second", position: 1)
        let references = try MeasurementGauge.ReferenceMarks([first, second])
        let empty = try MeasurementGauge.ReferenceMarks([])
        for style in [MeasurementGauge.Style.bar, .dial] {
            for width in [0, 1, 2, 3, 20, 512, 700, 4096] {
                let frame = render(nil, referenceMarks: references, style: style, width: width)
                for row in frame.rasterSurface.cells {
                    for (x, cell) in row.enumerated() where cell.character != " " {
                        #expect(x < 512)
                    }
                }
                if style == .bar, width >= 512 {
                    #expect(frame.rasterSurface.cells[1][511].character == "2")
                }
            }
            let completeHeight = style == .bar ? 4 : 7
            _ = DefaultRenderer().render(
                ExtremeGaugeProposalLayout(expectedHeight: completeHeight) {
                    MeasurementGauge(position: nil, referenceMarks: references, style: style)
                }, proposal: ProposedSize(width: 512, height: completeHeight))
            let renderer = DefaultRenderer()
            let proposal = ProposedSize(width: 20, height: 12)
            let supplied = MeasurementGauge(position: nil, referenceMarks: references, style: style)
                .frame(width: 20, height: 12, alignment: .topLeading)
            let firstFrame = renderer.render(supplied, proposal: proposal)
            let removed = MeasurementGauge(position: nil, referenceMarks: empty, style: style)
                .frame(width: 20, height: 12, alignment: .topLeading)
            let cleared = renderer.render(removed, proposal: proposal)
            #expect(cleared.rasterSurface == DefaultRenderer().render(removed, proposal: proposal).rasterSurface)
            #expect(!cleared.semanticSnapshot.accessibilityNodes.contains { $0.label?.contains("Reference") == true })
            #expect(renderer.render(supplied, proposal: proposal).rasterSurface == firstFrame.rasterSurface)
        }
    }
}

// Measure an extreme child proposal without requesting an extreme root raster.
private struct ExtremeGaugeProposalLayout {
    let expectedHeight: Int
}

extension ExtremeGaugeProposalLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout Void) -> LayoutSize {
        let measured = subviews.first?.sizeThatFits(ProposedSize(width: Int.max, height: 12)) ?? .zero
        #expect(measured == CellSize(width: 512, height: expectedHeight))
        return CellSize(width: 512, height: expectedHeight)
    }

    func placeSubviews(in bounds: LayoutRect, proposal: ProposedViewSize,
                       subviews: LayoutSubviews, cache: inout Void) {
        for subview in subviews {
            subview.place(at: bounds.origin,
                          proposal: ProposedSize(width: bounds.size.width, height: bounds.size.height))
        }
    }
}
