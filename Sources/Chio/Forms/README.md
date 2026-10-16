# FormField

`FormField<Content>` composes a heading, an authored native control, and wrapping
help or error text. This source root also owns form validation visibility and
styles for native editors, pickers, toggles, sliders and steppers.

## Use

Import `Chio` and `SwiftTUI`. Keep the draft and current error in the application:

```swift
FormField("Name", description: "Required", error: nameError) {
    TextField("Name", text: $name)
}
.style(.default)
```

The initializer accepts `description: String = ""`, `error: String? = nil`, and
a `@ViewBuilder` content closure. Empty descriptions add no help row. A present
error replaces help, including an empty error string. Picker/toggle content
retains accessible native labels while omitting duplicate visible labels.

Compose several fields in native stacks or `GroupBox`; use a bounded native
`TextEditor` for multiline input. `.style(...)` supplies inherited colors and
native styles. More specific native style modifiers remain available.

## Validation and state

`FormValidation<Field>` controls when current application-provided issues become
visible. It stores visibility history, not rules or cached validation results.
Assign the replacement from `recordingExit(from:)` after blur. `submitting(_:)`
returns replacement `validation` and `firstInvalidField`; applications assign the
former and use native focus for the latter. `message(for:in:)` reads the current
ordered issues. Exclude hidden fields when computing those issues.

The application owns drafts, validation rules, submission, save/cancel and focus.
Native controls own editing, selection, masking and scrolling. Keep retained
draft values outside conditional or responsive field layouts. Chio adds no form
DSL, credential model or persistence layer. See the accepted
[forms contract](../../../Docs/Decisions/Forms.md) for editing and lifecycle limits.

## Source and verification

- [FormField.swift](Presentation/FormField.swift) owns field composition.
- [FormValidation.swift](Domain/FormValidation.swift) owns immutable visibility transitions.
- [ChioTextFieldStyle.swift](Presentation/ChioTextFieldStyle.swift) and [ChioTextEditorStyle.swift](Presentation/ChioTextEditorStyle.swift) style native text entry.
- [FormFieldRenderTests](../../../Tests/ChioTests/Forms/Presentation/FormFieldRenderTests.swift) covers help/error precedence, wrapping and native label treatment.
- [FormValidationTests](../../../Tests/ChioTests/Forms/Domain/FormValidationTests.swift) covers visibility and submission contracts.
- [ChioTextEntryTests](../../../Tests/ChioTests/Forms/Presentation/ChioTextEntryTests.swift) covers native secure/multiline interaction.
- [CreateAgentView](../../../Examples/AgentDashboard/Presentation/CreateAgentView.swift) demonstrates application-owned validation and focus.

See [Usage](../../../Docs/Usage.md#forms) and
[Verification](../../../Docs/Verification.md) for current recipes and checks.
