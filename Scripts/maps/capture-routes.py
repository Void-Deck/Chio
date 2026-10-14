#!/usr/bin/env python3
"""Capture the isolated route-readability matrix through public hosted raster APIs."""

import argparse
import json
from pathlib import Path
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=Path('.build/release/RouteReadability'))
    parser.add_argument('--output', type=Path, default=Path('.build/route-readability'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    cases = [
        ('street-default', []),
        ('street-muted', ['--muted-roads']),
        ('street-finish', ['--muted-roads', '--endpoint', 'finish']),
        ('street-no-markers', ['--muted-roads', '--no-markers']),
        ('street-outlines', ['--muted-roads', '--outlines']),
        ('street-dense', ['--muted-roads', '--detail', 'source']),
        ('street-narrow', ['--muted-roads', '--width', '60', '--height', '24']),
        ('street-compact', ['--muted-roads', '--width', '36', '--height', '18']),
        ('street-light', ['--muted-roads', '--theme', 'light']),
        ('street-btop', ['--muted-roads', '--theme', 'btop']),
        ('hairpin', ['--muted-roads', '--route-case', 'hairpin']),
        ('hairpin-narrow', ['--muted-roads', '--route-case', 'hairpin', '--width', '60', '--height', '24']),
        ('crossing', ['--muted-roads', '--route-case', 'crossing']),
        ('crossing-narrow', ['--muted-roads', '--route-case', 'crossing', '--width', '60', '--height', '24']),
    ]
    manifest = []
    for name, options in cases:
        command = [str(args.binary.resolve()), '--snapshot', *options]
        capture = subprocess.run(command, cwd=root, capture_output=True, text=True, check=True, timeout=15)
        cells = json.loads(capture.stdout)
        text = '\n'.join(''.join(cell['character'] for cell in row) for row in cells)
        if 'Preparing map' in text or 'not navigation' not in text:
            raise RuntimeError(f'{name}: incomplete or unlabelled capture')
        is_compact = 'More room for the map' in text
        if is_compact != (name == 'street-compact'):
            raise RuntimeError(f'{name}: unexpected drawing/fallback mode')
        if not is_compact:
            def rgb(color):
                return tuple(round(color[channel] * 255) for channel in ('red', 'green', 'blue'))

            if '--muted-roads' in options:
                # Fixed spike palette: luminous mint on dark, contrasting teal on light.
                route_color = (0, 96, 107) if 'light' in options else (125, 255, 243)
            else:
                route_color = rgb(cells[0][0]['foreground'])
            route_cells = [cell for row in cells for cell in row
                           if '\u2801' <= cell['character'] <= '\u28ff' and rgb(cell['foreground']) == route_color]
            if len(route_cells) < 10:
                raise RuntimeError(f'{name}: route is absent or unexpectedly short')
        if name == 'street-finish' and 'Finish' not in text:
            raise RuntimeError('Selected finish is missing')
        path = output / f'{name}.json'
        path.write_text(capture.stdout)
        subprocess.run([sys.executable, str(root / 'Scripts/maps/render-snapshot.py'),
                        str(path), str(output / f'{name}.png')], check=True, timeout=15)
        manifest.append({'name': name, 'arguments': command[1:], 'width': len(cells[0]), 'height': len(cells)})
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    font = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 22)
    for filename, names, captions in [
        ('comparison', ['street-default', 'street-muted'], ['Existing style · 100×34', 'Muted background · same camera and path']),
        ('limits', ['hairpin-narrow', 'crossing-narrow'], ['Tight switchbacks · 60×24', 'Self-crossing path · 60×24']),
    ]:
        images = [Image.open(output / f'{name}.png').convert('RGB') for name in names]
        sheet = Image.new('RGB', (sum(im.width for im in images) + 24, max(im.height for im in images) + 52), '#14111b')
        draw = ImageDraw.Draw(sheet)
        x = 0
        for im, caption in zip(images, captions):
            draw.text((x + 8, 10), caption, font=font, fill='#f2eefa')
            sheet.paste(im, (x, 52))
            x += im.width + 24
        sheet.save(output / f'{filename}.png')


if __name__ == '__main__':
    main()
