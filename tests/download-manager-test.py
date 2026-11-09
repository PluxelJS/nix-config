"""Exercise the packaged MDM CLI and browser host with isolated local state.

MDM_PACKAGE=$(nix build --no-link --print-out-paths 'path:.#misterdownloadmanager') \
  python3 tests/download-manager-test.py
"""
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import threading
import unittest


PACKAGE = os.environ.get("MDM_PACKAGE")


@unittest.skipUnless(PACKAGE, "Set MDM_PACKAGE to the built package")
class DownloadManagerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.env = os.environ | {
            "HOME": str(self.root),
            "XDG_CONFIG_HOME": str(self.root / ".config"),
            "XDG_DATA_HOME": str(self.root / ".local/share"),
            "MDM_DATA_DIR": str(self.root / "mdm"),
        }

    def run_program(self, name, *args, data=None, check=True):
        return subprocess.run(
            [str(Path(PACKAGE) / "bin" / name), *args],
            input=data, capture_output=True, env=self.env, timeout=30, check=check,
        )

    def test_registration_writes_reachable_hosts_for_gecko_and_chromium(self):
        # MDM discovers installed browser data folders; no real profile is used.
        (self.root / ".zen").mkdir()
        (self.root / ".config/google-chrome").mkdir(parents=True)
        self.run_program("misterdownloadmanager-nmhost", "--register")
        for directory, allowed in [
            (".mozilla/native-messaging-hosts", "allowed_extensions"),
            (".config/google-chrome/NativeMessagingHosts", "allowed_origins"),
        ]:
            with self.subTest(browser=directory):
                path = self.root / directory / "com.misterdownloadmanager.host.json"
                manifest = json.loads(path.read_text())
                self.assertEqual(manifest["name"], "com.misterdownloadmanager.host")
                self.assertEqual(manifest["type"], "stdio")
                self.assertTrue(os.access(manifest["path"], os.X_OK))
                # The real host named by registration must work without a wrapper's environment.
                request = json.dumps({"rules": True}).encode()
                caller = "chrome-extension://ejoleppdfgjdndddcjoehopknmlglojp/"
                caller_args = (
                    [str(path), "integration@misterdownloadmanager.com"]
                    if allowed == "allowed_extensions" else [caller]
                )
                reply = subprocess.run(
                    [manifest["path"], *caller_args],
                    input=struct.pack("<I", len(request)) + request,
                    capture_output=True, env=self.env, check=True, timeout=10,
                ).stdout
                length, = struct.unpack("<I", reply[:4])
                self.assertEqual(length, len(reply) - 4)
                self.assertTrue(json.loads(reply[4:])["ok"])
                if allowed == "allowed_extensions":
                    self.assertIn("integration@misterdownloadmanager.com", manifest[allowed])
                else:
                    self.assertIn(caller, manifest[allowed])

    def test_native_host_refuses_an_unregistered_extension(self):
        result = self.run_program(
            "misterdownloadmanager-nmhost", "unknown@example.invalid", check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"refusing caller", result.stderr)

    def test_cli_downloads_local_file_and_checks_its_sha256(self):
        payload = bytes(range(256)) * 4096
        checksum = hashlib.sha256(payload).hexdigest()

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass

            def do_HEAD(self):
                self.respond(body=False)

            def do_GET(self):
                self.respond(body=True)

            def respond(self, body):
                start, end = 0, len(payload) - 1
                partial = self.headers.get("Range")
                if partial:
                    first, last = partial.removeprefix("bytes=").split("-", 1)
                    start = int(first)
                    end = int(last) if last else end
                self.send_response(206 if partial else 200)
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Content-Length", str(end - start + 1))
                self.send_header("ETag", '"mdm-nix-test"')
                if partial:
                    self.send_header("Content-Range", f"bytes {start}-{end}/{len(payload)}")
                self.end_headers()
                if body:
                    self.wfile.write(payload[start:end + 1])

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            output = self.root / "download.bin"
            self.run_program(
                "misterdownloadmanager-cli", "get",
                f"http://127.0.0.1:{server.server_port}/payload.bin",
                "--direct", "--connections", "4", "--output", str(output),
                "--checksum", f"sha256:{checksum}",
            )
            self.assertEqual(output.read_bytes(), payload)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
