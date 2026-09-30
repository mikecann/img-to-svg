"""Exercise real conversion and the installed launcher without GPU/model downloads."""
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


class ConversionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="img-to-svg tests ")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)

    def run_cli(self, *args):
        return subprocess.run(
            [sys.executable, str(ROOT / "img-to-svg.py"), *map(str, args)],
            cwd=self.folder, capture_output=True, text=True,
        )

    def assert_svg(self, path):
        self.assertEqual(ET.parse(path).getroot().tag, "{http://www.w3.org/2000/svg}svg")
        self.assertGreater(path.stat().st_size, 100)

    def make_image(self, name):
        path = self.folder / name
        image = Image.new("RGB", (32, 32), "white")
        for x in range(8, 24):
            for y in range(8, 24):
                image.putpixel((x, y), (0, 0, 0))
        image.save(path)
        return path

    def test_formats_and_presets(self):
        for ext in ("png", "jpg", "webp"):
            source = self.make_image(f"input image.{ext}")
            for preset in ("poster", "photo", "bw"):
                with self.subTest(ext=ext, preset=preset):
                    result = self.run_cli(source, "--preset", preset)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assert_svg(source.with_suffix(".svg"))

    def test_explicit_output(self):
        source = self.make_image("input.png")
        output = self.folder / "different output.svg"
        result = self.run_cli(source, output)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_svg(output)
        self.assertFalse(source.with_suffix(".svg").exists())

    def test_missing_input_and_invalid_preset(self):
        result = self.run_cli("missing.png")
        self.assertEqual(result.returncode, 1)
        self.assertIn("File not found", result.stdout)
        result = self.run_cli("missing.png", "--preset", "unknown")
        self.assertEqual(result.returncode, 2)

    @unittest.skipUnless(sys.platform == "win32", "Windows bat launcher")
    def test_windows_bat_launcher(self):
        source = self.make_image("bat input.webp")
        result = subprocess.run(
            ["cmd.exe", "/c", str(ROOT / "img-to-svg.bat"), str(source)],
            cwd=self.folder, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_svg(source.with_suffix(".svg"))

    @unittest.skipIf(sys.platform == "win32", "POSIX symlink installer")
    def test_installed_launcher_from_another_directory(self):
        clone = self.folder / "clone with spaces"
        clone.mkdir()
        for name in ("install.sh", "uninstall.sh", "img-to-svg", "img-to-svg.py"):
            shutil.copy2(ROOT / name, clone / name)
        # Use the test interpreter to isolate launcher lookup from shell PATH.
        python_dir = clone / ".venv" / "bin"
        python_dir.mkdir(parents=True)
        interpreter = python_dir / "python3"
        interpreter.write_text(f'#!/bin/bash\nexec {shlex.quote(sys.executable)} "$@"\n')
        interpreter.chmod(0o755)
        target = self.folder / "bin with spaces"
        for _ in range(2):
            result = subprocess.run(
                ["bash", str(clone / "install.sh"), str(target), "--skip-deps"],
                cwd=self.folder, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        source = self.make_image("launcher input.webp")
        result = subprocess.run(
            [str(target / "img-to-svg"), str(source)], cwd=self.folder,
            env={**os.environ, "PATH": "/usr/bin:/bin"}, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_svg(source.with_suffix(".svg"))
        other = target / "other-tool"
        other.symlink_to(clone / "img-to-svg")
        result = subprocess.run(["bash", str(clone / "uninstall.sh"), str(target)])
        self.assertEqual(result.returncode, 0)
        self.assertFalse((target / "img-to-svg").is_symlink())
        self.assertTrue(other.is_symlink())
        # An install from a different clone must survive this clone's uninstall.
        (target / "img-to-svg").symlink_to(ROOT / "img-to-svg")
        subprocess.run(["bash", str(clone / "uninstall.sh"), str(target)], check=True)
        self.assertTrue((target / "img-to-svg").is_symlink())


if __name__ == "__main__":
    unittest.main()
