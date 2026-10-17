# MarkdownView

`MarkdownView` composes an immutable `MarkdownDocument` into native terminal
views. Construct and retain the document when source changes; the view does
not require reparsing on each theme or presentation update.

## Use

Import `Chio` and `SwiftTUI`. Supply a retained parsed document:

```swift
ScrollView {
    MarkdownView(document)
        .codeHighlighting(.automatic)
}
.style(.default)
```

Create the input with `MarkdownDocument(source)` at the content owner. The
application provides vertical scrolling. Code and tables use native horizontal
scrolling where needed. `.codeHighlighting(.plain)` removes token paint while
preserving source text, installed link actions and native scroll identity.

## Links, style and limits

The basic initializer is passive: links show readable labels and destinations.
`MarkdownView(document, openLink: OpenLinkAction { destination in ... })` enables
native links with an explicit application action returning whether it handled
the destination. A false result never invokes an outer/system opener.
Applications own opening policy, including schemes, relative paths and fragments;
rendering does not fetch or open destinations.

Supported content includes headings, rich paragraphs, code, lists, quotes, rules
and aligned tables. Images display readable alt/source text; HTML stays literal.
Swift fences highlight automatically with `ChioStyle.syntax` colors. Unknown,
unlabelled, oversized or parsing-budget-exhausted code stays wholly plain.
The [Markdown contract](../../../Docs/Decisions/Markdown.md) owns exact parsing
bounds, text normalization, native table styling and traversal limitations.

Native focus and scrolling control link traversal and reveal. Table body links
can activate; native headers use their readable plain fallback. Disabled links
retain native disabled behavior. Parser and third-party AST types stay internal;
the immutable document has no application persistence schema.

## Source and verification

- [MarkdownView.swift](Presentation/MarkdownView.swift) owns native composition and link mode.
- [MarkdownDocument.swift](Domain/MarkdownDocument.swift) owns retained parsed content.
- [MarkdownCode.swift](Domain/MarkdownCode.swift) owns internal Swift token classification.
- [MarkdownViewRenderTests](../../../Tests/ChioTests/Markdown/Presentation/MarkdownViewRenderTests.swift) covers document rendering.
- [MarkdownLinkTests](../../../Tests/ChioTests/Markdown/Presentation/MarkdownLinkTests.swift) covers explicit link behavior.
- [MarkdownInteractionTests](../../../Tests/ChioTests/Markdown/Presentation/MarkdownInteractionTests.swift) covers code scrolling, focus, paint and resize.
- [MarkdownTableInteractionTests](../../../Tests/ChioTests/Markdown/Presentation/MarkdownTableInteractionTests.swift) covers native table interaction.

See [Usage](../../../Docs/Usage.md#markdown) and
[Verification](../../../Docs/Verification.md) for recipes and required checks.
