#!/usr/bin/env python3
"""Decode extracted textures and create a contact sheet without changing originals."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

EXTENSIONS = {'.blp', '.tga', '.png', '.jpg', '.jpeg'}
PRIORITY = ('ui-targetingframe.blp', 'ui-targetingframe-rare-elite.blp', 'ui-partyframe.blp', 'ui-quickslot2.blp',
            'ui-questlog-topleft.blp', 'ui-questlog-topright.blp',
            'ui-questlog-botleft.blp', 'ui-questlog-botright.blp',
            'warriorarms-topleft.blp', 'warriorarms-topright.blp',
            'ui-talentframe-botleft.blp', 'ui-talentframe-botright.blp',
            'ui-mainmenubar-human.blp', 'ui-mainmenubar-endcap-human.blp',
            'ui-minimap-border.blp', 'ui-minimap-background.blp',
            'ui-spellbookpanel-topleft.blp', 'ui-spellbookpanel-topright.blp',
            'ui-spellbookpanel-botleft.blp', 'ui-spellbookpanel-botright.blp',
            'ui-character-general-topleft.blp', 'ui-character-general-bottomleft.blp',
            'ui-backpackbackground.blp', 'ui-bag-1x4.blp')


def order(path):
    name = path.name.lower()
    return (PRIORITY.index(name) if name in PRIORITY else len(PRIORITY), str(path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('assets/classic-era'))
    parser.add_argument('--output', type=Path, default=Path('previews'))
    parser.add_argument('--manifest', type=Path)
    parser.add_argument('--verify-all', action='store_true', help='Decode every texture, not just the displayed samples.')
    parser.add_argument('--tiles', type=int, default=24)
    args = parser.parse_args()
    if args.manifest is None:
        args.manifest = Path('manifests/texture-validation.json' if args.verify_all else 'manifests/texture-preview.json')
    if not 1 <= args.tiles <= 200:
        parser.error('--tiles must be between 1 and 200')
    paths = sorted((p for p in args.source.rglob('*') if p.suffix.lower() in EXTENSIONS), key=order)
    if not paths:
        parser.error('No textures found in the source directory.')
    available = len(paths)
    if not args.verify_all:
        paths = paths[:args.tiles]
    results, selected = [], []
    for path in paths:
        relative = path.relative_to(args.source)
        try:
            with Image.open(path) as im:
                im.load()
                row = {'path': relative.as_posix(), 'width': im.width, 'height': im.height,
                       'mode': im.mode, 'status': 'decoded'}
                if len(selected) < args.tiles:
                    preview = im.convert('RGBA')
                    target = args.output / relative.with_suffix('.png')
                    target.parent.mkdir(parents=True, exist_ok=True)
                    preview.save(target)
                    selected.append((relative, preview))
        except (OSError, ValueError, NotImplementedError) as exc:
            row = {'path': relative.as_posix(), 'status': 'decode_failed', 'error': str(exc)}
        results.append(row)
    if not selected:
        parser.error('No texture could be decoded; inspect the source format.')
    columns, tile_w, tile_h, header = 4, 280, 215, 88
    height = header + ((len(selected) + columns - 1) // columns) * tile_h
    canvas = Image.new('RGB', (columns * tile_w, height), '#17191c')
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default(size=14)
    title = ImageFont.load_default(size=25)
    draw.text((22, 16), 'Classic Era - extracted interface textures', fill='#e9cc86', font=title)
    draw.text((22, 53), 'Original BLP files preserved. PNG samples only; this is not an in-game screenshot.', fill='#bbc0c6', font=font)
    for index, (path, im) in enumerate(selected):
        x, y = (index % columns) * tile_w, header + (index // columns) * tile_h
        for cy in range(y + 8, y + 163, 12):
            for cx in range(x + 10, x + tile_w - 10, 12):
                color = '#292d32' if ((cx - x) // 12 + (cy - y) // 12) % 2 else '#22262b'
                draw.rectangle((cx, cy, min(cx + 11, x + tile_w - 11), min(cy + 11, y + 162)), fill=color)
        original_size = im.size
        im.thumbnail((tile_w - 28, 145), Image.Resampling.LANCZOS)
        canvas.paste(im, (x + (tile_w - im.width) // 2, y + 12 + (145 - im.height) // 2), im)
        label = path.name
        if len(label) > 33:
            label = label[:30] + '...'
        draw.text((x + 14, y + 173), label, fill='#f1f1ed', font=font)
        draw.text((x + 14, y + 192), f'{original_size[0]} x {original_size[1]}  |  {path.parent.name}', fill='#a0a8b0', font=font)
    args.output.mkdir(parents=True, exist_ok=True)
    sheet = args.output / 'classic-era-contact-sheet.png'
    canvas.save(sheet)
    data = {'source': str(args.source), 'available': available, 'coverage': 'all' if args.verify_all else 'samples', 'total': len(results),
            'decoded': sum(r['status'] == 'decoded' for r in results),
            'failed': sum(r['status'] == 'decode_failed' for r in results),
            'contact_sheet': str(sheet), 'textures': results}
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(data, indent=2) + '\n')
    print(json.dumps({key: value for key, value in data.items() if key != 'textures'}, indent=2))


if __name__ == '__main__':
    main()
