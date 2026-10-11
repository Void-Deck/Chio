import Chio
import SwiftTUI

/// Example-owned visual recipes; these are not additions to Chio's public theme catalog.
enum AppearanceRecipe: String {
    case chio
    case opencode
    case btop

    var title: String {
        switch self {
        case .chio: "Chio"
        case .opencode: "OpenCode"
        case .btop: "btop"
        }
    }

    var next: Self {
        switch self {
        case .chio: .opencode
        case .opencode: .btop
        case .btop: .chio
        }
    }

    var theme: ChioTheme {
        switch self {
        case .chio: .default
        case .btop: .btop
        case .opencode:
            ChioTheme.default.replacing(
                colors: ChioTheme.Colors(
                    accent: Color(hexRGB: 0xFAB283), heading: Color(hexRGB: 0xEEEAE5),
                    foreground: Color(hexRGB: 0xEEEAE5), secondaryText: Color(hexRGB: 0xB8B2AB),
                    mutedText: Color(hexRGB: 0x8E8780), surface: Color(hexRGB: 0x1D1D1D),
                    selectedSurface: Color(hexRGB: 0x3B3028), border: Color(hexRGB: 0x4B4641),
                    success: Color(hexRGB: 0xA8CB8B), warning: Color(hexRGB: 0xF0CD89),
                    error: Color(hexRGB: 0xEE8C86)
                ),
                spacing: AppearanceDensity.roomy.spacing,
                treatments: ChioTheme.Treatments(borderStyle: .single)
            )
        }
    }

    var canvas: Color {
        switch self {
        case .chio: ChioTheme.default.colors.surface
        case .opencode: Color(hexRGB: 0x111111)
        case .btop: ChioTheme.btop.colors.surface
        }
    }

    var usesAccentEdge: Bool {
        switch self {
        case .opencode: true
        case .chio, .btop: false
        }
    }

    var usesBorderTitle: Bool {
        switch self {
        case .btop: true
        case .chio, .opencode: false
        }
    }

    func theme(density: AppearanceDensity, isNarrow: Bool) -> ChioTheme {
        let spacing: ChioTheme.Spacing
        switch density {
        case .recipe: spacing = theme.spacing
        case .compact, .roomy: spacing = density.spacing
        }
        // This example's width policy is independent of the palette and framing.
        let fittedSpacing = isNarrow ? spacing.replacing(horizontalInset: min(1, spacing.horizontalInset)) : spacing
        return theme.replacing(spacing: fittedSpacing)
    }
}

extension AppearanceRecipe: CaseIterable {}
extension AppearanceRecipe: ExpressibleByArgument {}
extension AppearanceRecipe: Hashable {}
extension AppearanceRecipe: Codable {}
extension AppearanceRecipe: Sendable {}
