import SwiftTUIViews

/// Semantic colors, cell spacing, and visual treatments for a Chio subtree.
public struct ChioStyle {
    public let colors: Colors
    public let spacing: Spacing
    public let treatments: Treatments
    public let syntax: SyntaxColors
    public let map: MapColors
    public let gauge: GaugeColors
    public let surfaces: Surfaces

    public init(
        colors: Colors = Colors(),
        spacing: Spacing = Spacing(),
        treatments: Treatments = Treatments(),
        syntax: SyntaxColors = SyntaxColors(),
        map: MapColors = MapColors(),
        gauge: GaugeColors = GaugeColors(),
        surfaces: Surfaces = Surfaces()
    ) {
        self.colors = colors
        self.spacing = spacing
        self.treatments = treatments
        self.syntax = syntax
        self.map = map
        self.gauge = gauge
        self.surfaces = surfaces
    }

    /// Preserves the six-component initializer's function-reference signature.
    public init(
        colors: Colors, spacing: Spacing, treatments: Treatments,
        syntax: SyntaxColors, map: MapColors, gauge: GaugeColors
    ) {
        self.init(colors: colors, spacing: spacing, treatments: treatments,
                  syntax: syntax, map: map, gauge: gauge, surfaces: Surfaces())
    }

    /// Preserves the original initializer's function-reference signature.
    public init(
        colors: Colors,
        spacing: Spacing,
        treatments: Treatments,
        syntax: SyntaxColors,
        map: MapColors
    ) {
        self.init(colors: colors, spacing: spacing, treatments: treatments,
                  syntax: syntax, map: map, gauge: GaugeColors())
    }

    /// Returns a new style; omitted components retain their current values.
    public func replacing(
        colors: Colors? = nil,
        spacing: Spacing? = nil,
        treatments: Treatments? = nil,
        syntax: SyntaxColors? = nil,
        map: MapColors? = nil,
        gauge: GaugeColors? = nil,
        surfaces: Surfaces? = nil
    ) -> Self {
        ChioStyle(colors: colors ?? self.colors, spacing: spacing ?? self.spacing,
             treatments: treatments ?? self.treatments, syntax: syntax ?? self.syntax,
             map: map ?? self.map, gauge: gauge ?? self.gauge,
             surfaces: surfaces ?? self.surfaces)
    }

    /// Preserves the six-component replacement's function-reference signature.
    public func replacing(
        colors: Colors?, spacing: Spacing?, treatments: Treatments?,
        syntax: SyntaxColors?, map: MapColors?, gauge: GaugeColors?
    ) -> Self {
        replacing(colors: colors, spacing: spacing, treatments: treatments,
                  syntax: syntax, map: map, gauge: gauge, surfaces: nil)
    }

    /// Preserves the original replacement's function-reference signature.
    public func replacing(
        colors: Colors?,
        spacing: Spacing?,
        treatments: Treatments?,
        syntax: SyntaxColors?,
        map: MapColors?
    ) -> Self {
        replacing(colors: colors, spacing: spacing, treatments: treatments,
                  syntax: syntax, map: map, gauge: nil)
    }

    /// A dark palette inspired by Charm's Huh controls and Bubbles lists.
    public static let `default` = ChioStyle()

    public static let light = ChioStyle(colors: Colors(
        accent: Color(hexRGB: 0xB52B80),
        heading: Color(hexRGB: 0x5145CD),
        foreground: Color(hexRGB: 0x272634),
        secondaryText: Color(hexRGB: 0x565367),
        mutedText: Color(hexRGB: 0x777285),
        surface: Color(hexRGB: 0xFAF8FF),
        selectedSurface: Color(hexRGB: 0xE9E3FC),
        border: Color(hexRGB: 0xB4ACC4),
        success: Color(hexRGB: 0x23784E),
        warning: Color(hexRGB: 0x996800),
        error: Color(hexRGB: 0xBE354B)
    ), syntax: SyntaxColors(
        keyword: Color(hexRGB: 0x922368),
        type: Color(hexRGB: 0x155C83),
        string: Color(hexRGB: 0x246641),
        number: Color(hexRGB: 0x825005),
        comment: Color(hexRGB: 0x615968)
    ), map: MapColors(water: Color(hexRGB: 0xC8D6E4), park: Color(hexRGB: 0xD8E1E1)),
       gauge: GaugeColors(arc: Color(hexRGB: 0x8B8B91), target: Color(hexRGB: 0x800056),
                          needle: Color(hexRGB: 0x101014)))

    /// A compact dark palette inspired by btop's instrumentation layouts.
    public static let btop = ChioStyle(
        colors: Colors(
            accent: Color(hexRGB: 0x55C9D8),
            heading: Color(hexRGB: 0xA5D9E1),
            foreground: Color(hexRGB: 0xE5E9ED),
            secondaryText: Color(hexRGB: 0xB0BBC5),
            mutedText: Color(hexRGB: 0x84929E),
            surface: Color(hexRGB: 0x101419),
            selectedSurface: Color(hexRGB: 0x233440),
            border: Color(hexRGB: 0x526674),
            success: Color(hexRGB: 0x77C59B),
            warning: Color(hexRGB: 0xE5BD72),
            error: Color(hexRGB: 0xE77E88)
        ),
        spacing: Spacing(horizontalInset: 1, verticalInset: 0, sectionGap: 0, hintGap: 1),
        treatments: Treatments(groupBoxTitlePlacement: .border),
        syntax: SyntaxColors(
            keyword: Color(hexRGB: 0xC69ADD),
            type: Color(hexRGB: 0x55C9D8),
            string: Color(hexRGB: 0xA8C58C),
            number: Color(hexRGB: 0xE5BD72),
            comment: Color(hexRGB: 0xA0ACB6)
        ),
        map: MapColors(water: Color(hexRGB: 0x1F3C43), park: Color(hexRGB: 0x28302B)),
        gauge: GaugeColors(arc: Color(hexRGB: 0x565F66), target: Color(hexRGB: 0x6FFFFF),
                           needle: Color(hexRGB: 0xFFFFFF))
    )

    /// Roomy surfaces and leading edges inspired by OpenCode's terminal UI.
    public static let opencode = ChioStyle(
        colors: Colors(
            accent: Color(hexRGB: 0xFAB283), heading: Color(hexRGB: 0xEEEAE5),
            foreground: Color(hexRGB: 0xEEEAE5), secondaryText: Color(hexRGB: 0xB8B2AB),
            mutedText: Color(hexRGB: 0x8E8780), surface: Color(hexRGB: 0x1D1D1D),
            selectedSurface: Color(hexRGB: 0x3B3028), border: Color(hexRGB: 0x4B4641),
            success: Color(hexRGB: 0xA8CB8B), warning: Color(hexRGB: 0xF0CD89),
            error: Color(hexRGB: 0xEE8C86)
        ),
        spacing: Spacing(horizontalInset: 2, verticalInset: 1, sectionGap: 1, hintGap: 2,
                         inputVerticalInset: 1),
        treatments: Treatments(borderStyle: .single, groupBoxBorder: .leading, textFieldBorder: .leading),
        surfaces: Surfaces(canvas: .color(Color(hexRGB: 0x111111)),
                           input: .color(Color(hexRGB: 0x282522)))
    )

    /// Geographic area fills. Roads, routes and markers use the ordinary semantic palette.
    public struct MapColors {
        public let water: Color
        public let park: Color

        public init(water: Color = Color(hexRGB: 0x344754), park: Color = Color(hexRGB: 0x373B40)) {
            self.water = water
            self.park = park
        }

        public func replacing(water: Color? = nil, park: Color? = nil) -> Self {
            MapColors(water: water ?? self.water, park: park ?? self.park)
        }
    }

    /// Code token colors, independent of application success, warning, and error status.
    /// Plain code, punctuation, and operators use the ordinary foreground color.
    public struct SyntaxColors {
        public let keyword: Color
        public let type: Color
        public let string: Color
        public let number: Color
        public let comment: Color

        public init(
            keyword: Color = Color(hexRGB: 0xF780E2),
            type: Color = Color(hexRGB: 0x78DCE8),
            string: Color = Color(hexRGB: 0xA8DAB5),
            number: Color = Color(hexRGB: 0xE5C07B),
            comment: Color = Color(hexRGB: 0xB5AABE)
        ) {
            self.keyword = keyword
            self.type = type
            self.string = string
            self.number = number
            self.comment = comment
        }

        /// Returns a new syntax palette; omitted colors retain their current values.
        public func replacing(
            keyword: Color? = nil,
            type: Color? = nil,
            string: Color? = nil,
            number: Color? = nil,
            comment: Color? = nil
        ) -> Self {
            SyntaxColors(keyword: keyword ?? self.keyword, type: type ?? self.type,
                 string: string ?? self.string, number: number ?? self.number,
                 comment: comment ?? self.comment)
        }
    }

    public struct Colors {
        public let accent: Color
        public let heading: Color
        public let foreground: Color
        public let secondaryText: Color
        public let mutedText: Color
        public let surface: Color
        public let selectedSurface: Color
        public let border: Color
        public let success: Color
        public let warning: Color
        public let error: Color

        public init(
            accent: Color = Color(hexRGB: 0xF780E2),
            heading: Color = Color(hexRGB: 0x7571F9),
            foreground: Color = Color(hexRGB: 0xF2EEFA),
            secondaryText: Color = Color(hexRGB: 0xBBB4CB),
            mutedText: Color = Color(hexRGB: 0x81778F),
            surface: Color = Color(hexRGB: 0x211D2A),
            selectedSurface: Color = Color(hexRGB: 0x3A2D4F),
            border: Color = Color(hexRGB: 0x554762),
            success: Color = Color(hexRGB: 0x02BF87),
            warning: Color = Color(hexRGB: 0xF4CA64),
            error: Color = Color(hexRGB: 0xED567A)
        ) {
            self.accent = accent
            self.heading = heading
            self.foreground = foreground
            self.secondaryText = secondaryText
            self.mutedText = mutedText
            self.surface = surface
            self.selectedSurface = selectedSurface
            self.border = border
            self.success = success
            self.warning = warning
            self.error = error
        }

        /// Returns a new palette; omitted colors retain their current values.
        public func replacing(
            accent: Color? = nil,
            heading: Color? = nil,
            foreground: Color? = nil,
            secondaryText: Color? = nil,
            mutedText: Color? = nil,
            surface: Color? = nil,
            selectedSurface: Color? = nil,
            border: Color? = nil,
            success: Color? = nil,
            warning: Color? = nil,
            error: Color? = nil
        ) -> Self {
            Colors(accent: accent ?? self.accent, heading: heading ?? self.heading,
                 foreground: foreground ?? self.foreground,
                 secondaryText: secondaryText ?? self.secondaryText,
                 mutedText: mutedText ?? self.mutedText, surface: surface ?? self.surface,
                 selectedSurface: selectedSurface ?? self.selectedSurface,
                 border: border ?? self.border, success: success ?? self.success,
                 warning: warning ?? self.warning, error: error ?? self.error)
        }
    }

    public struct Treatments {
        public let borderStyle: StrokeStyle
        /// A single-cell glyph shown beside the selected search result.
        public let selectionMarker: String
        /// Single-cell glyphs repeated across a progress track.
        public let progressFilledGlyph: String
        public let progressEmptyGlyph: String
        public let groupBoxBorder: Edge.Set
        public let groupBoxTitlePlacement: ChioGroupBoxStyle.TitlePlacement
        public let textFieldBorder: Edge.Set

        public init(
            borderStyle: StrokeStyle = .rounded,
            selectionMarker: String = "›",
            progressFilledGlyph: String = "━",
            progressEmptyGlyph: String = "─",
            groupBoxBorder: Edge.Set = .all,
            groupBoxTitlePlacement: ChioGroupBoxStyle.TitlePlacement = .content,
            textFieldBorder: Edge.Set = .all
        ) {
            Self.requireSingleCellGlyph(selectionMarker)
            Self.requireSingleCellGlyph(progressFilledGlyph)
            Self.requireSingleCellGlyph(progressEmptyGlyph)
            self.borderStyle = borderStyle
            self.selectionMarker = selectionMarker
            self.progressFilledGlyph = progressFilledGlyph
            self.progressEmptyGlyph = progressEmptyGlyph
            self.groupBoxBorder = groupBoxBorder
            self.groupBoxTitlePlacement = groupBoxTitlePlacement
            self.textFieldBorder = textFieldBorder
        }

        /// Compatibility with the original four-component initializer.
        public init(borderStyle: StrokeStyle, selectionMarker: String,
                    progressFilledGlyph: String, progressEmptyGlyph: String) {
            self.init(borderStyle: borderStyle, selectionMarker: selectionMarker,
                      progressFilledGlyph: progressFilledGlyph, progressEmptyGlyph: progressEmptyGlyph,
                      groupBoxBorder: .all, groupBoxTitlePlacement: .content, textFieldBorder: .all)
        }

        /// Returns checked treatments; omitted values retain their current values.
        public func replacing(
            borderStyle: StrokeStyle? = nil,
            selectionMarker: String? = nil,
            progressFilledGlyph: String? = nil,
            progressEmptyGlyph: String? = nil,
            groupBoxBorder: Edge.Set? = nil,
            groupBoxTitlePlacement: ChioGroupBoxStyle.TitlePlacement? = nil,
            textFieldBorder: Edge.Set? = nil
        ) -> Self {
            Treatments(borderStyle: borderStyle ?? self.borderStyle,
                 selectionMarker: selectionMarker ?? self.selectionMarker,
                 progressFilledGlyph: progressFilledGlyph ?? self.progressFilledGlyph,
                 progressEmptyGlyph: progressEmptyGlyph ?? self.progressEmptyGlyph,
                 groupBoxBorder: groupBoxBorder ?? self.groupBoxBorder,
                 groupBoxTitlePlacement: groupBoxTitlePlacement ?? self.groupBoxTitlePlacement,
                 textFieldBorder: textFieldBorder ?? self.textFieldBorder)
        }

        /// Compatibility with the original four-component replacement.
        public func replacing(borderStyle: StrokeStyle?, selectionMarker: String?,
                              progressFilledGlyph: String?, progressEmptyGlyph: String?) -> Self {
            replacing(borderStyle: borderStyle, selectionMarker: selectionMarker,
                      progressFilledGlyph: progressFilledGlyph, progressEmptyGlyph: progressEmptyGlyph,
                      groupBoxBorder: nil, groupBoxTitlePlacement: nil, textFieldBorder: nil)
        }

        private static func requireSingleCellGlyph(_ glyph: String) {
            let layout = layoutText(for: glyph, width: nil)
            let hasControlScalar = glyph.unicodeScalars.contains {
                $0.properties.generalCategory == .control
                    || $0.properties.generalCategory == .lineSeparator
                    || $0.properties.generalCategory == .paragraphSeparator
            }
            let hasSingleLine = layout.lines.count == 1
            let hasSingleCluster = hasSingleLine && layout.lines[0].clusters.count == 1
            let hasSingleCellWidth = hasSingleCluster && layout.lines[0].cellWidth == 1
            precondition(!hasControlScalar && hasSingleLine && hasSingleCluster && hasSingleCellWidth,
                         "Theme glyphs must contain exactly one printable terminal cell")
        }
    }
}

extension ChioStyle: Equatable {}
extension ChioStyle: Sendable {}

extension ChioStyle.MapColors: Codable {}
extension ChioStyle.MapColors: Hashable {}
extension ChioStyle.MapColors: Sendable {}

extension ChioStyle.SyntaxColors: Decodable {}
extension ChioStyle.SyntaxColors: Encodable {}
extension ChioStyle.SyntaxColors: Equatable {}
extension ChioStyle.SyntaxColors: Hashable {}
extension ChioStyle.SyntaxColors: Sendable {}

extension ChioStyle.Colors: Decodable {}
extension ChioStyle.Colors: Encodable {}
extension ChioStyle.Colors: Equatable {}
extension ChioStyle.Colors: Hashable {}
extension ChioStyle.Colors: Sendable {}

extension ChioStyle.Treatments: Equatable {}
extension ChioStyle.Treatments: Sendable {}
