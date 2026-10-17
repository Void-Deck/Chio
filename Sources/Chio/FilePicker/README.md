# FilePicker

`FilePicker` browses directories and explicitly confirms one existing, readable
regular file. It composes [SearchableList](../SearchableList/Presentation/SearchableList.swift)
with native focus and actions, using the inherited Chio style.

## Use

Import `Chio`, `SwiftTUI` and `Foundation`. The application supplies a starting
directory and a retained optional URL binding:

```swift
FilePicker(
    directory: startingDirectory,
    selection: $selectedFile,
    allowedExtensions: .only(["swift", "md"]),
    onConfirm: { url in selectedDocument = url },
    onCancel: { showsPicker = false }
)
.style(.default)
```

The example's directory, bindings and presentation state belong to the
application. `onConfirm` and `onCancel` default to no-op callbacks.
Applications decide how to present/dismiss the picker and open confirmed files.

## Behavior and limits

Selection changes only after explicit confirmation; cancellation preserves its
previous value. Directory browsing and search do not commit the candidate.
Confirmation rechecks readability and file kind, then honors the value actually
retained by the application binding. It neither opens nor reserves file contents;
the application must still handle errors when opening the URL.

`allowedExtensions` defaults to `.all`. `.only([])` permits no files, while
`.only([""])` permits extensionless files. Matching ignores case and expects
extensions without a leading dot. Directories remain visible for navigation.
Hidden files are omitted unless `showsHiddenFiles: true` is supplied.

Symlinks are followed and the returned URL preserves the chosen path. The
starting directory does not restrict navigation. The component owns asynchronous
directory reads and confirmation validation; failed reads offer recovery actions.
Request identity prevents late reads or validations from committing stale work.
See the [file selection contract](../../../Docs/Decisions/FileSelection.md).

## Source and verification

- [FilePicker.swift](Presentation/FilePicker.swift) owns presentation and request lifecycle.
- [FileDirectoryReader.swift](Execution/FileDirectoryReader.swift) owns filesystem access.
- [FileExtensionFilter.swift](Domain/FileExtensionFilter.swift) defines extension policy.
- [FilePickerTests](../../../Tests/ChioTests/FilePicker/Presentation/FilePickerTests.swift) covers browsing, confirmation, rejected bindings, failure recovery and stale completions.
- [FileDirectoryReaderTests](../../../Tests/ChioTests/FilePicker/Execution/FileDirectoryReaderTests.swift) and [FileExtensionFilterTests](../../../Tests/ChioTests/FilePicker/Domain/FileExtensionFilterTests.swift) cover their respective boundaries.

See [Usage](../../../Docs/Usage.md#file-selection) and
[Verification](../../../Docs/Verification.md) for recipes and required checks.
