#!/usr/bin/env python3
"""Validate a Forever package and submit a Release to CurseForge without retries."""
import argparse
import hashlib
import http.client
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import urllib.error
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = Path('addon/ForeverReframed')
TOC = ADDON / 'ForeverReframed.toc'
PROJECT_ID = 1699904
ENDPOINT = f'https://wow.curseforge.com/api/projects/{PROJECT_ID}/upload-file'


class ReleaseError(Exception):
    """An expected validation or submission failure safe to print in CI."""


def require(condition, message):
    if not condition:
        raise ReleaseError(message)


def toc_fields(text):
    fields = {}
    for line in text.splitlines():
        if line.startswith('##') and ':' in line:
            key, value = line[2:].split(':', 1)
            require(key.strip() not in fields, 'Duplicate TOC metadata.')
            fields[key.strip()] = value.strip()
    return fields


def read_json(path):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, UnicodeError, ValueError):
        raise ReleaseError('Required JSON file is missing or invalid.') from None


def source_version(root):
    fields = toc_fields((root / TOC).read_text(encoding='utf-8'))
    version = fields.get('Version', '')
    require(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]*', version), 'Invalid source TOC version.')
    require(fields.get('X-Curse-Project-ID') == str(PROJECT_ID), 'Wrong source CurseForge project ID.')
    core = (root / ADDON / 'Core.lua').read_text(encoding='utf-8')
    versions = re.findall(r'^Addon\.version\s*=\s*["\']([^"\']+)["\']', core, re.MULTILINE)
    require(versions == [version], 'Core.lua and source TOC versions disagree.')
    return version


def validate_package(root, archive=None):
    version = source_version(root)
    expected = root / 'dist' / f'ForeverReframed-{version}-forever-beta.zip'
    archive = expected if archive is None else Path(archive)
    if not archive.is_absolute():
        archive = root / archive
    require(archive.resolve() == expected.resolve(), 'Only the normal Forever beta archive can be published.')
    manifest = read_json(archive.with_suffix('.json'))
    require(isinstance(manifest, dict), 'Invalid package manifest.')
    checks = {
        'archive': expected.name, 'addon_version': version, 'target': 'forever-beta',
        'target_client_version': '1.60.1.69913', 'target_interface': 16001,
    }
    require(all(manifest.get(key) == value for key, value in checks.items()), 'Package target/version mismatch.')
    require(manifest.get('bundled_media_files') == manifest.get('required_media_files')
            and type(manifest.get('required_media_files')) is int,
            'Preview media must not be published.')
    content = archive.read_bytes()
    digest = hashlib.sha256(content).hexdigest()
    require(manifest.get('sha256') == digest and manifest.get('size') == len(content), 'Package checksum/size mismatch.')
    try:
        with zipfile.ZipFile(archive) as bundle:
            names = bundle.namelist()
            require(names == manifest.get('files') and len(names) == len(set(names)), 'Archive members mismatch or duplicate.')
            for item in bundle.infolist():
                parts = PurePosixPath(item.filename).parts
                require(parts and parts[0] == 'ForeverReframed' and len(parts) > 1
                        and all(part not in ('', '.', '..') for part in item.filename.split('/'))
                        and '\\' not in item.filename and ':' not in item.filename
                        and not item.is_dir() and not stat.S_ISLNK(item.external_attr >> 16),
                        'Unsafe archive member.')
            require(bundle.testzip() is None, 'Corrupt archive member.')
            fields = toc_fields(bundle.read('ForeverReframed/ForeverReframed.toc').decode('utf-8'))
            require(fields.get('Version') == version and fields.get('Interface') == '16001'
                    and fields.get('X-Curse-Project-ID') == str(PROJECT_ID), 'Packaged TOC mismatch.')
            require(bundle.read('ForeverReframed/Core.lua') == (root / ADDON / 'Core.lua').read_bytes(),
                    'Packaged Core.lua does not match the source.')
    except (zipfile.BadZipFile, KeyError, UnicodeError):
        raise ReleaseError('Invalid package archive.') from None
    notes = root / 'docs' / 'releases' / f'{version}.md'
    require(notes.is_file(), 'Missing release notes: docs/releases/<version>.md.')
    changelog = notes.read_text(encoding='utf-8').strip()
    require(bool(changelog), 'Release notes must not be empty.')
    metadata = {
        'displayName': f'Classic UI - Forever Reframed {version}',
        'gameVersionNames': [manifest['target_client_version'].rsplit('.', 1)[0]],
        'releaseType': 'release', 'changelog': changelog, 'changelogType': 'markdown',
        'isMarkedForManualRelease': False,
    }
    return version, archive, digest, metadata


def version_changed(root, version, base_ref):
    if base_ref is None:
        return False
    require(re.fullmatch(r'[0-9a-fA-F]{40}', base_ref) and set(base_ref) != {'0'},
            'Base ref must be a nonzero full commit SHA.')
    try:
        subprocess.run(['git', 'cat-file', '-e', f'{base_ref}^{{commit}}'], cwd=root,
                       check=True, capture_output=True)
        previous = subprocess.run(['git', 'show', f'{base_ref}:{TOC.as_posix()}'], cwd=root,
                                  check=True, capture_output=True, text=True).stdout
    except subprocess.CalledProcessError:
        raise ReleaseError('Base commit or its addon TOC is unavailable; fetch full history.') from None
    old_version = toc_fields(previous).get('Version', '')
    require(bool(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]*', old_version)), 'Base TOC has no valid version.')
    return old_version != version


def append_environment_file(variable, text):
    if os.environ.get(variable):
        with open(os.environ[variable], 'a', encoding='utf-8') as stream:
            stream.write(text)


def prepare(root, base_ref=None):
    version, archive, _, metadata = validate_package(root)
    publish = version_changed(root, version, base_ref)
    destination = root / 'dist' / 'curseforge-metadata.json'
    destination.write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    result = {'version': version, 'archive': archive.relative_to(root).as_posix(),
              'metadata': destination.relative_to(root).as_posix(), 'publish': str(publish).lower()}
    append_environment_file('GITHUB_OUTPUT', ''.join(f'{key}={value}\n' for key, value in result.items()))
    return result


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ReleaseError('Upload redirect rejected. Check CurseForge before starting a new workflow.')


def upload(root, archive, metadata_path):
    require(os.environ.get('GITHUB_RUN_ATTEMPT', '1') == '1',
            'Upload refused on a workflow rerun. Check CurseForge for an existing file, '
            'then use a new manual dispatch only if no submission exists.')
    token = os.environ.get('CF_API_TOKEN', '')
    require(token and '\r' not in token and '\n' not in token,
            'CF_API_TOKEN is missing or invalid. Configure the CF_API_TOKEN repository secret.')
    version, archive, digest, expected_metadata = validate_package(root, archive)
    metadata_path = Path(metadata_path)
    metadata = read_json(metadata_path if metadata_path.is_absolute() else root / metadata_path)
    require(metadata == expected_metadata, 'Upload metadata must match the validated Release package and release notes.')
    boundary = '----ForeverReframed' + uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n'
            'Content-Type: application/json\r\n\r\n').encode() + json.dumps(metadata).encode()
    body += (f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; '
             f'filename="{archive.name}"\r\nContent-Type: application/zip\r\n\r\n').encode()
    body += archive.read_bytes() + f'\r\n--{boundary}--\r\n'.encode()
    request = urllib.request.Request(ENDPOINT, data=body, method='POST', headers={
        'X-Api-Token': token, 'Content-Type': f'multipart/form-data; boundary={boundary}',
        'Accept': 'application/json', 'User-Agent': 'ForeverReframed-CI/1.0',
    })
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=60) as response:
            require(200 <= response.status < 300, 'Upload response was not successful; check CurseForge before retrying.')
            result = json.loads(response.read(1_000_001))
        require(isinstance(result, dict) and type(result.get('id')) is int and result['id'] > 0,
                'Upload response has no valid file ID; check CurseForge before retrying.')
    except (urllib.error.URLError, OSError, http.client.HTTPException, ValueError, UnicodeError):
        raise ReleaseError('Upload outcome is uncertain. Check CurseForge before starting a new workflow; '
                           'the request was not retried.') from None
    record = {'projectId': PROJECT_ID, 'id': result['id'], 'version': version,
              'archive': archive.name, 'sha256': digest}
    (root / 'dist' / 'curseforge-upload.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    url = f'https://authors.curseforge.com/#/projects/{PROJECT_ID}/files/{record["id"]}'
    append_environment_file('GITHUB_STEP_SUMMARY',
                            f'### CurseForge submission\n\nRelease {version}: [file {record["id"]}]({url}). '
                            'Submitted for moderation; public availability is not confirmed.\n')
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('prepare').add_argument('--base-ref')
    uploader = commands.add_parser('upload')
    uploader.add_argument('--archive', required=True)
    uploader.add_argument('--metadata', required=True)
    args = parser.parse_args()
    try:
        result = prepare(ROOT, args.base_ref) if args.command == 'prepare' else upload(ROOT, args.archive, args.metadata)
        print(json.dumps(result))
    except (ReleaseError, OSError, UnicodeError):
        error = sys.exc_info()[1]
        print(f'CurseForge: {error if isinstance(error, ReleaseError) else "Required local file cannot be read or written."}',
              file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
