# Chio showcase website

This is the source root of the public [Chio showcase](https://echoz.github.io/Chio/).
It presents recorded terminal interactions, static theme previews, public API
fragments and matching launch commands. The
[package overview](../../README.md) retains the project's personal-software and
Codex-assisted development context, which the showcase also presents.

## Entry points and assets

`index.html` is the component/example catalog. `recordings.js` coordinates entry
selection, shared preview themes, URL history and explicit recording playback;
`site.css` styles that catalog. `appearance.html`, `appearance.js` and
`appearance.css` provide the separate style/size comparison.

Maps and DotMatrix lead the page as two featured views. Their wide terminal
previews reuse the approved recording stills; native links open the existing
catalog entries, where commands, playback and API details remain authoritative.
The rows stack on narrow screens. These featured stills retain their captured
appearance; the shared theme selector controls the catalog previews. DotMatrix's
unreleased status stays visible beside its featured introduction.

The catalog assembles 17 terminal recordings and 51 static previews across three themes from
`Docs/Media`. The pinned local player
and its upstream license stay in `vendor/asciinema-player`; its
[guide](vendor/asciinema-player/README.md) records player-specific limits.
The catalog distinguishes Chio views, styles for native SwiftTUI controls and
application-owned examples. Its browser state does not control a live terminal
application. Original recordings retain their captured theme changes even when
a different static-preview theme is selected.

The Views catalog includes public `DotMatrix` with its standalone `chio-matrix`
example. `recordings/dot-matrix.cast` and `recordings/dot-matrix.png` provide the
recording and fallback still; `recordings/themes/dot-matrix-{default,light,btop}.png`
provide static theme previews. Its command uses the same shared theme handling as
the other entries. Frame production, lettering, animation timing and interaction
belong to the example; the public view presents checked frames with inherited
dot styling. See the [component guide](../../Sources/Chio/DotMatrix/README.md) and
[example guide](../../Examples/DotMatrix/README.md).

## Assemble and preview

Run from the repository root with Bash and Python 3:

```sh
bash Scripts/docs/build-site.sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory .build/site
```

Open `http://127.0.0.1:8000/` in a browser. Assembly recreates the generated
`.build/site` directory, copies source/media assets and gives owned CSS/JavaScript
content-hashed filenames. It does not build Swift examples or refresh recordings.
Keep edits in the source files, not the generated directory.

The [Pages workflow](../../.github/workflows/pages.yml) assembles relevant pull
requests and deploys relevant `main` changes. Preview assembly is distinct from
publication and verification of the published result.

## Verification and capture ownership

The [showcase verification contract](../Verification.md#demo-site) owns capture
commands, approved media replacement and browser checks. Refresh affected assets
from a verified release binary, inspect full recordings and logs, then retain only
the approved media. Capture tools live in `Scripts/docs`; their optional browser
and rendering dependencies are documented in that contract.

Check assembly plus playback, seeking, theme/command/snippet agreement, related
navigation, featured-entry links, URL history, focus, narrow layouts and
script-free/missing-asset fallbacks. HTML and browser behavior need separate
checks beyond the Markdown link gate. Recordings demonstrate specific fixture workflows and captured
terminal sizes; they do not prove current live integrations, every platform,
terminal emulator or SSH configuration.
