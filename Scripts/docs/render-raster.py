#!/usr/bin/env python3
"""Render native SwiftTUI raster cells or frame documents (requires Pillow).

This exports a native SwiftTUI raster, not a screenshot of an emulator. The font
and cell dimensions are explicit; live-terminal glyph/capability checks are separate.
PNG preserves colors; animated GIF quantizes them.
"""
import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def validate_cells(rows, label):
    if not isinstance(rows, list) or not rows:
        raise ValueError(f'{label}: cells must contain at least one row')
    if not isinstance(rows[0], list) or not rows[0]:
        raise ValueError(f'{label}: rows must contain at least one cell')
    width = len(rows[0])
    for row in rows:
        if not isinstance(row, list) or len(row) != width:
            raise ValueError(f'{label}: ragged rows')
        for cell in row:
            if not isinstance(cell, dict) or not isinstance(cell.get('character'), str):
                raise ValueError(f'{label}: each cell needs a character string')
            for role in ('foreground', 'background'):
                color = cell.get(role)
                if not isinstance(color, dict):
                    raise ValueError(f'{label}: {role} must be an RGB object')
                for channel in ('red', 'green', 'blue'):
                    value = color.get(channel)
                    if type(value) not in (int, float) or not 0 <= value <= 1 or not math.isfinite(value):
                        raise ValueError(f'{label}: {role}.{channel} must be finite and in 0…1')
    return width, len(rows)


def frames_from(document):
    if isinstance(document, list):
        frames = [{'delayMS': 250, 'cells': document}]
    elif isinstance(document, dict) and isinstance(document.get('frames'), list):
        frames = document['frames']
    else:
        raise ValueError('expected raster rows or an object containing a frames array')
    if not frames:
        raise ValueError('frames must contain at least one frame')
    size = None
    for index, frame in enumerate(frames):
        label = f'frame {index + 1}'
        if not isinstance(frame, dict):
            raise ValueError(f'{label}: expected an object')
        delay = frame.get('delayMS')
        if type(delay) is not int or delay <= 0:
            raise ValueError(f'{label}: delayMS must be a positive integer')
        frame_size = validate_cells(frame.get('cells'), label)
        if size is not None and frame_size != size:
            raise ValueError(f'{label}: dimensions {frame_size} do not match {size}')
        size = frame_size
    return frames, size


def rgb(color):
    return tuple(round(max(0, min(1, color[channel])) * 255) for channel in ('red', 'green', 'blue'))


def render(rows, size, font, symbols, cell_width, cell_height):
    width, height = size
    image = Image.new('RGB', (width * cell_width, height * cell_height))
    draw = ImageDraw.Draw(image)
    for y, row in enumerate(rows):
        for x, cell in enumerate(row):
            draw.rectangle((x * cell_width, y * cell_height,
                            (x + 1) * cell_width - 1, (y + 1) * cell_height - 1),
                           fill=rgb(cell['background']))
    # Paint glyphs after backgrounds so a native wide character can cover its continuation cell.
    for y, row in enumerate(rows):
        for x, cell in enumerate(row):
            if cell['character'].strip():
                glyph = cell['character']
                if len(glyph) == 1 and 0x2800 <= ord(glyph) <= 0x28ff:
                    # Center the complete braille block; glyph bounds vary with lit dots.
                    left, top, right, bottom = symbols.getbbox('\u28ff')
                    origin = (x * cell_width + (cell_width - right + left) / 2 - left,
                              y * cell_height + (cell_height - bottom + top) / 2 - top)
                    draw.text(origin, glyph, font=symbols, fill=rgb(cell['foreground']))
                else:
                    draw.text((x * cell_width, y * cell_height + 1), glyph,
                              font=font, fill=rgb(cell['foreground']))
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--font', type=Path, default=Path('/System/Library/Fonts/Menlo.ttc'))
    parser.add_argument('--symbol-font', type=Path, default=Path('/System/Library/Fonts/Apple Symbols.ttf'),
                        help='Font with Unicode braille coverage; Pillow does not perform font fallback')
    parser.add_argument('--cell-width', type=int, default=12)
    parser.add_argument('--cell-height', type=int, default=24)
    args = parser.parse_args()
    if args.cell_width <= 0 or args.cell_height <= 0:
        parser.error('cell dimensions must be positive')
    suffix = args.output.suffix.lower()
    if suffix not in ('.png', '.gif'):
        parser.error('output suffix must be .png or .gif')
    try:
        frames, size = frames_from(json.loads(args.input.read_text()))
        font = ImageFont.truetype(str(args.font), size=20)
        symbols = ImageFont.truetype(str(args.symbol_font), size=28)
        images = [render(frame['cells'], size, font, symbols, args.cell_width, args.cell_height)
                  for frame in frames]
        args.output.parent.mkdir(parents=True, exist_ok=True)
        if suffix == '.gif' or len(images) > 1:
            images[0].save(args.output, save_all=True, append_images=images[1:],
                           duration=[frame['delayMS'] for frame in frames], loop=0)
        else:
            images[0].save(args.output)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    width, height = size
    print(f'{width}x{height} native cells, {len(frames)} frame(s) -> {args.output}')


if __name__ == '__main__':
    main()
