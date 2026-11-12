#!/usr/bin/env python3
"""Check real Git lookup and preservation of existing private config."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class GitBridgeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="codestudio git ")
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.host = root / "host home"
        self.private = root / "private home"
        self.config = self.host / "custom-xdg-config"
        self.write(self.config / "git/config", '[init]\n defaultBranch = main\n')
        self.write(self.config / "gh/config.yml", 'git_protocol: ssh\n')
        self.write(self.host / ".gitconfig", (
            f'[include]\n path = "{self.config}/git/config"\n'
            '[user]\n name = Shared Author\n email = author@example.test\n'
            '[credential]\n helper = test-helper\n'
        ))
        expr = f'''
          let
            flake = builtins.getFlake {json.dumps("path:" + str(REPO))};
            ide = import {REPO}/home/modules/gui/ide-flatpaks/lib.nix {{
              lib = flake.inputs.nixpkgs.lib;
              config = {{
                home.homeDirectory = {json.dumps(str(self.host))};
                xdg.configHome = {json.dumps(str(self.config))};
                xdg.dataHome = {json.dumps(str(self.host / ".local/share"))};
              }};
            }};
          in ide.mkFakeHomeGitBridge {json.dumps(str(self.private))}
        '''
        self.script = subprocess.check_output(
            ["nix", "eval", "--impure", "--raw", "--expr", expr], text=True)

    def write(self, path, contents):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)

    def activate(self, check=True):
        return subprocess.run(["bash", "-euc", self.script],
                              capture_output=True, text=True, check=check)

    def git_config(self, home, xdg=None, explicit=False):
        env = {k: v for k, v in os.environ.items()
               if not k.startswith("GIT_") and k != "XDG_CONFIG_HOME"}
        env["HOME"] = str(home)
        env["GIT_CONFIG_NOSYSTEM"] = "1"
        if xdg:
            env["XDG_CONFIG_HOME"] = str(xdg)
        if explicit:
            env["GIT_CONFIG_GLOBAL"] = str(self.host / ".gitconfig")
        return subprocess.check_output(
            ["git", "config", "--global", "--includes", "--list"], env=env, text=True)

    def test_fresh_home_matches_host_with_or_without_launcher_environment(self):
        self.activate()
        expected = self.git_config(self.host, self.config)
        self.assertIn("init.defaultbranch=main\n", expected)
        self.assertIn("user.name=Shared Author\n", expected)
        self.assertEqual(self.git_config(self.private), expected)
        self.assertEqual(self.git_config(self.private, self.private / ".config"), expected)
        # GIT_CONFIG_GLOBAL reads the host file's include without also reading
        # XDG Git config first. Effective settings must still be identical.
        self.assertEqual(set(self.git_config(self.private, explicit=True).splitlines()),
                         set(expected.splitlines()))
        self.assertTrue((self.private / ".config/gh").samefile(self.config / "gh"))

    def test_migration_and_repeated_activation_preserve_private_and_host_data(self):
        originals = {
            ".gitconfig": "[user]\n name = Old Private Author\n",
            ".config/git/config": "[init]\n defaultBranch = old\n",
            ".config/gh/config.yml": "git_protocol: https\n",
        }
        for path, contents in originals.items():
            self.write(self.private / path, contents)
        host_before = (self.host / ".gitconfig").read_bytes()
        self.activate()
        self.activate()
        self.assertEqual((self.private / ".gitconfig.app-private.bak").read_text(),
                         originals[".gitconfig"])
        for name in ["git", "gh"]:
            filename = "config" if name == "git" else "config.yml"
            backup = self.private / f".config/{name}.app-private.bak/{filename}"
            self.assertEqual(backup.read_text(), originals[f".config/{name}/{filename}"])
        self.assertEqual((self.host / ".gitconfig").read_bytes(), host_before)
        self.assertEqual(self.git_config(self.private), self.git_config(self.host, self.config))

    def test_existing_backup_conflict_does_not_overwrite_either_file(self):
        target = self.private / ".gitconfig"
        backup = self.private / ".gitconfig.app-private.bak"
        self.write(target, "private config\n")
        self.write(backup, "previous backup\n")
        result = self.activate(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot bridge", result.stderr)
        self.assertEqual(target.read_text(), "private config\n")
        self.assertEqual(backup.read_text(), "previous backup\n")

    def test_shared_github_directory_supports_atomic_config_updates(self):
        self.activate()
        directory = self.private / ".config/gh"
        temporary = directory / "config.yml.tmp"
        temporary.write_text("git_protocol: https\n")
        temporary.replace(directory / "config.yml")
        self.assertEqual((self.config / "gh/config.yml").read_text(),
                         "git_protocol: https\n")


if __name__ == "__main__":
    unittest.main()
