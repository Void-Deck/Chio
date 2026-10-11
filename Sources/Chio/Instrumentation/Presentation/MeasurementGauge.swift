import Foundation
import SwiftTUIViews

/// A passive indication of a supplied measurement's position on its scale.
///
/// A known position must be finite and in `0...1`; `nil` means a missing reading,
/// distinct from zero. Applications own normalization, units, out-of-range policy
/// and surrounding labels. This view owns no clock, sampling or measurement state.
///
/// A target band is independent of the reading and uses the same normalized scale.
/// The bar uses one row, or two with a target; the dial uses up to five rows.
/// Reserve the complete height to avoid clipping the bar's target track. Tiny
/// dials may merge target marks; callers can supply an ordinary target caption.
/// Supplied references add a numbered bar track, or numbered dial cells, and
/// native caption text beneath the plot. A shared reference cell displays `*`;
/// every caption remains independently present. Caption wrapping determines its
/// additional height. Applications reserve the complete plot and caption layout.
/// Both adapt to the native allocation, prefer twenty columns, and limit drawing
/// to 512 columns. The
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

    /// Presents a reading and an independently authored desired interval.
    public init(position: Double?, targetBand: TargetBand?, style: Style = .bar) {
        self.init(position: position, targetBand: targetBand, referenceMarks: [], style: style)
    }

    /// Presents up to two supplied references, without deriving aggregate values.
    public init(position: Double?, referenceMarks: ReferenceMarks,
                targetBand: TargetBand? = nil, style: Style = .bar) {
        self.init(position: position, targetBand: targetBand, referenceMarks: referenceMarks.marks, style: style)
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
            .frame(idealWidth: 20, maxWidth: 512,
                   idealHeight: .finite(preferredHeight), maxHeight: .finite(preferredHeight))
            .foregroundStyle(theme.colors.accent)
            .accessibilityLabel(summary)
    }
}

extension MeasurementGauge.Style: Hashable {}
extension MeasurementGauge.Style: Sendable {}

extension MeasurementGauge: View {
    @ViewBuilder
    public var body: some View {
        if referenceMarks.isEmpty {
            plot
        } else {
            VStack(alignment: .leading, spacing: 0) {
                plot.accessibilityHidden()
                ForEach(Array(referenceMarks.enumerated()), id: \.element.id) { entry in
                    Text("\(entry.offset + 1) \(entry.element.label)")
                        .foregroundStyle(theme.colors.mutedText)
                        .accessibilityHidden()
                }
            }
            .frame(maxWidth: 512, alignment: .leading)
            .accessibilityRole(.image)
            .accessibilityLabel(summary)
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
        // A terminal cell is approximately twice as tall as it is wide. Separate
        // radii preserve the semicircle's aspect and fit even one-cell allocations.
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
        if let targetBand {
            drawDialTarget(targetBand, into: &context, center: center,
                           radiusX: radiusX, radiusY: radiusY, steps: steps)
        }
        if let position {
            let angle = Double.pi * (1 - position)
            let tip = Point(x: center.x + cos(angle) * radiusX * 0.82,
                            y: center.y - sin(angle) * radiusY * 0.82)
            context.line(from: center, to: tip)
        }
        let locations = referenceMarks.map { mark in
            let angle = Double.pi * (1 - mark.position)
            let x = center.x + cos(angle) * radiusX
            let y = center.y - sin(angle) * radiusY
            return CellPoint(x: Int(x.rounded(.down)), y: Int(y.rounded(.down)))
        }
        drawReferences(at: locations, into: &context)
    }

    private func drawReferences(at locations: [CellPoint], into context: inout CanvasContext) {
        for (index, location) in locations.enumerated() {
            let sharesCell = locations.filter { $0 == location }.count > 1
            let glyph: Character
            if sharesCell { glyph = "*" }
            else if index == 0 { glyph = "1" }
            else { glyph = "2" }
            // Native grid writes overlay direct cells. Reserve the entire cell
            // for the ordinal; this explicit precedence applies to arc, needle
            // and target geometry equally and remains legible in monochrome.
            for x in 0..<2 {
                for y in 0..<4 {
                    context.clearSample(GridSample(x: location.x * 2 + x, y: location.y * 4 + y))
                }
            }
            context.setCell(at: location, character: glyph, foreground: context.foreground)
        }
    }

    private func drawDialTarget(_ targetBand: MeasurementGauge.TargetBand,
                                into context: inout CanvasContext, center: Point,
                                radiusX: Double, radiusY: Double, steps: Int) {
        // A concentric inner arc and radial endpoint marks identify the interval
        // in monochrome. All grid writes keep the same whole-cell foreground.
        let lower = targetBand.range.lowerBound
        let upper = targetBand.range.upperBound
        let bandSteps = max(1, Int(((upper - lower) * Double(steps)).rounded(.up)))
        var previous: Point?
        for index in 0...bandSteps {
            let position = lower + (upper - lower) * Double(index) / Double(bandSteps)
            let angle = Double.pi * (1 - position)
            let point = Point(x: center.x + cos(angle) * radiusX * 0.62,
                              y: center.y - sin(angle) * radiusY * 0.62)
            if let previous { context.line(from: previous, to: point) }
            else { context.setPixel(at: point) }
            previous = point
        }
        for bound in [lower, upper] {
            let angle = Double.pi * (1 - bound)
            let inside = Point(x: center.x + cos(angle) * radiusX * 0.48,
                               y: center.y - sin(angle) * radiusY * 0.48)
            let outside = Point(x: center.x + cos(angle) * radiusX * 0.76,
                                y: center.y - sin(angle) * radiusY * 0.76)
            context.line(from: inside, to: outside)
            // Tangential caps keep a narrow band visible when its radial mark
            // coincides with the needle. Clamp before native line submission.
            let marker = Point(x: center.x + cos(angle) * radiusX * 0.62,
                               y: center.y - sin(angle) * radiusY * 0.62)
            let halfWidth = sin(angle) * 0.5
            let halfHeight = cos(angle) * 0.25
            let maximumX = center.x * 2 - 0.125
            let maximumY = Double(min(5, context.size.height)) - 0.125
            let capStart = Point(x: max(0.125, min(maximumX, marker.x - halfWidth)),
                                 y: max(0.125, min(maximumY, marker.y - halfHeight)))
            let capEnd = Point(x: max(0.125, min(maximumX, marker.x + halfWidth)),
                               y: max(0.125, min(maximumY, marker.y + halfHeight)))
            context.line(from: capStart, to: capEnd)
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
