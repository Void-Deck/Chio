import Chio
import Foundation
import SwiftTUIRuntime
import Testing

struct ChioStyleValueTests {
    @Test("Custom gauge colors compose independently and survive successive theme replacements")
    func gaugeCustomization() {
        let base = ChioStyle.btop
        let palette = ChioStyle.GaugeColors(arc: .red, target: .green, needle: .blue)
        let composed = ChioStyle(colors: base.colors, spacing: base.spacing,
                                 treatments: base.treatments, syntax: base.syntax,
                                 map: base.map, gauge: palette)
        let changedPalette = palette.replacing(target: .yellow).replacing(needle: .cyan)
        let changed = composed.replacing(gauge: changedPalette)
            .replacing(colors: base.colors.replacing(accent: .magenta))

        #expect(composed == base.replacing(gauge: palette))
        #expect(palette == ChioStyle.GaugeColors(arc: .red, target: .green, needle: .blue))
        #expect(changed.gauge == ChioStyle.GaugeColors(arc: .red, target: .yellow, needle: .cyan))
        #expect(composed.gauge == palette)
        #expect(base.gauge == ChioStyle.GaugeColors(arc: Color(hexRGB: 0x565F66),
                                                  target: Color(hexRGB: 0x6FFFFF),
                                                  needle: Color(hexRGB: 0xFFFFFF)))
        #expect(changed.colors == base.colors.replacing(accent: .magenta))
        #expect(changed.spacing == base.spacing)
        #expect(changed.treatments == base.treatments)
        #expect(changed.syntax == base.syntax)
        #expect(changed.map == base.map)
        #expect(changed.replacing() == changed)
        #expect(changedPalette.replacing() == changedPalette)
    }

    @Test("Gauge palettes preserve distinct roles through serialization and hashing")
    func gaugeRoundTrip() throws {
        let palette = ChioStyle.GaugeColors(arc: Color(hexRGB: 0x102030),
                                           target: Color(hexRGB: 0x405060),
                                           needle: Color(hexRGB: 0x708090))
        let data = try JSONEncoder().encode(palette)
        let decoded = try JSONDecoder().decode(ChioStyle.GaugeColors.self, from: data)
        #expect(decoded == palette)
        #expect(Set([palette, decoded]).count == 1)
        #expect(Set([palette, palette.replacing(arc: .red),
                     palette.replacing(target: .red), palette.replacing(needle: .red)]).count == 4)
    }

    @Test("The instrumentation preset preserves semantic customization and native treatments")
    func instrumentationPreset() throws {
        let base = ChioStyle.btop
        let copy = base
        let customized = base.replacing(colors: base.colors.replacing(accent: .red))
        #expect(base == copy)
        #expect(base != ChioStyle.default)
        #expect(base != ChioStyle.light)
        #expect(customized.colors.accent == .red)
        #expect(customized.colors.success == base.colors.success)
        #expect(customized.spacing == base.spacing)
        #expect(customized.treatments == base.treatments)
        #expect(base.spacing.sectionGap == 0)
        #expect(base.treatments == ChioStyle.default.treatments.replacing(groupBoxTitlePlacement: .border))
        #expect(base.replacing() == base)
        let title = ChioGroupBoxStyle.TitlePlacement.border
        #expect(try JSONDecoder().decode(ChioGroupBoxStyle.TitlePlacement.self,
                                       from: JSONEncoder().encode(title)) == title)
        let measurement = ChioProgressViewStyle.Treatment.measurement
        #expect(try JSONDecoder().decode(ChioProgressViewStyle.Treatment.self,
                                       from: JSONEncoder().encode(measurement)) == measurement)
        #expect(ChioGroupBoxStyle().titlePlacement == .content)
        #expect(ChioProgressViewStyle().treatment == .progress)
    }

    @Test("Successive customization leaves the base palette and unrelated values unchanged")
    func replacementIsolation() {
        let base = ChioStyle.light
        let copy = base
        let accent = Color(hexRGB: 0x123456)
        let error = Color(hexRGB: 0x654321)
        let surface = Color(hexRGB: 0x102030)
        let colors = base.colors.replacing(accent: accent, error: error)
            .replacing(surface: surface)
        let spacing = base.spacing.replacing(horizontalInset: 3, sectionGap: 2)
            .replacing(hintGap: 4)
        let stroke = StrokeStyle(borderSet: .double)
        let treatments = base.treatments.replacing(borderStyle: stroke, selectionMarker: ">")
            .replacing(progressFilledGlyph: "#", progressEmptyGlyph: ".")
        let first = base.replacing(colors: colors)
        let customized = first.replacing(spacing: spacing, treatments: treatments)

        #expect(base == copy)
        #expect(base == .light)
        #expect(ChioStyle.default == ChioStyle())
        #expect(first.spacing == base.spacing)
        #expect(first.treatments == base.treatments)
        #expect(customized.colors.accent == accent)
        #expect(customized.colors.error == error)
        #expect(customized.colors.surface == surface)
        #expect(customized.colors.heading == base.colors.heading)
        #expect(customized.colors.foreground == base.colors.foreground)
        #expect(customized.colors.secondaryText == base.colors.secondaryText)
        #expect(customized.colors.mutedText == base.colors.mutedText)
        #expect(customized.colors.selectedSurface == base.colors.selectedSurface)
        #expect(customized.colors.border == base.colors.border)
        #expect(customized.colors.success == base.colors.success)
        #expect(customized.colors.warning == base.colors.warning)
        #expect(customized.spacing == ChioStyle.Spacing(horizontalInset: 3, sectionGap: 2, hintGap: 4))
        #expect(customized.treatments.borderStyle == stroke)
        #expect(customized.treatments.selectionMarker == ">")
        #expect(customized.treatments.progressFilledGlyph == "#")
        #expect(customized.treatments.progressEmptyGlyph == ".")
        #expect(customized.replacing() == customized)
        #expect(colors.replacing() == colors)
        #expect(spacing.replacing() == spacing)
        #expect(treatments.replacing() == treatments)
    }

    @Test("All color roles can be replaced together without retaining defaults")
    func allColorRoles() {
        let palette = ChioStyle.default.colors
        let expected = ChioStyle.Colors(
            accent: Color(hexRGB: 0x010203), heading: Color(hexRGB: 0x040506),
            foreground: Color(hexRGB: 0x070809), secondaryText: Color(hexRGB: 0x101112),
            mutedText: Color(hexRGB: 0x131415), surface: Color(hexRGB: 0x161718),
            selectedSurface: Color(hexRGB: 0x192021), border: Color(hexRGB: 0x222324),
            success: Color(hexRGB: 0x252627), warning: Color(hexRGB: 0x282930),
            error: Color(hexRGB: 0x313233)
        )
        let changed = palette.replacing(
            accent: expected.accent, heading: expected.heading, foreground: expected.foreground,
            secondaryText: expected.secondaryText, mutedText: expected.mutedText,
            surface: expected.surface, selectedSurface: expected.selectedSurface,
            border: expected.border, success: expected.success,
            warning: expected.warning, error: expected.error
        )
        #expect(changed == expected)
        #expect(palette == ChioStyle.default.colors)
    }

    @Test("Zero distances and single-cell Unicode remain valid theme values")
    func validBoundaries() {
        let spacing = ChioStyle.Spacing(horizontalInset: 2, verticalInset: 3, sectionGap: 4, hintGap: 5)
        let zero = spacing.replacing(horizontalInset: 0, verticalInset: 0, sectionGap: 0, hintGap: 0)
        #expect(zero == ChioStyle.Spacing(horizontalInset: 0, verticalInset: 0, sectionGap: 0, hintGap: 0))
        #expect(spacing.verticalInset == 3)
        let treatments = ChioStyle.Treatments(selectionMarker: "é", progressFilledGlyph: "#", progressEmptyGlyph: " ")
        let replacement = treatments.replacing(selectionMarker: "e\u{301}")
        #expect(replacement.selectionMarker == "e\u{301}")
        #expect(replacement.progressFilledGlyph == "#")
        #expect(replacement.progressEmptyGlyph == " ")
        #expect(treatments.selectionMarker == "é")
    }

    @Test("Negative distances fail both construction and replacement", arguments: 0..<4)
    func negativeSpacing(component: Int) async {
        await #expect(processExitsWith: .failure) { [component] in
            switch component {
            case 0: _ = ChioStyle.Spacing(horizontalInset: -1)
            case 1: _ = ChioStyle.Spacing(verticalInset: -1)
            case 2: _ = ChioStyle.Spacing(sectionGap: -1)
            default: _ = ChioStyle.Spacing(hintGap: -1)
            }
        }
        await #expect(processExitsWith: .failure) { [component] in
            let base = ChioStyle.default.spacing
            switch component {
            case 0: _ = base.replacing(horizontalInset: -1)
            case 1: _ = base.replacing(verticalInset: -1)
            case 2: _ = base.replacing(sectionGap: -1)
            default: _ = base.replacing(hintGap: -1)
            }
        }
    }

    @Test("Empty, multiple-cell, wide and control markers cannot be constructed or substituted",
          arguments: ["", "ab", "界", "\n", "\t", "\u{1B}"])
    func invalidMarkers(glyph: String) async {
        await #expect(processExitsWith: .failure) { [glyph] in
            _ = ChioStyle.Treatments(selectionMarker: glyph)
        }
        await #expect(processExitsWith: .failure) { [glyph] in
            _ = ChioStyle.default.treatments.replacing(selectionMarker: glyph)
        }
    }

    @Test("Both progress glyphs retain their restrictions during construction and replacement")
    func invalidProgressGlyphs() async {
        await #expect(processExitsWith: .failure) {
            _ = ChioStyle.Treatments(progressFilledGlyph: "界")
        }
        await #expect(processExitsWith: .failure) {
            _ = ChioStyle.Treatments(progressEmptyGlyph: "")
        }
        await #expect(processExitsWith: .failure) {
            _ = ChioStyle.default.treatments.replacing(progressFilledGlyph: "界")
        }
        await #expect(processExitsWith: .failure) {
            _ = ChioStyle.default.treatments.replacing(progressEmptyGlyph: "")
        }
    }

    @Test("Spacing decodes valid distances and round-trips without changing zero values")
    func spacingRoundTrip() throws {
        let fixture = Data(#"{"horizontalInset":3,"verticalInset":0,"sectionGap":2,"hintGap":0}"#.utf8)
        let decoded = try JSONDecoder().decode(ChioStyle.Spacing.self, from: fixture)
        #expect(decoded == ChioStyle.Spacing(horizontalInset: 3, verticalInset: 0, sectionGap: 2, hintGap: 0))
        let data = try JSONEncoder().encode(decoded)
        #expect(try JSONDecoder().decode(ChioStyle.Spacing.self, from: data) == decoded)
        #expect(Set([decoded, decoded.replacing()]).count == 1)
        #expect(Set([decoded, decoded.replacing(hintGap: 1)]).count == 2)
    }

    @Test("Decoding rejects each negative spacing field with its field location",
          arguments: ["horizontalInset", "verticalInset", "sectionGap", "hintGap"])
    func invalidSpacingDecode(field: String) throws {
        let valid = ["horizontalInset": 1, "verticalInset": 0, "sectionGap": 1, "hintGap": 2]
        let invalid = valid.merging([field: -1]) { _, replacement in replacement }
        let fixture = try JSONSerialization.data(withJSONObject: invalid)
        do {
            _ = try JSONDecoder().decode(ChioStyle.Spacing.self, from: fixture)
            Issue.record("Negative spacing unexpectedly decoded")
        } catch DecodingError.dataCorrupted(let context) {
            #expect(context.codingPath.map(\.stringValue) == [field])
        }
    }

    @Test("Spacing decoding requires all integer fields instead of repairing malformed input",
          arguments: [
            #"{"horizontalInset":1,"verticalInset":0,"sectionGap":1}"#,
            #"{"horizontalInset":1,"verticalInset":null,"sectionGap":1,"hintGap":2}"#,
            #"{"horizontalInset":1,"verticalInset":"0","sectionGap":1,"hintGap":2}"#,
        ])
    func malformedSpacingDecode(fixture: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ChioStyle.Spacing.self, from: Data(fixture.utf8))
        }
    }

    @Test("Native palette values retain every role through Codable and Hashable synthesis")
    func colorsRoundTrip() throws {
        let palette = ChioStyle.light.colors.replacing(
            accent: Color(hexRGB: 0x010203), heading: Color(hexRGB: 0x040506),
            foreground: Color(hexRGB: 0x070809), secondaryText: Color(hexRGB: 0x101112),
            mutedText: Color(hexRGB: 0x131415), surface: Color(hexRGB: 0x161718),
            selectedSurface: Color(hexRGB: 0x192021), border: Color(hexRGB: 0x222324),
            success: Color(hexRGB: 0x252627), warning: Color(hexRGB: 0x282930),
            error: Color(hexRGB: 0x313233)
        )
        let data = try JSONEncoder().encode(palette)
        let decoded = try JSONDecoder().decode(ChioStyle.Colors.self, from: data)
        #expect(decoded == palette)
        #expect(Set([palette, decoded]).count == 1)
        #expect(Set([palette, palette.replacing(accent: .red)]).count == 2)
    }
}
