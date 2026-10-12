import SwiftTUIViews

/// A muted heading above an emphasized, application-authored reading.
///
/// This opt-in style inherits the current Chio theme and hosts each native slot
/// once. It does not format or inspect content. Inside an already-titled group,
/// compose `InstrumentReadout` or custom content directly: the pinned native
/// labelled-content API does not offer a label-hiding modifier.
public struct ChioInstrumentLabeledContentStyle {
    public init() {}
}

extension ChioInstrumentLabeledContentStyle: LabeledContentStyle {
    @MainActor
    public func makeBody(configuration: LabeledContentStyleConfiguration) -> some View {
        InstrumentBody(configuration: configuration)
    }
}

extension ChioInstrumentLabeledContentStyle: Equatable {}

@MainActor
private struct InstrumentBody {
    @Environment(\.chioStyle) private var theme
    let configuration: LabeledContentStyleConfiguration
}

extension InstrumentBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.verticalInset) {
            configuration.label.foregroundStyle(theme.colors.mutedText)
            configuration.content.foregroundStyle(theme.colors.accent)
        }
    }
}
