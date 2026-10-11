import SwiftTUIViews

/// A themed native stepper retaining its label, value and both pointer actions.
public struct ChioStepperStyle {
    public init() {}
}

extension ChioStepperStyle: StepperStyle {
    @MainActor
    public func makeBody(configuration: StepperStyleConfiguration) -> some View {
        StepperBody(configuration: configuration)
    }
}

extension ChioStepperStyle: Equatable {}

@MainActor
private struct StepperBody {
    @Environment(\.chioTheme) private var theme
    let configuration: StepperStyleConfiguration
}

extension StepperBody: View {
    var body: some View {
        let isActive = configuration.isEnabled && (configuration.focusActive || configuration.isPressed)
        return HStack(spacing: theme.spacing.horizontalInset) {
            Text(configuration.focusActive && configuration.isEnabled ? "▌" : " ")
                .foregroundStyle(theme.colors.accent)
            configuration.label.foregroundStyle(theme.colors.secondaryText)
            configuration.decrement {
                Text(configuration.canDecrement ? "◀" : "◁")
                    .foregroundStyle(configuration.canDecrement ? theme.colors.accent : theme.colors.mutedText)
            }
            configuration.valueLabel.foregroundStyle(theme.colors.foreground)
            configuration.increment {
                Text(configuration.canIncrement ? "▶" : "▷")
                    .foregroundStyle(configuration.canIncrement ? theme.colors.accent : theme.colors.mutedText)
            }
            Spacer(minLength: 0)
        }
        .background(isActive ? theme.colors.selectedSurface : theme.colors.surface)
        .opacity(configuration.isEnabled ? 1 : 0.6)
    }
}
