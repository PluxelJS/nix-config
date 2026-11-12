#!/usr/bin/env python3
"""Opt-in wallet integration tests; use only unique .invalid test credentials.

CODESTUDIO_TEST_INSTANCE=<flatpak instance> CODESTUDIO_TEST_ENV_PID=<editor pid> \
  python3 tests/git-wallet-flatpak-test.py

The PID supplies the running editor's HOME/XDG/PATH/bus environment. Every
credential is deleted in cleanup. No existing credentials are read or printed.
"""
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import time
import unittest
import uuid


REPO = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.environ.get("CODESTUDIO_TEST_INSTANCE") and
                     os.environ.get("CODESTUDIO_TEST_ENV_PID"),
                     "requires an unlocked wallet and running Code Studio")
class FlatpakWalletTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        expr = f'''
          let h = (builtins.getFlake {json.dumps("path:" + str(REPO))}).homeConfigurations.current;
          in {{
            gitConfig = h.config.xdg.configFile."git/config".text;
            helpers = h.config.programs.git.settings.credential.helper;
          }}
        '''
        cls.config = json.loads(subprocess.check_output(
            ["nix", "eval", "--impure", "--json", "--expr", expr], text=True))
        cls.wallet = cls.config["helpers"][1]
        proc = Path("/proc") / os.environ["CODESTUDIO_TEST_ENV_PID"] / "environ"
        env = dict(entry.decode().split("=", 1)
                   for entry in proc.read_bytes().split(b"\0") if b"=" in entry)
        keys = {"HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME",
                "XDG_RUNTIME_DIR", "PATH", "DBUS_SESSION_BUS_ADDRESS"}
        cls.editor_env = {k: v for k, v in env.items() if k in keys}
        cls.prefix = ["flatpak", "enter", os.environ["CODESTUDIO_TEST_INSTANCE"],
                      "env"] + [k + "=" + v for k, v in cls.editor_env.items()]

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(
            prefix="git-wallet-test-", dir=self.editor_env["XDG_CACHE_HOME"])
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.query = f"protocol=https\nhost={uuid.uuid4().hex}.invalid:10001\n"
        self.addCleanup(self.run_wallet, "erase", self.query + "\n")
        self.expiry = str(int(time.time()) + 3600)
        self.log = self.root / "oauth.calls"
        oauth = self.root / "oauth"
        oauth.write_text(
            "#!/bin/sh\n"
            'input=$(cat)\n'
            'if [ "$1" = get ]; then\n'
            f'  printf "get\\n" >> {shlex.quote(str(self.log))}\n'
            '  case "$input" in *oauth_refresh_token=fake-refresh-token*)\n'
            f'    printf "refresh\\n" >> {shlex.quote(str(self.log))};; esac\n'
            '  printf "username=oauth2\\npassword=fake-access-token\\n'
            f'password_expiry_utc={self.expiry}\\n'
            'oauth_refresh_token=fake-refresh-token\\n"\n'
            'fi\n')
        oauth.chmod(0o700)
        config = self.root / "gitconfig"
        config.write_text(self.config["gitConfig"].replace(
            self.config["helpers"][2], str(oauth)))
        self.git = self.prefix + [
            "GIT_CONFIG_NOSYSTEM=1", "GIT_CONFIG_GLOBAL=" + str(config),
            "GIT_TERMINAL_PROMPT=0", "git", "credential"]

    def run_wallet(self, action, payload, sandbox=False):
        command = (self.prefix if sandbox else []) + [self.wallet, action]
        return subprocess.run(command, input=payload, capture_output=True,
                              text=True, check=True, timeout=15).stdout

    def credential(self, action, payload):
        return subprocess.run(self.git + [action], input=payload,
                              capture_output=True, text=True, check=True,
                              timeout=15).stdout

    def test_sandbox_approval_survives_next_process_and_reject_erases(self):
        first = self.credential("fill", self.query + "\n")
        self.credential("approve", first + "\n")
        second = self.credential("fill", self.query + "\n")
        self.assertEqual(first, second)
        self.assertEqual(self.log.read_text().splitlines(), ["get"])
        for sandbox in [False, True]:
            stored = self.run_wallet("get", self.query + "\n", sandbox=sandbox)
            self.assertIn("password=fake-access-token\n", stored)
            self.assertIn("oauth_refresh_token=fake-refresh-token\n", stored)
            self.assertIn("password_expiry_utc=" + self.expiry + "\n", stored)
        self.credential("reject", second + "\n")
        self.assertNotIn("password=", self.run_wallet("get", self.query + "\n"))

    def test_host_saved_credential_avoids_oauth_in_sandbox(self):
        self.run_wallet("store", self.query +
                        "username=oauth2\npassword=fake-host-token\n\n")
        result = self.credential("fill", self.query + "\n")
        self.assertIn("password=fake-host-token\n", result)
        self.assertFalse(self.log.exists())

    def test_expired_token_passes_refresh_token_and_saves_replacement(self):
        self.run_wallet("store", self.query +
                        "username=oauth2\npassword=fake-expired-token\n"
                        "password_expiry_utc=1\noauth_refresh_token=fake-refresh-token\n\n")
        result = self.credential("fill", self.query + "\n")
        self.assertEqual(self.log.read_text().splitlines(), ["get", "refresh"])
        self.credential("approve", result + "\n")
        self.credential("fill", self.query + "\n")
        self.assertEqual(self.log.read_text().splitlines(), ["get", "refresh"])
        self.assertIn("password=fake-access-token\n",
                      self.run_wallet("get", self.query + "\n"))


if __name__ == "__main__":
    unittest.main()
