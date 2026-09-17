#!/usr/bin/env python3
"""Verify the checked-in artwork against its provenance manifest."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'classic-era'


def main():
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    expected = set()
    total = 0
    for item in manifest['files']:
        name = item['path']
        path = ROOT / name
        if not path.resolve().is_relative_to(ROOT.resolve()) or path.is_symlink():
            raise SystemExit(f'Invalid artwork path: {name}')
        data = path.read_bytes()
        if len(data) != item['size'] or hashlib.sha256(data).hexdigest() != item['sha256']:
            raise SystemExit(f'Artwork integrity check failed: {name}')
        if data[:4] not in (b'BLP1', b'BLP2'):
            raise SystemExit(f'Unexpected texture format: {name}')
        if name in expected:
            raise SystemExit(f'Duplicate artwork path: {name}')
        expected.add(name)
        total += len(data)
    actual = {path.relative_to(ROOT).as_posix() for path in (ROOT / 'interface').rglob('*') if path.is_file()}
    if actual != expected:
        raise SystemExit('Artwork directory and manifest differ.')
    print(f'Verified {len(expected):,} original BLP files ({total:,} bytes).')


if __name__ == '__main__':
    main()
