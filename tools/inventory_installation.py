#!/usr/bin/env python3
"""Read product/build metadata only; never read account settings or write into WoW."""
import argparse
import csv
import datetime
import json
import plistlib
from pathlib import Path


def inventory(root):
    build_info = root / '.build.info'
    products = []
    if build_info.is_file():
        with build_info.open(encoding='utf-8-sig', newline='') as stream:
            reader = csv.DictReader(stream, delimiter='|')
            for raw in reader:
                row = {key.split('!')[0]: value for key, value in raw.items()}
                products.append({
                    'product': row.get('Product'), 'version': row.get('Version'),
                    'build_key': row.get('Build Key'), 'active': row.get('Active') == '1',
                })
    installations = []
    for folder in sorted(root.glob('_*')):
        if not folder.is_dir():
            continue
        flavor = folder / '.flavor.info'
        flavor_lines = flavor.read_text().strip().splitlines() if flavor.exists() else []
        entry = {'folder': folder.name, 'product': flavor_lines[-1] if len(flavor_lines) > 1 else None}
        entry['applications'] = []
        for info in sorted(folder.glob('*.app/Contents/Info.plist')):
            with info.open('rb') as stream:
                data = plistlib.load(stream)
            entry['applications'].append({
                'name': info.parents[1].name,
                'version': data.get('CFBundleShortVersionString'),
                'build': data.get('CFBundleVersion'),
            })
        entry['interface_art_export_present'] = (folder / 'BlizzardInterfaceArt').is_dir()
        entry['interface_code_export_present'] = (folder / 'BlizzardInterfaceCode').is_dir()
        installations.append(entry)
    return {
        'inspected_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'installation_root': str(root),
        'products': products, 'installations': installations,
        'scope': 'Build/flavor/application metadata only. No WTF, account, chat or character data.',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('/Applications/World of Warcraft'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not (args.root / '.build.info').is_file():
        parser.error('No .build.info found at the supplied installation root.')
    if args.output.resolve().is_relative_to(args.root.resolve()):
        parser.error('Output must be outside the game installation.')
    result = inventory(args.root)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    for item in result['products']:
        print(f"{item['product']}: {item['version']}")


if __name__ == '__main__':
    main()
