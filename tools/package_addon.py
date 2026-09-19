#!/usr/bin/env python3
"""Package original addon code, required Classic artwork and optional preview art."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'addon' / 'ForeverReframed'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=('era', 'forever-beta'), default='era',
                        help='Target client; Forever uses the observed in-game Interface 16001.')
    parser.add_argument('--with-preview-media', action='store_true',
                        help='Include only Media.lua sample textures from the local Era extraction.')
    args = parser.parse_args()
    toc = ADDON / 'ForeverReframed.toc'
    toc_text = toc.read_text()
    metadata = dict(line[2:].strip().split(':', 1)
                    for line in toc_text.splitlines()
                    if line.startswith('##') and ':' in line)
    version = metadata.get('Version', '').strip()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]*', version):
        raise SystemExit('Missing or invalid addon Version in the source TOC.')
    source_interface = metadata.get('Interface', '').strip()
    if not source_interface.isdigit():
        raise SystemExit('Missing or invalid Interface in the source TOC.')
    target_interface = int(source_interface)
    interface_basis = 'source-addon-toc'
    target_client_version = None
    packaged_toc = None
    if args.target == 'forever-beta':
        target_interface = 16001
        target_client_version = '1.60.1.69913'
        interface_basis = 'Interface 16001 observed in user runtime logs on build 69913'
        overrides = {
            'Interface': str(target_interface),
            'Title': 'Classic UI - Forever Reframed - Beta Workshop',
            'Notes': 'Grouped Classic styling in Edit Mode, with experimental window borders.',
        }
        packaged_toc = '\n'.join(
            f'## {key}: {overrides[key]}' if key in overrides else line
            for line in toc_text.splitlines()
            for key in [line[2:].strip().partition(':')[0] if line.startswith('##') else None]
        ) + '\n'
    entries = [line.strip() for line in toc_text.splitlines()
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
    media_paths = set()
    required_media = ADDON / 'RequiredMedia.txt'
    if required_media.is_file():
        files.append((required_media, f'{ADDON.name}/RequiredMedia.txt'))
        media_paths.update(line.strip() for line in required_media.read_text().splitlines()
                           if line.strip() and not line.strip().startswith('#'))
    required_media_count = len(media_paths)
    if args.with_preview_media:
        media_text = (ADDON / 'Media.lua').read_text()
        paths = re.findall(r'native\s*=\s*"([^"\n]+)"', media_text)
        if not paths:
            raise SystemExit('No sample paths found in Media.lua.')
        media_paths.update(native.replace('\\\\', '/').lower() + '.blp' for native in paths)
    for relative in sorted(media_paths):
        path = Path(relative)
        if path.is_absolute() or '..' in path.parts or path.parts[0] != 'interface' or path.suffix != '.blp':
            raise SystemExit(f'Invalid artwork path: {relative}')
        sources = [ROOT / 'assets' / name / relative for name in ('classic-era', 'era')]
        source = next((path for path in sources if path.is_file()), None)
        if source is None:
            raise SystemExit(f'Required texture was not extracted: {relative}')
        files.append((source, f'{ADDON.name}/Media/{relative}'))
    target_suffix = '-forever-beta' if args.target == 'forever-beta' else ''
    media_suffix = '-local-preview' if args.with_preview_media else ''
    dest = ROOT / 'dist' / f'ForeverReframed-{version}{target_suffix}{media_suffix}.zip'
    dest.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(dest, 'w', compression=zipfile.ZIP_DEFLATED) as bundle:
        for source, name in files:
            if source == toc and packaged_toc is not None:
                bundle.writestr(name, packaged_toc)
            else:
                bundle.write(source, name)
    with zipfile.ZipFile(dest) as bundle:
        if bundle.testzip() is not None:
            raise SystemExit('Archive verification failed.')
        members = bundle.namelist()
    manifest = {'archive': dest.name, 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest(),
                'size': dest.stat().st_size, 'files': members,
                'includes_extracted_blizzard_art': bool(media_paths),
                'required_media_files': required_media_count,
                'bundled_media_files': len(media_paths),
                'includes_classicframes_code': False, 'in_game_validated': False,
                'addon_version': version, 'addon_version_basis': 'source-addon-toc',
                'target': args.target, 'target_client_version': target_client_version,
                'target_interface': target_interface, 'target_interface_basis': interface_basis,
                'compatibility_validation': 'pending'}
    dest.with_suffix('.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
