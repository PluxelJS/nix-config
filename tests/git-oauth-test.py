#!/usr/bin/env python3
"""Exercise credential migration and helper ordering without real tokens."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]


class OAuthConfigTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        expr = f'''
          let h = (builtins.getFlake {json.dumps("path:" + str(REPO))}).homeConfigurations.current;
          in {{
            migration = h.config.home.activation.migrateGitOAuthHelpers.data;
            gitConfig = h.config.xdg.configFile."git/config".text;
            helpers = h.config.programs.git.settings.credential.helper;
            home = h.config.home.homeDirectory;
          }}
        '''
        cls.data = json.loads(subprocess.check_output(
            ["nix", "eval", "--impure", "--json", "--expr", expr], text=True))

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="git-oauth-test-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.target = self.home / ".gitconfig"
        self.backup = self.home / ".gitconfig.pre-nix-oauth.bak"
        self.managed = self.home / ".config/git/config"
        self.managed.parent.mkdir(parents=True)
        self.managed.write_text(self.data["gitConfig"])
        self.script = self.data["migration"].replace(
            f'target="{self.data["home"]}/.gitconfig"',
            "target=" + shlex.quote(str(self.target)))
        self.original = (
            '[include]\n path = ' + str(self.managed) + '\n'
            '[user]\n name = Local Author\n email = author@example.test\n'
            '[credential]\n helper =\n helper = libsecret\n helper = oauth\n'
            '[credential "https://github.com"]\n helper =\n helper = !gh auth git-credential\n'
            '[credential "https://gist.github.com"]\n helper =\n helper = !gh auth git-credential\n'
        )
        self.target.write_text(self.original)
        self.target.chmod(0o600)

    def migrate(self):
        subprocess.run(["bash", "-euc", self.script], check=True,
                       capture_output=True, text=True)

    def test_migration_preserves_identity_and_backs_up_original(self):
        self.migrate()
        result = subprocess.check_output([
            "git", "config", "--file", str(self.target), "--list"], text=True)
        self.assertIn("user.name=Local Author", result)
        self.assertIn("user.email=author@example.test", result)
        self.assertIn("include.path=" + str(self.managed), result)
        self.assertNotIn("credential.", result)
        self.assertEqual(self.backup.read_text(), self.original)
        self.assertEqual(self.backup.stat().st_mode & 0o777, 0o600)
        migrated = self.target.read_bytes()
        self.migrate()
        self.assertEqual(self.target.read_bytes(), migrated)
        self.assertEqual(self.backup.read_text(), self.original)

    def test_custom_helpers_and_their_reset_are_preserved(self):
        self.target.write_text(self.original + (
            '[credential]\n helper = custom-global\n'
            '[credential "https://github.com"]\n helper = custom-github\n'
            '[credential "https://internal.example.test"]\n helper = custom-internal\n'
        ))
        self.migrate()
        for key, expected in [
            ("credential.helper", ["", "custom-global"]),
            ("credential.https://github.com.helper", ["", "custom-github"]),
            ("credential.https://internal.example.test.helper", ["custom-internal"]),
        ]:
            actual = subprocess.check_output([
                "git", "config", "--file", str(self.target), "--get-all", key], text=True)
            self.assertEqual(actual.splitlines(), expected)

    def test_existing_backup_is_not_overwritten(self):
        self.backup.write_text("previous backup\n")
        self.migrate()
        self.assertEqual(self.backup.read_text(), "previous backup\n")

    def test_symlinked_local_config_is_not_rewritten(self):
        original = self.home / "custom-config"
        self.target.rename(original)
        self.target.symlink_to(original)
        self.migrate()
        self.assertEqual(original.read_text(), self.original)
        self.assertTrue(self.target.is_symlink())
        self.assertFalse(self.backup.exists())

    def check_helper_chain(self, wallet_hit, expected):
        self.migrate()
        config = self.data["gitConfig"]
        for index, name in [(1, "wallet"), (2, "oauth")]:
            helper = self.home / name
            helper.write_text(
                '#!/bin/sh\n'
                f'printf "%s\\n" "{name}:$1" >> "$TEST_LOG"\n'
                f'if [ "{name}" = oauth ] || [ "$TEST_WALLET_HIT" = 1 ]; then\n'
                '  printf "username=test-user\\npassword=test-value\\n"\n'
                'fi\n'
            )
            helper.chmod(0o700)
            config = config.replace(self.data["helpers"][index], str(helper))
        self.managed.write_text(config)
        system = self.home / "system-gitconfig"
        system.write_text('[credential]\n helper = !echo inherited-helper-must-not-run >&2; exit 99\n')
        env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        env.update(HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / ".config"),
                   GIT_CONFIG_SYSTEM=str(system), GIT_TERMINAL_PROMPT="0",
                   TEST_LOG=str(self.home / "calls"), TEST_WALLET_HIT=str(int(wallet_hit)))
        result = subprocess.run(["git", "credential", "fill"],
                                input="protocol=https\nhost=github.com\n\n", env=env,
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stderr, "")
        self.assertIn("password=test-value\n", result.stdout)
        self.assertEqual((self.home / "calls").read_text().splitlines(), expected)

    def test_wallet_miss_calls_oauth_after_storage(self):
        self.check_helper_chain(False, ["wallet:get", "oauth:get"])

    def test_wallet_hit_avoids_oauth(self):
        self.check_helper_chain(True, ["wallet:get"])


if __name__ == "__main__":
    unittest.main()
