import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest


SCRIPT = (
    Path(__file__).resolve().parents[1] / "home/files/mango/scripts/session-start.sh"
)


class MangoSessionTest(unittest.TestCase):
    def run_startup(self, *, fail_import=False, with_socket=True):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "calls"
            for command in ("systemctl", "dbus-update-activation-environment"):
                stub = root / command
                stub.write_text(
                    "#!/bin/sh\n"
                    'printf "%s %s\\n" "${0##*/}" "$*" >> "$CALL_LOG"\n'
                    'if [ "${FAIL_IMPORT:-}" = 1 ] && '
                    '[ "${0##*/}" = dbus-update-activation-environment ] && '
                    '[ "$1" = --systemd ]; then exit 1; fi\n'
                )
                stub.chmod(0o755)
            env = dict(
                os.environ,
                PATH=f"{root}:/usr/bin:/bin",
                XDG_RUNTIME_DIR=directory,
                WAYLAND_DISPLAY="wayland-test",
                CALL_LOG=str(log),
                FAIL_IMPORT="1" if fail_import else "0",
            )
            with socket.socket(socket.AF_UNIX) as wayland:
                if with_socket:
                    wayland.bind(str(root / "wayland-test"))
                result = subprocess.run(
                    ["/bin/sh", str(SCRIPT)], env=env, capture_output=True, text=True
                )
            return (
                result.returncode,
                log.read_text().splitlines() if log.exists() else [],
            )

    def test_import_completes_before_target_and_dms_start(self):
        code, calls = self.run_startup()
        self.assertEqual(code, 0)
        imported = next(
            i
            for i, call in enumerate(calls)
            if call.startswith("dbus-update-activation-environment --systemd ")
        )
        target = calls.index("systemctl --user start mango-session.target")
        dms = calls.index("systemctl --user start dms.service")
        self.assertLess(imported, target)
        self.assertLess(target, dms)

    def test_failed_environment_import_never_starts_services(self):
        code, calls = self.run_startup(fail_import=True)
        self.assertNotEqual(code, 0)
        self.assertFalse(
            any(" start " in call or " restart " in call for call in calls)
        )

    def test_missing_wayland_socket_does_not_touch_systemd(self):
        code, calls = self.run_startup(with_socket=False)
        self.assertNotEqual(code, 0)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
