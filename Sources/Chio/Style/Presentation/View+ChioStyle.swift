import SwiftTUIViews

extension View {
    /// Scopes a style and installs Chio's native control styles.
    public func style(_ style: ChioStyle) -> some View {
        environment(\.chioStyle, style)
            .groupBoxStyle(ChioGroupBoxStyle(theme: style, titlePlacement: style.treatments.groupBoxTitlePlacement))
            .disclosureGroupStyle(ChioDisclosureGroupStyle(theme: style))
            .listStyle(ChioListStyle(theme: style))
            .tableStyle(ChioTableStyle(theme: style))
            .tabViewStyle(ChioTabViewStyle(theme: style))
            .scrollViewStyle(ChioScrollViewStyle(theme: style))
            .paletteStyle(ChioPaletteStyle(theme: style))
            .textFieldStyle(ChioTextFieldStyle(theme: style))
            .textEditorStyle(ChioTextEditorStyle(theme: style))
            .progressViewStyle(ChioProgressViewStyle(theme: style))
            .spinnerStyle(ChioSpinnerStyle(theme: style))
            .promptStyle(ChioPromptStyle(theme: style))
            .buttonStyle(ChioButtonStyle(theme: style))
            .linkStyle(ChioLinkStyle(theme: style))
            .pickerStyle(ChioPickerStyle(theme: style))
            .toggleStyle(ChioToggleStyle(theme: style))
            .sliderStyle(ChioSliderStyle())
            .stepperStyle(ChioStepperStyle())
            .foregroundStyle(style.colors.foreground)
            .tint(style.colors.accent)
            .background(style.surfaces.canvas.resolve(base: style.colors.surface))
    }
}
