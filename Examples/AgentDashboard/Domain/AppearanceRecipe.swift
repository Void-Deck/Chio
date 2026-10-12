import Chio
import SwiftTUI

/// Example-owned CLI selection of reusable Chio presentation presets.
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

    var style: ChioStyle {
        switch self {
        case .chio: .default
        case .opencode: .opencode
        case .btop: .btop
        }
    }

    func style(density: AppearanceDensity, isNarrow: Bool) -> ChioStyle {
        let spacing: ChioStyle.Spacing
        switch density {
        case .recipe: spacing = style.spacing
        case .compact, .roomy: spacing = density.spacing
        }
        // This example's width policy is independent of its presentation value.
        let fittedSpacing = isNarrow ? spacing.replacing(horizontalInset: min(1, spacing.horizontalInset)) : spacing
        return style.replacing(spacing: fittedSpacing)
    }

}

extension AppearanceRecipe: CaseIterable {}
extension AppearanceRecipe: ExpressibleByArgument {}
extension AppearanceRecipe: Hashable {}
extension AppearanceRecipe: Codable {}
extension AppearanceRecipe: Sendable {}
