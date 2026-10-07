"""Boundaries of the local HTTP/root helper interface; no real network changes."""

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch
import urllib.request
import urllib.error

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location(
    "manager", Path(__file__).resolve().parents[1] / "home/files/n2n-web/manager.py"
)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class Validation(unittest.TestCase):
    def test_defaults_and_static_ip(self):
        self.assertEqual(m.validate(m.DEFAULT)["community"], "my-lan")
        self.assertEqual(
            m.validate(dict(m.DEFAULT, address="10.42.0.20/24"))["address"],
            "10.42.0.20/24",
        )

    def test_untrusted_configuration(self):
        for change in [
            dict(community="x\n-r"),
            dict(community="a" * 17),
            dict(server="host:7777\n-r"),
            dict(address="127.0.0.1/8"),
            dict(address="10.42.0.0/24"),
            dict(address="8.8.8.8/24"),
            dict(key="x\n-y"),
            dict(key=123),
        ]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                m.validate(dict(m.DEFAULT, **change))

    def test_custom_server_validation(self):
        self.assertEqual(m.endpoint("Example.COM:07777"), "example.com:7777")
        self.assertEqual(m.endpoint("192.168.1.5:7777"), "192.168.1.5:7777")
        for value in [
            "-x:77",
            "host:0",
            "host:65536",
            "host:77 -r",
            "https://host:77",
            "host..com:77",
            None,
        ]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                m.endpoint(value)

    def test_subscription_format_deduplication_and_failure(self):
        rows = [
            {"server": "one.example", "port": "7777"},
            {"server": "two.example", "port": 8888},
        ]
        self.assertEqual(
            m.parse_subscription(json.dumps(rows + rows)),
            ["one.example:7777", "two.example:8888"],
        )
        for body in [
            "<html>login</html>",
            "{}",
            "[]",
            "[null]",
            '[{"server":"host","port":70000}]',
        ]:
            with self.subTest(body=body), self.assertRaises(ValueError):
                m.parse_subscription(body)

    def test_subscription_url_boundary(self):
        self.assertEqual(
            m.subscription_url("https://example.com/private"),
            "https://example.com/private",
        )
        for value in [
            "http://example.com",
            "file:///etc/passwd",
            "https://user:password@example.com",
            "https://example.com/#x",
            None,
        ]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                m.subscription_url(value)

    def test_native_ping_validates_pong(self):
        group = b"my-lan".ljust(20, b"\0")
        good = m.struct.pack(
            "!BBH20sH6s6s", 3, 2, 42, group, 0, b"ABCDEF", bytes(6)
        ) + bytes(36)
        wrong_group = good[:4] + b"other".ljust(20, b"\0") + good[24:]
        with patch.object(m.socket, "socket") as factory:
            sock = factory.return_value.__enter__.return_value
            sock.recv.side_effect = [b"invalid", wrong_group, good, good]
            result = m.probe_server("example.com:7777", "my-lan")
            self.assertEqual(result["received"], 2)
            self.assertEqual(result["status"], "ok")
            packet = sock.send.call_args.args[0]
            version, ttl, kind, community, source, target, flags = m.struct.unpack(
                "!BBH20s6s6sH", packet
            )
            self.assertEqual(
                (version, kind, community, target), (3, 11, group, bytes(6))
            )

    def test_probe_timeout_and_concurrency_limit(self):
        with patch.object(m.socket, "socket") as factory:
            factory.return_value.__enter__.return_value.recv.side_effect = (
                TimeoutError()
            )
            self.assertEqual(
                m.probe_server("example.com:7777", "my-lan")["status"], "timeout"
            )
        probes = m.Probes()
        with patch.object(m.threading, "Thread") as thread:
            probes.request(["example.com:7777"], "my-lan")
            probes.request(["example.com:7777"], "my-lan", force=True)
            thread.assert_called_once()

    def test_root_invocation_is_bounded(self):
        with tempfile.TemporaryDirectory() as tmp:
            with (
                patch.object(m, "ROOT", Path(tmp)),
                patch.object(m.os, "geteuid", return_value=0),
                patch.object(m, "run") as run,
            ):
                run.return_value.returncode = 0
                with patch.object(m.sys, "stdin") as stdin:
                    stdin.read.return_value = json.dumps(m.DEFAULT)
                    m.privileged("connect")
                run.assert_called_once_with(
                    ["/usr/bin/systemctl", "restart", "n2n-lan.service"], timeout=30
                )
                self.assertEqual(
                    (Path(tmp) / "config.json").stat().st_mode & 0o777, 0o600
                )

    def test_catalog_updates_are_atomic_and_do_not_restart_vpn(self):
        with tempfile.TemporaryDirectory() as tmp:
            server = m.http.server.ThreadingHTTPServer(("127.0.0.1", 0), m.Handler)
            server.token = "test-token"
            server.catalog = Path(tmp) / "servers.json"
            server.lock = threading.Lock()
            worker = threading.Thread(target=server.serve_forever, daemon=True)
            worker.start()

            def post(action, data):
                req = urllib.request.Request(
                    f"http://127.0.0.1:{server.server_port}/api/{action}",
                    data=json.dumps(data).encode(),
                    headers={
                        "Host": f"127.0.0.1:{m.PORT}",
                        "X-N2N-Token": "test-token",
                        "Content-Type": "application/json",
                    },
                )
                with urllib.request.urlopen(req) as reply:
                    return json.load(reply)

            try:
                with patch.object(m, "run") as commands:
                    with patch.object(
                        m, "fetch_subscription", return_value=["one.example:7777"]
                    ):
                        d = post("subscription", {"url": "https://example.com/private"})
                    self.assertEqual(d["manual"], [])
                    d = post("server-add", {"server": "local.example:8888"})
                    self.assertIn("local.example:8888", d["servers"])
                    before = server.catalog.read_bytes()
                    with patch.object(
                        m,
                        "fetch_subscription",
                        side_effect=ValueError("download failed"),
                    ):
                        with self.assertRaises(urllib.error.HTTPError) as ctx:
                            post("subscription", {"url": "https://example.com/broken"})
                        ctx.exception.close()
                    self.assertEqual(server.catalog.read_bytes(), before)
                    with patch.object(
                        m, "fetch_subscription", return_value=["two.example:7777"]
                    ):
                        d = post("subscription", {"url": "https://example.com/private"})
                    self.assertEqual(
                        d["servers"], ["local.example:8888", "two.example:7777"]
                    )
                    d = post("server-remove", {"server": "local.example:8888"})
                    self.assertEqual(d["servers"], ["two.example:7777"])
                    self.assertEqual(server.catalog.stat().st_mode & 0o777, 0o600)
                    commands.assert_not_called()
            finally:
                server.shutdown()
                server.server_close()
                worker.join()

    def test_http_rejects_cross_site_and_missing_token(self):
        server = m.http.server.ThreadingHTTPServer(("127.0.0.1", 0), m.Handler)
        server.token = "test-token"
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            for headers in [
                {},
                {"Host": f"127.0.0.1:{m.PORT}"},
                {
                    "Host": f"127.0.0.1:{m.PORT}",
                    "X-N2N-Token": "test-token",
                    "Origin": "https://evil.example",
                },
            ]:
                req = urllib.request.Request(
                    f"http://127.0.0.1:{server.server_port}/api/connect",
                    data=b"{}",
                    headers=headers,
                )
                with self.assertRaises(urllib.error.HTTPError) as ctx:
                    urllib.request.urlopen(req)
                self.assertEqual(ctx.exception.code, 403)
                ctx.exception.close()
        finally:
            server.shutdown()
            server.server_close()
            worker.join()


if __name__ == "__main__":
    unittest.main()
