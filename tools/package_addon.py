#!/usr/bin/env python3
"""Package only original addon code, optionally with locally extracted preview art."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'addon' / 'ForeverClassicUI'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--with-preview-media', action='store_true',
                        help='Include only Media.lua sample textures from the local Era extraction.')
    args = parser.parse_args()
    toc = ADDON / 'ForeverClassicUI.toc'
    entries = [line.strip() for line in toc.read_text().splitlines()
               if line.strip() and not line.strip().startswith('#')]
    files = [(toc, f'{ADDON.name}/{toc.name}')]
    if (ADDON / 'README.md').is_file():
        files.append((ADDON / 'README.md', f'{ADDON.name}/README.md'))
    for notice in ('LICENSE', 'NOTICE.md'):
        files.append((ROOT / notice, f'{ADDON.name}/{notice}'))
    for entry in entries:
        path = (ADDON / entry.replace('\\', '/')).resolve()
        if not path.is_relative_to(ADDON.resolve()) or not path.is_file():
            raise SystemExit(f'Invalid or missing TOC entry: {entry}')
        files.append((path, f'{ADDON.name}/{entry}'))
    if args.with_preview_media:
        media_text = (ADDON / 'Media.lua').read_text()
        paths = re.findall(r'native\s*=\s*"([^"\n]+)"', media_text)
        if not paths:
            raise SystemExit('No sample paths found in Media.lua.')
        for native in paths:
            relative = native.replace('\\\\', '/').lower() + '.blp'
            sources = [ROOT / 'assets' / name / relative for name in ('classic-era', 'era')]
            source = next((path for path in sources if path.is_file()), None)
            if source is None:
                raise SystemExit(f'Preview texture was not extracted: {relative}')
            files.append((source, f'{ADDON.name}/Media/{relative}'))
    suffix = '-local-preview' if args.with_preview_media else ''
    dest = ROOT / 'dist' / f'ForeverClassicUI-0.1.0-dev{suffix}.zip'
    dest.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(dest, 'w', compression=zipfile.ZIP_DEFLATED) as bundle:
        for source, name in files:
            bundle.write(source, name)
    with zipfile.ZipFile(dest) as bundle:
        if bundle.testzip() is not None:
            raise SystemExit('Archive verification failed.')
        members = bundle.namelist()
    manifest = {'archive': dest.name, 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest(),
                'size': dest.stat().st_size, 'files': members,
                'includes_extracted_blizzard_art': args.with_preview_media,
                'includes_classicframes_code': False, 'in_game_validated': False,
                'target_interface': 11509}
    dest.with_suffix('.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
