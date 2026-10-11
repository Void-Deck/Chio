import Chio
import SwiftTUI

/// Supplied native editor and focus, presented with either an outline or an accent edge.
struct AppearanceTextFieldStyle {
    let recipe: AppearanceRecipe
    let theme: ChioTheme
}

extension AppearanceTextFieldStyle: TextFieldStyle {
    func makeBody(configuration: TextFieldStyleConfiguration) -> some View {
        let isActive = configuration.focusActive && configuration.isEnabled
        VStack(alignment: .leading, spacing: 0) {
            if configuration.showsLabel {
                configuration.label.foregroundStyle(theme.colors.secondaryText)
            }
            HStack(spacing: 0) {
                configuration.fieldContent
                    .foregroundStyle(configuration.isShowingPrompt ? theme.colors.mutedText : theme.colors.foreground)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.spacing.horizontalInset)
            .padding(.vertical, recipe.usesAccentEdge ? theme.spacing.verticalInset : 0)
            .background(recipe.usesAccentEdge ? Color(hexRGB: 0x282522) : theme.colors.surface)
            .border(isActive ? theme.colors.accent : theme.colors.border,
                    style: theme.treatments.borderStyle, placement: .outset,
                    sides: recipe.usesAccentEdge ? .leading : .all)
        }
        .opacity(configuration.isEnabled ? 1 : 0.6)
    }
}

extension AppearanceTextFieldStyle: Equatable {}
