"""Validate all repository includes using the installed Mango 0.18+ parser."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "home/files/mango"


@unittest.skipUnless(shutil.which("mango"), "Mango is not installed")
class MangoConfigTest(unittest.TestCase):
    def test_complete_config_has_no_errors_or_binding_conflicts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "mango"
            shutil.copytree(SOURCE, root)
            for path in root.rglob("*.conf"):
                path.write_text(path.read_text().replace("~/.config/mango", str(root)))
            result = subprocess.run(
                ["mango", "-p", "-c", str(root / "config.conf")],
                capture_output=True, text=True, timeout=15,
            )
            output = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + result.stderr)
            self.assertEqual(result.returncode, 0, output)
            # Mango can return zero even when it reports invalid config keys.
            self.assertNotRegex(output, r"\[(ERROR|WARN)\]")


if __name__ == "__main__":
    unittest.main()
