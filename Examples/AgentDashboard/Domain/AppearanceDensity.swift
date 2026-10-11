import Chio
import SwiftTUI

/// An independent spacing override for the visual comparison.
enum AppearanceDensity: String {
    case recipe
    case compact
    case roomy

    var next: Self {
        switch self {
        case .recipe: .compact
        case .compact: .roomy
        case .roomy: .recipe
        }
    }

    var spacing: ChioTheme.Spacing {
        switch self {
        case .recipe: ChioTheme.default.spacing
        case .compact: ChioTheme.Spacing(horizontalInset: 1, verticalInset: 0, sectionGap: 0, hintGap: 1)
        case .roomy: ChioTheme.Spacing(horizontalInset: 2, verticalInset: 1, sectionGap: 1, hintGap: 2)
        }
    }
}

extension AppearanceDensity: CaseIterable {}
extension AppearanceDensity: ExpressibleByArgument {}
extension AppearanceDensity: Hashable {}
extension AppearanceDensity: Codable {}
extension AppearanceDensity: Sendable {}
