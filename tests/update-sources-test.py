#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('updater', Path(__file__).resolve().parents[1] / 'tools/update-sources.py')
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)


class UpdateTests(unittest.TestCase):
    def test_concurrent_updater_is_rejected_and_lock_is_released(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / '.git').mkdir()
            with patch.object(u.subprocess, 'check_output', return_value='.git/source-update.lock'):
                with u.checkout_lock(root):
                    with self.assertRaisesRegex(RuntimeError, 'Another source update'):
                        with u.checkout_lock(root):
                            self.fail('Concurrent update acquired the lock')
                with u.checkout_lock(root):
                    pass

    def asset(self):
        return {'kind': 'file', 'owner': 'owner', 'repo': 'repo', 'version': 'LTS',
                'name': 'model.gram', 'url': 'https://example.invalid/LTS/model.gram',
                'hash': u.FAKE_HASH, 'update': {'type': 'release', 'tag': 'LTS', 'asset': 'model.gram'}}

    def test_mutable_release_is_resolved_to_asset_id(self):
        original = self.asset()
        release = {'tag_name': 'LTS', 'assets': [{'id': 123, 'name': 'model.gram', 'digest': None}]}
        with patch.object(u, 'api', return_value=release), patch.object(u, 'file_hash', return_value='verified') as download:
            updated = u.refresh(original)
        self.assertEqual(updated['assetId'], 123)
        self.assertEqual(updated['url'], 'https://api.github.com/repos/owner/repo/releases/assets/123?download=1')
        self.assertEqual(updated['hash'], 'verified')
        self.assertNotIn('assetId', original)
        self.assertEqual(download.call_count, 1)

    def test_missing_asset_does_not_select_unrelated_download(self):
        with patch.object(u, 'api', return_value={'tag_name': 'LTS', 'assets': [{'id': 123, 'name': 'other'}]}):
            with self.assertRaises(ValueError):
                u.refresh(self.asset())

    def test_download_digest_is_checked_before_store_import(self):
        def command(args, **kwargs):
            if args[0] == 'curl':
                Path(args[args.index('--output') + 1]).write_bytes(b'wrong download')
            else:
                self.fail('An unverified download reached the Nix store')
        with patch.object(u, 'run', side_effect=command):
            with self.assertRaisesRegex(ValueError, 'digest mismatch'):
                u.file_hash(self.asset(), 'sha256:' + '0' * 64)

    def test_source_change_during_update_is_preserved(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'sources.json').write_bytes(b'user edit')
            with self.assertRaisesRegex(RuntimeError, 'changed during update'):
                u.publish(root, {'sources.json': b'old'}, {'sources.json': b'new'})
            self.assertEqual((root / 'sources.json').read_bytes(), b'user edit')

    def test_second_lock_write_failure_restores_first(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            original = {'sources.json': b'old sources', 'flake.lock': b'old flake'}
            for name, data in original.items():
                (root / name).write_bytes(data)
            (root / 'flake.lock.updating').write_text('another update')
            with self.assertRaises(FileExistsError):
                u.publish(root, original, {name: b'new' for name in original})
            for name, data in original.items():
                self.assertEqual((root / name).read_bytes(), data)

    def test_failed_asset_refresh_does_not_modify_either_lock(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'tools').mkdir()
            initial = u.encode({'first': self.asset(), 'second': self.asset()})
            (root / 'sources.json').write_bytes(initial)
            (root / 'flake.lock').write_bytes(b'original flake')
            with patch.object(u, '__file__', str(root / 'tools/update-sources.py')), \
                 patch.object(u, 'copy_checkout'), \
                 patch.object(u, 'refresh', side_effect=[self.asset(), ValueError('network failure')]), \
                 patch.object(sys, 'argv', ['update-sources.py', '--flake']):
                with self.assertRaisesRegex(ValueError, 'network failure'):
                    u.main()
            self.assertEqual((root / 'sources.json').read_bytes(), initial)
            self.assertEqual((root / 'flake.lock').read_bytes(), b'original flake')

    def test_vendor_hash_is_validated_and_not_guessed_on_other_failures(self):
        with tempfile.TemporaryDirectory() as temp:
            sources = {'dms': {'vendorHash': 'old'}}
            with patch.object(u.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'network failed')):
                with self.assertRaisesRegex(RuntimeError, 'network failed'):
                    u.update_vendor_hash(Path(temp), sources)

    def test_flake_failure_after_partial_staging_does_not_publish_locks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'tools').mkdir()
            original = u.encode({'asset': self.asset()})
            (root / 'sources.json').write_bytes(original)
            (root / 'flake.lock').write_bytes(b'old flake')

            def fail(args, **kwargs):
                (kwargs['cwd'] / 'flake.lock').write_bytes(b'partial flake')
                raise subprocess.CalledProcessError(1, args)

            with patch.object(u, '__file__', str(root / 'tools/update-sources.py')), \
                 patch.object(u, 'copy_checkout'), patch.object(u, 'refresh', return_value=self.asset()), \
                 patch.object(u, 'run', side_effect=fail), \
                 patch.object(sys, 'argv', ['update-sources.py', '--flake']):
                with self.assertRaises(subprocess.CalledProcessError):
                    u.main()
            self.assertEqual((root / 'sources.json').read_bytes(), original)
            self.assertEqual((root / 'flake.lock').read_bytes(), b'old flake')

    def test_vendor_hash_mismatch_is_followed_by_real_verification(self):
        got = u.sri('1' * 64)
        error = f"error: hash mismatch in fixed-output derivation '/nix/store/abc-dms-1.0-go-modules.drv':\n specified: {u.FAKE_HASH}\n got: {got}\n"
        with tempfile.TemporaryDirectory() as temp:
            sources = {'dms': {'vendorHash': 'old'}}
            with patch.object(u.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', error)), \
                 patch.object(u, 'run') as verify:
                u.update_vendor_hash(Path(temp), sources)
            self.assertEqual(sources['dms']['vendorHash'], got)
            self.assertEqual(verify.call_count, 1)
            self.assertEqual(json.loads((Path(temp) / 'sources.json').read_text())['dms']['vendorHash'], got)


if __name__ == '__main__':
    unittest.main()
