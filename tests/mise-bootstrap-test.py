#!/usr/bin/env python3
"""Migration must preserve choices and leave failed provisioning retryable."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import tomlkit

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "bootstrap", Path(__file__).resolve().parents[1] / "tools/mise-bootstrap.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class MigrationTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.target = self.home / ".config/mise/config.toml"
        self.marker = self.home / ".local/state/mise/nix-bootstrap-v1"
        self.defaults = tomlkit.parse('[tools]\nnode="24"\npnpm="latest"\nopencode="latest"\n')

    def seed(self):
        b.seed_config(self.home, self.target, self.defaults, self.marker)

    def test_merge_keeps_host_options_and_private_original(self):
        original = '# user comment\n[tools]\nnode="22"\n[env]\nCUSTOM="keep"\n[settings.self_update]\nauto=false\n'
        b.write_atomic(self.target, original)
        private = self.home / '.var/app/io.github.trumank.CodeStudio/home/.config/mise/config.toml'
        private_text = '[tools]\nnode="24.16.0"\n"npm:example"={version="1",expose=false}\n'
        b.write_atomic(private, private_text)
        self.seed()
        result = b.read_config(self.target)
        self.assertEqual(result['tools']['node'], '22')
        self.assertEqual(result['tools']['npm:example']['version'], '1')
        self.assertFalse(result['tools']['npm:example']['expose'])
        self.assertFalse(result['settings']['self_update']['auto'])
        self.assertEqual(result['env']['CUSTOM'], 'keep')
        self.assertIn('# user comment', self.target.read_text())
        self.assertEqual(private.read_text(), private_text)
        self.assertEqual(self.target.with_suffix('.toml.pre-shared-mise').read_text(), original)

    def test_second_activation_respects_removed_tools(self):
        self.seed()
        changed = '[tools]\nnode="26"\n'
        b.write_atomic(self.target, changed)
        self.seed()
        self.assertEqual(self.target.read_text(), changed)

    def test_invalid_private_config_does_not_publish_partial_migration(self):
        original = '[tools]\nnode="22"\n'
        b.write_atomic(self.target, original)
        b.write_atomic(self.home / '.var/app/com.jetbrains.CLion/config/mise/config.toml', '[')
        with self.assertRaises(tomlkit.exceptions.ParseError):
            self.seed()
        self.assertEqual(self.target.read_text(), original)
        self.assertFalse(self.marker.exists())

    def test_failed_download_preserves_old_symlink(self):
        binary = self.home / '.local/bin/mise'
        binary.parent.mkdir(parents=True)
        binary.symlink_to('/nix/store/old-mise/bin/mise')
        with patch.object(b.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'curl')):
            with self.assertRaises(subprocess.CalledProcessError):
                b.ensure_binary(binary)
        self.assertEqual(str(binary.readlink()), '/nix/store/old-mise/bin/mise')


if __name__ == '__main__':
    unittest.main()
