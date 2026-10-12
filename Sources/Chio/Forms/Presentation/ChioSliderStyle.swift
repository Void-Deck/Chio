import SwiftTUIViews

/// A themed native slider retaining its label, value and routed pointer track.
public struct ChioSliderStyle {
    public init() {}
}

extension ChioSliderStyle: SliderStyle {
    @MainActor
    public func makeBody(configuration: SliderStyleConfiguration) -> some View {
        SliderBody(configuration: configuration)
    }
}

extension ChioSliderStyle: Equatable {}

@MainActor
private struct SliderBody {
    @Environment(\.chioStyle) private var theme
    let configuration: SliderStyleConfiguration
}

extension SliderBody: View {
    var body: some View {
        let isActive = configuration.isEnabled && (configuration.focusActive || configuration.isPressed)
        let width = max(1, configuration.trackCellCount)
        let fraction = configuration.fractionCompleted.isFinite
            ? min(max(configuration.fractionCompleted, 0), 1) : 0
        let position = Int((fraction * Double(width - 1)).rounded())
        return HStack(spacing: theme.spacing.horizontalInset) {
            Text(configuration.focusActive && configuration.isEnabled ? "▌" : " ")
                .foregroundStyle(theme.colors.accent)
            configuration.label.foregroundStyle(theme.colors.secondaryText)
            configuration.track {
                Text(String(repeating: "━", count: position) + "●"
                     + String(repeating: "─", count: width - position - 1))
                    .foregroundStyle(theme.colors.accent)
            }
            configuration.valueLabel.foregroundStyle(theme.colors.foreground)
            Spacer(minLength: 0)
        }
        .background(isActive ? theme.colors.selectedSurface : theme.colors.surface)
        .opacity(configuration.isEnabled ? 1 : 0.6)
    }
}
