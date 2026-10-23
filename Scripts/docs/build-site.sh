#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
site_output="$repo_root/.build/site"

# This directory contains only generated Pages output, never source documents.
rm -rf "$site_output"
mkdir -p "$site_output/recordings"
cp -R "$repo_root/Docs/Site/." "$site_output/"
# Keep the source-root contributor guide out of the published site.
rm "$site_output/README.md"
# New markup must load its matching styles and navigation script, even when a
# browser retains assets from a previous deployment. Source remains previewable.
python3 - "$site_output" <<'PY'
import hashlib
from pathlib import Path
import sys

site = Path(sys.argv[1])
pages = {page: page.read_text() for page in site.glob("*.html")}
for name in ("site.css", "recordings.js", "appearance.css", "appearance.js"):
    asset = site / name
    digest = hashlib.sha256(asset.read_bytes()).hexdigest()[:16]
    versioned = f"{asset.stem}.{digest}{asset.suffix}"
    asset.rename(site / versioned)
    pages = {page: html.replace(f'"{name}"', f'"{versioned}"') for page, html in pages.items()}
for page, html in pages.items():
    page.write_text(html)
PY
for recording in dashboard choices feedback-light pagination viewport tree forms timers markdown-links metrics instruments inbox diff maps keyboard-help files dot-matrix; do
  cp "$repo_root/Docs/Media/$recording.cast" "$site_output/recordings/"
  cp "$repo_root/Docs/Media/$recording.png" "$site_output/recordings/"
done
mkdir -p "$site_output/recordings/themes"
for example in choices feedback pagination viewport tree forms timers markdown dashboard metrics instruments inbox diff maps keyboard-help files dot-matrix; do
  for theme in default light btop; do
    cp "$repo_root/Docs/Media/themes/$example-$theme.png" "$site_output/recordings/themes/"
  done
done
mkdir -p "$site_output/recordings/appearance"
for treatment in chio opencode btop; do
  for width in wide narrow; do
    for extension in png cast; do
      cp "$repo_root/Docs/Media/appearance/$treatment-$width.$extension" "$site_output/recordings/appearance/"
    done
  done
done
touch "$site_output/.nojekyll"
printf 'Built demo site: %s\n' "$site_output"
