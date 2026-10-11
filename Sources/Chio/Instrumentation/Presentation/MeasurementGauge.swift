import Foundation
import SwiftTUIViews

/// A passive indication of a supplied measurement's position on its scale.
///
/// A known position must be finite and in `0...1`; `nil` means a missing reading,
/// distinct from zero. Applications own normalization, units, out-of-range policy
/// and surrounding labels. This view owns no clock, sampling or measurement state.
///
/// Bar target bands and references are independent of the reading and use the
/// same normalized scale.
/// The bar requires one row, plus a row each for targets and references. The
/// dial requires a complete twenty-column, five-row plot to retain its aspect.
/// Native fitting measures those complete plots; applications choose another
/// presentation when they do not fit. A caller-forced smaller frame or ancestor
/// viewport can still clip content through native layout.
/// Supplied references add a numbered bar track and native caption text beneath
/// the plot. A shared reference cell displays `*`;
/// every caption remains independently present. Caption wrapping determines its
/// additional height. Applications reserve the complete plot and caption layout.
/// Bars adapt to native width, prefer twenty columns, and limit drawing to 512
/// columns. A dial centers its fixed plot within wider native allocations;
/// reference captions wrap to the available width, up to 512 columns. The
/// environment's accent color applies at every position, including one. Replace
/// the accessibility label to describe an application's scale and units.
@MainActor
public struct MeasurementGauge {
    @Environment(\.chioTheme) private var theme
    private let position: Double?
    private let targetBand: TargetBand?
    private let referenceMarks: [ReferenceMark]
    private let style: Style

    /// The presentation of a measurement on a normalized scale.
    public enum Style {
        case bar
        case dial
    }

    public init(position: Double?, style: Style = .bar) {
        self.init(position: position, targetBand: nil, referenceMarks: [], style: style)
    }

    /// Presents a bar reading and an independently authored desired interval.
    public init(position: Double?, targetBand: TargetBand?) {
        self.init(position: position, targetBand: targetBand, referenceMarks: [], style: .bar)
    }

    /// Presents a bar with up to two supplied references, without deriving aggregate values.
    public init(position: Double?, referenceMarks: ReferenceMarks, targetBand: TargetBand? = nil) {
        self.init(position: position, targetBand: targetBand, referenceMarks: referenceMarks.marks, style: .bar)
    }

    private init(position: Double?, targetBand: TargetBand?, referenceMarks: [ReferenceMark], style: Style) {
        if let position {
            let isFinite = position.isFinite
            let isWithinScale = (0...1).contains(position)
            precondition(isFinite && isWithinScale,
                         "MeasurementGauge position must be finite and in 0...1; use nil for a missing reading.")
        }
        self.position = position
        self.targetBand = targetBand
        self.referenceMarks = referenceMarks
        self.style = style
    }

    private var preferredHeight: Int {
        switch style {
        case .bar:
            let targetRows = targetBand == nil ? 0 : 1
            let referenceRows = referenceMarks.isEmpty ? 0 : 1
            return 1 + targetRows + referenceRows
        case .dial: return 5
        }
    }

    private var minimumWidth: Int {
        switch style {
        case .bar: return 1
        case .dial: return 20
        }
    }

    private var maximumWidth: Int {
        switch style {
        case .bar: return 512
        case .dial: return 20
        }
    }

    private var summary: String {
        let reading: String
        if let position { reading = "Measurement position: \(position) of 1." }
        else { reading = "Measurement: missing reading." }
        let target: String
        if let targetBand {
            target = " Target band: \(targetBand.range.lowerBound) to \(targetBand.range.upperBound) of 1."
        } else { target = "" }
        let references = referenceMarks.enumerated().map { entry in
            " Reference \(entry.offset + 1): \(entry.element.label) (\(entry.element.position) of 1)."
        }.joined()
        return reading + target + references
    }

    private var plot: some View {
        Canvas(MeasurementDrawing(position: position, targetBand: targetBand,
                                  referenceMarks: referenceMarks, style: style), grid: .braille2x4)
            .frame(minWidth: .finite(minimumWidth), idealWidth: 20, maxWidth: .finite(maximumWidth),
                   minHeight: .finite(preferredHeight), idealHeight: .finite(preferredHeight),
                   maxHeight: .finite(preferredHeight))
            .foregroundStyle(theme.colors.accent)
    }
}

extension MeasurementGauge.Style: Hashable {}
extension MeasurementGauge.Style: Sendable {}

extension MeasurementGauge: View {
    public var body: some View {
        presentation
            .frame(minWidth: .finite(minimumWidth), idealWidth: 20, maxWidth: 512, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityRole(.image)
            .accessibilityLabel(summary)
    }

    @ViewBuilder
    private var presentation: some View {
        if referenceMarks.isEmpty {
            plot
                .frame(maxWidth: .infinity)
                .accessibilityHidden()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                plot.frame(maxWidth: .infinity).accessibilityHidden()
                ForEach(Array(referenceMarks.enumerated()), id: \.element.id) { entry in
                    Text("\(entry.offset + 1) \(entry.element.label)")
                        .lineLimit(nil)
                        .foregroundStyle(theme.colors.mutedText)
                        .accessibilityHidden()
                }
            }
        }
    }
}

private struct MeasurementDrawing {
    let position: Double?
    let targetBand: MeasurementGauge.TargetBand?
    let referenceMarks: [MeasurementGauge.ReferenceMark]
    let style: MeasurementGauge.Style

    private func drawBar(into context: inout CanvasContext, width: Int) {
        let filled = position.map { Int(($0 * Double(width)).rounded()) }
        for column in 0..<width {
            let glyph: Character
            if let filled {
                glyph = column < filled ? "▰" : "▱"
            } else {
                glyph = "·"
            }
            context.setCell(at: CellPoint(x: column, y: 0), character: glyph,
                            foreground: context.foreground)
        }
        if let targetBand, context.size.height > 1 {
            let lastColumn = Double(width - 1)
            let lower = Int((targetBand.range.lowerBound * lastColumn).rounded())
            let upper = Int((targetBand.range.upperBound * lastColumn).rounded())
            for column in lower...upper {
                let glyph: Character
                if lower == upper { glyph = "╪" }
                else if column == lower { glyph = "╞" }
                else if column == upper { glyph = "╡" }
                else { glyph = "═" }
                context.setCell(at: CellPoint(x: column, y: 1), character: glyph,
                                foreground: context.foreground)
            }
        }
        let referenceRow = targetBand == nil ? 1 : 2
        guard referenceRow < context.size.height else { return }
        let locations = referenceMarks.map { mark in
            CellPoint(x: Int((mark.position * Double(width - 1)).rounded()), y: referenceRow)
        }
        drawReferences(at: locations, into: &context)
    }

    private func drawDial(into context: inout CanvasContext, width: Int) {
        let height = min(5, context.size.height)
        // Assuming terminal cells are approximately twice as tall as they are
        // wide, the fixed 20×5 plot presents a physical semicircle. Font and
        // emulator metrics can differ; the drawing retains all braille samples.
        let radiusX = Double(width) / 2 - 0.25
        let radiusY = min(Double(height) - 0.25, radiusX / 2)
        let center = Point(x: Double(width) / 2, y: radiusY + 0.125)
        let steps = max(12, width * 4)
        var previous: Point?
        for index in 0...steps {
            let angle = Double.pi * (1 - Double(index) / Double(steps))
            let point = Point(x: center.x + cos(angle) * radiusX,
                              y: center.y - sin(angle) * radiusY)
            if let previous { context.line(from: previous, to: point) }
            else { context.setPixel(at: point) }
            previous = point
        }
        guard let position else { return }
        let angle = Double.pi * (1 - position)
        let tip = Point(x: center.x + cos(angle) * radiusX * 0.82,
                        y: center.y - sin(angle) * radiusY * 0.82)
        context.line(from: center, to: tip)
    }

    private func drawReferences(at locations: [CellPoint], into context: inout CanvasContext) {
        for (index, location) in locations.enumerated() {
            let sharesCell = locations.filter { $0 == location }.count > 1
            let glyph: Character
            if sharesCell { glyph = "*" }
            else if index == 0 { glyph = "1" }
            else { glyph = "2" }
            context.setCell(at: location, character: glyph, foreground: context.foreground)
        }
    }
}

extension MeasurementDrawing: CanvasDrawing {
    func draw(into context: inout CanvasContext) {
        guard context.size.width > 0, context.size.height > 0 else { return }
        let width = min(512, context.size.width)
        switch style {
        case .bar: drawBar(into: &context, width: width)
        case .dial: drawDial(into: &context, width: width)
        }
    }
}
