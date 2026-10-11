import Chio
import SwiftTUI

/// A pure, example-only framing study. Keep the content in one stable native slot.
struct AppearanceGroupBoxStyle {
    let recipe: AppearanceRecipe
    let theme: ChioTheme
}

extension AppearanceGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: GroupBoxStyleConfiguration) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            if !recipe.usesBorderTitle, let label = configuration.label {
                label.foregroundStyle(theme.colors.heading)
            }
            configuration.content
        }
        .padding(EdgeInsets(horizontal: theme.spacing.horizontalInset, vertical: theme.spacing.verticalInset))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surface)
        .border(recipe.usesAccentEdge ? theme.colors.accent : theme.colors.border,
                style: theme.treatments.borderStyle, placement: .outset,
                sides: recipe.usesAccentEdge ? .leading : .all)
        .overlay(alignment: .topLeading) {
            if recipe.usesBorderTitle, let label = configuration.label {
                GeometryReader { geometry in
                    label.foregroundStyle(theme.colors.heading)
                        .lineLimit(1).truncationMode(.tail)
                        .padding(.horizontal, 1).background(theme.colors.surface)
                        .frame(width: max(0, geometry.size.width - 2), height: 1, alignment: .leading)
                        .padding(.leading, 1)
                        .frame(width: geometry.size.width, height: 1, alignment: .leading)
                        .clipped().opacity(geometry.size.width >= 5 ? 1 : 0)
                        .disabled(true).allowsHitTesting(false)
                }
                .clipped()
            }
        }
    }
}

extension AppearanceGroupBoxStyle: Equatable {}
