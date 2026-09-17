"""Exercise publication gates without calling CurseForge or using a real token."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch, Mock
import urllib.error
import warnings
import zipfile

SPEC = importlib.util.spec_from_file_location('curseforge_release', Path(__file__).resolve().parents[1] / 'tools/curseforge_release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class Response(io.BytesIO):
    status = 200


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / release.ADDON).mkdir(parents=True)
        (self.root / 'dist').mkdir()
        (self.root / 'docs/releases').mkdir(parents=True)
        self.version = '1.2.3-dev'
        self.archive = self.root / 'dist' / f'ForeverReframed-{self.version}-forever-beta.zip'
        self.metadata = self.root / 'dist/curseforge-metadata.json'
        self.notes = self.root / 'docs/releases' / f'{self.version}.md'
        self.notes.write_text('# 1.2.3-dev\n\nWindow border fixes.\n')
        source_toc = f'## Interface: 11509\n## Version: {self.version}\n## X-Curse-Project-ID: 1699904\n\nCore.lua\n'
        (self.root / release.TOC).write_text(source_toc)
        core = f'Addon.version = "{self.version}"\n'
        (self.root / release.ADDON / 'Core.lua').write_text(core)
        self.members = {
            'ForeverReframed/ForeverReframed.toc': source_toc.replace('11509', '16001'),
            'ForeverReframed/Core.lua': core,
        }
        self.manifest = {
            'archive': self.archive.name, 'addon_version': self.version, 'target': 'forever-beta',
            'target_client_version': '1.60.1.69893', 'target_interface': 16001,
            'required_media_files': 0, 'bundled_media_files': 0,
        }
        self.repack()
        self.environment = patch.dict(os.environ, {
            'CF_API_TOKEN': 'test-secret-never-print', 'GITHUB_RUN_ATTEMPT': '1',
            'GITHUB_OUTPUT': str(self.root / 'outputs'),
            'GITHUB_STEP_SUMMARY': str(self.root / 'summary'),
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def repack(self):
        with zipfile.ZipFile(self.archive, 'w') as bundle:
            for name, contents in self.members.items():
                bundle.writestr(name, contents)
        self.manifest.update(sha256=hashlib.sha256(self.archive.read_bytes()).hexdigest(),
                             size=self.archive.stat().st_size, files=list(self.members))
        self.save_manifest()

    def save_manifest(self):
        self.archive.with_suffix('.json').write_text(json.dumps(self.manifest))

    def prepare(self):
        return release.prepare(self.root)

    def upload(self):
        return release.upload(self.root, self.archive, self.metadata)

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, check=True, text=True, capture_output=True).stdout.strip()

    def test_prepare_release_and_explicit_outputs(self):
        result = self.prepare()
        metadata = json.loads(self.metadata.read_text())
        self.assertEqual(metadata['releaseType'], 'release')
        self.assertEqual(metadata['gameVersionNames'], ['1.60.1'])
        self.assertFalse(metadata['isMarkedForManualRelease'])
        self.assertEqual(metadata['changelogType'], 'markdown')
        self.assertEqual(metadata['changelog'], self.notes.read_text().strip())
        self.assertEqual(result['publish'], 'false')
        self.assertIn('archive=dist/ForeverReframed-1.2.3-dev-forever-beta.zip\n', (self.root / 'outputs').read_text())

    def test_missing_or_empty_release_notes_fail(self):
        self.notes.unlink()
        with self.assertRaisesRegex(release.ReleaseError, 'Missing release notes'):
            self.prepare()
        self.notes.write_text(' \n')
        with self.assertRaisesRegex(release.ReleaseError, 'empty'):
            self.prepare()

    def test_core_version_mismatch_fails(self):
        (self.root / release.ADDON / 'Core.lua').write_text('Addon.version = "0.1"\n')
        with self.assertRaisesRegex(release.ReleaseError, 'versions disagree'):
            self.prepare()

    def test_wrong_source_project_fails(self):
        path = self.root / release.TOC
        path.write_text(path.read_text().replace('1699904', '1234567'))
        with self.assertRaisesRegex(release.ReleaseError, 'project ID'):
            self.prepare()

    def test_archive_project_interface_and_version_mismatches_fail(self):
        original = self.members['ForeverReframed/ForeverReframed.toc']
        for before, after in [('1699904', '123'), ('16001', '11509'), (self.version, '9.0.0')]:
            with self.subTest(before=before):
                self.members['ForeverReframed/ForeverReframed.toc'] = original.replace(before, after)
                self.repack()
                with self.assertRaisesRegex(release.ReleaseError, 'TOC mismatch'):
                    self.prepare()

    def test_manifest_target_mismatches_fail(self):
        for key, value in [('target', 'era'), ('target_interface', 11509),
                           ('target_client_version', '1.60.2.70000'), ('addon_version', '0.1'),
                           ('archive', 'wrong.zip')]:
            with self.subTest(key=key):
                original = self.manifest[key]
                self.manifest[key] = value
                self.save_manifest()
                with self.assertRaisesRegex(release.ReleaseError, 'target/version'):
                    self.prepare()
                self.manifest[key] = original

    def test_changed_archive_fails_checksum(self):
        with open(self.archive, 'ab') as stream:
            stream.write(b'changed')
        with self.assertRaisesRegex(release.ReleaseError, 'checksum'):
            self.prepare()

    def test_repackaged_stale_core_fails(self):
        self.members['ForeverReframed/Core.lua'] += '-- stale\n'
        self.repack()
        with self.assertRaisesRegex(release.ReleaseError, 'does not match'):
            self.prepare()

    def test_unsafe_members_fail_even_with_matching_checksum(self):
        for name in ['ForeverReframed/../evil.lua', '/ForeverReframed/evil.lua',
                     'OtherAddon/evil.lua', 'ForeverReframed\\evil.lua',
                     'ForeverReframed//evil.lua']:
            with self.subTest(name=name):
                self.members[name] = 'bad'
                self.repack()
                with self.assertRaisesRegex(release.ReleaseError, 'Unsafe archive'):
                    self.prepare()
                del self.members[name]

    def test_preview_package_rejected(self):
        with self.assertRaisesRegex(release.ReleaseError, 'normal Forever beta'):
            release.validate_package(self.root, 'dist/ForeverReframed-1.2.3-dev-forever-beta-local-preview.zip')
        self.manifest['bundled_media_files'] = 8
        self.save_manifest()
        with self.assertRaisesRegex(release.ReleaseError, 'Preview media'):
            self.prepare()

    def test_symlink_member_is_rejected(self):
        with zipfile.ZipFile(self.archive, 'a') as bundle:
            link = zipfile.ZipInfo('ForeverReframed/link')
            link.create_system = 3
            link.external_attr = 0o120777 << 16
            bundle.writestr(link, '../../outside')
        self.manifest.update(files=list(self.members) + ['ForeverReframed/link'],
                             sha256=hashlib.sha256(self.archive.read_bytes()).hexdigest(),
                             size=self.archive.stat().st_size)
        self.save_manifest()
        with self.assertRaisesRegex(release.ReleaseError, 'Unsafe archive'):
            self.prepare()

    def test_duplicate_and_unlisted_members_are_rejected(self):
        self.manifest['files'] = []
        self.save_manifest()
        with self.assertRaisesRegex(release.ReleaseError, 'members mismatch'):
            self.prepare()
        with warnings.catch_warnings(), zipfile.ZipFile(self.archive, 'a') as bundle:
            warnings.simplefilter('ignore', UserWarning)
            bundle.writestr('ForeverReframed/Core.lua', 'duplicate')
        self.manifest.update(files=list(self.members) + ['ForeverReframed/Core.lua'],
                             sha256=hashlib.sha256(self.archive.read_bytes()).hexdigest(),
                             size=self.archive.stat().st_size)
        self.save_manifest()
        with self.assertRaisesRegex(release.ReleaseError, 'duplicate'):
            self.prepare()

    def test_version_change_gate_uses_real_base_commit(self):
        self.git('init', '-q')
        self.git('config', 'user.name', 'Test')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('add', '.')
        self.git('commit', '-qm', 'current')
        same = self.git('rev-parse', 'HEAD')
        self.assertEqual(release.prepare(self.root, same)['publish'], 'false')
        toc = self.root / release.TOC
        toc.write_text(toc.read_text().replace(self.version, '1.2.2-dev'))
        self.git('add', '.')
        self.git('commit', '-qm', 'old version fixture')
        different = self.git('rev-parse', 'HEAD')
        toc.write_text(toc.read_text().replace('1.2.2-dev', self.version))
        self.assertEqual(release.prepare(self.root, different)['publish'], 'true')

    def test_invalid_or_unavailable_base_fails_closed(self):
        for base in ['0' * 40, 'HEAD', '--bad', 'a' * 40]:
            with self.subTest(base=base), self.assertRaises(release.ReleaseError):
                release.prepare(self.root, base)

    def test_metadata_channel_and_notes_cannot_be_changed(self):
        self.prepare()
        original = self.metadata.read_text()
        for key, value in [('releaseType', 'alpha'), ('gameVersionNames', ['1.15.9']),
                           ('changelog', 'unvalidated changes'), ('isMarkedForManualRelease', True)]:
            with self.subTest(key=key):
                data = json.loads(original)
                data[key] = value
                self.metadata.write_text(json.dumps(data))
                with patch.object(release.urllib.request, 'build_opener') as build:
                    with self.assertRaisesRegex(release.ReleaseError, 'metadata must match'):
                        self.upload()
                    build.assert_not_called()

    def test_success_posts_once_and_records_moderation_link_without_token(self):
        self.prepare()
        opener = Mock()
        opener.open.return_value = Response(b'{"id":8904620}')
        with patch.object(release.urllib.request, 'build_opener', return_value=opener):
            result = self.upload()
        opener.open.assert_called_once()
        request = opener.open.call_args.args[0]
        self.assertEqual(request.full_url, release.ENDPOINT)
        self.assertEqual(request.get_method(), 'POST')
        self.assertEqual(request.get_header('X-api-token'), os.environ['CF_API_TOKEN'])
        self.assertNotIn(os.environ['CF_API_TOKEN'].encode(), request.data)
        self.assertIn(b'name="metadata"', request.data)
        self.assertIn(b'"releaseType": "release"', request.data)
        self.assertIn(self.archive.read_bytes(), request.data)
        self.assertEqual(result['id'], 8904620)
        summary = (self.root / 'summary').read_text()
        self.assertIn('Submitted for moderation', summary)
        self.assertIn('/files/8904620', summary)
        self.assertNotIn(os.environ['CF_API_TOKEN'], (self.root / 'dist/curseforge-upload.json').read_text() + summary)

    def test_network_error_does_not_retry_or_leak_token(self):
        self.prepare()
        opener = Mock()
        opener.open.side_effect = urllib.error.URLError(os.environ['CF_API_TOKEN'])
        with patch.object(release.urllib.request, 'build_opener', return_value=opener):
            with self.assertRaises(release.ReleaseError) as failure:
                self.upload()
        opener.open.assert_called_once()
        self.assertNotIn(os.environ['CF_API_TOKEN'], str(failure.exception))
        self.assertFalse((self.root / 'dist/curseforge-upload.json').exists())

    def test_invalid_upload_responses_fail_closed(self):
        self.prepare()
        for response in [b'not-json', b'{}', b'{"id":true}', b'{"id":0}', b'[]']:
            with self.subTest(response=response):
                opener = Mock()
                opener.open.return_value = Response(response)
                with patch.object(release.urllib.request, 'build_opener', return_value=opener):
                    with self.assertRaises(release.ReleaseError):
                        self.upload()
                opener.open.assert_called_once()
                self.assertFalse((self.root / 'dist/curseforge-upload.json').exists())

    def test_non_success_response_is_not_recorded(self):
        self.prepare()
        opener = Mock()
        response = Response(b'{"id":8904620}')
        response.status = 503
        opener.open.return_value = response
        with patch.object(release.urllib.request, 'build_opener', return_value=opener):
            with self.assertRaisesRegex(release.ReleaseError, 'not successful'):
                self.upload()
        opener.open.assert_called_once()
        self.assertFalse((self.root / 'dist/curseforge-upload.json').exists())

    def test_redirect_is_never_followed(self):
        self.prepare()
        with self.assertRaisesRegex(release.ReleaseError, 'redirect rejected'):
            release.NoRedirect().redirect_request(Mock(), None, 302, 'Found', {}, 'https://elsewhere.invalid')

    def test_rerun_and_missing_token_refuse_before_http(self):
        self.prepare()
        for environment in [{'GITHUB_RUN_ATTEMPT': '2'}, {'CF_API_TOKEN': ''}]:
            with self.subTest(environment=environment), patch.dict(os.environ, environment):
                with patch.object(release.urllib.request, 'build_opener') as build:
                    with self.assertRaises(release.ReleaseError):
                        self.upload()
                    build.assert_not_called()


if __name__ == '__main__':
    unittest.main()
