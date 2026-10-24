#!/usr/bin/env python3
"""Exercise the compiler preflight through disposable PATH-selected compilers."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


class SwiftCompilerPinTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        (self.root / "Scripts").mkdir()
        self.guard = self.root / "Scripts/check-swift-version.sh"
        shutil.copyfile(Path(__file__).with_name("check-swift-version.sh"), self.guard)
        self.pin = self.root / ".swift-version"
        self.pin.write_text("6.4\n")
        self.compiler = self.root / "swift"
        for command in ("dirname", "cat", "grep"):
            (self.root / command).symlink_to(shutil.which(command))
        self.environment = dict(os.environ, PATH=str(self.root))

    def run_guard(self, output="Swift version 6.4", exit_code=0):
        # repr is safe here because the fake executable is Python, not shell text.
        self.compiler.write_text(
            f"#!{os.sys.executable}\nimport sys\n"
            "assert sys.argv[1:] == ['--version']\n"
            f"print({output!r})\nsys.exit({exit_code})\n"
        )
        self.compiler.chmod(0o755)
        return subprocess.run(
            ["/bin/bash", str(self.guard)], env=self.environment,
            cwd="/", capture_output=True, text=True, check=False,
        )

    def test_accepts_release_compiler_forms(self):
        for output in (
            "swift-driver version: 1.168.6 Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)\nTarget: arm64-apple-macosx27.0.0",
            "Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)",
            "Apple Swift version 6.4.1 (swiftlang-6.4.1.1)",
            "Swift version 6.4", "Swift version 6.4.0 (swift-6.4-RELEASE)",
            "Swift version 6.4.12 (swift-6.4.12-RELEASE)\nTarget: x86_64-unknown-linux-gnu",
        ):
            with self.subTest(output=output):
                result = self.run_guard(output)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(output, result.stdout)

    def test_rejects_adjacent_versions_and_prereleases(self):
        for version in ("6.3", "6.5", "6.40", "6.4-dev", "6.4.1-dev", "6.4.0-dev", "6.4.0.1", "6.4-SNAPSHOT"):
            with self.subTest(version=version):
                result = self.run_guard(f"Swift version {version}")
                self.assertEqual(result.returncode, 2)
                self.assertIn("Expected Swift 6.4 release compiler", result.stderr)
        result = self.run_guard("Apple Swift version 6.4 (swift-DEVELOPMENT-SNAPSHOT-2026-10-23-a)")
        self.assertEqual(result.returncode, 2)

    def test_rejects_malformed_and_multiple_version_reports(self):
        for output in ("garbled Swift version 6.4", "Swift version", "6.4",
                       "Swift version 6.4\nSwift version 6.5",
                       "Swift version 6.4 Swift version 6.4"):
            with self.subTest(output=output):
                self.assertEqual(self.run_guard(output).returncode, 2)

    def test_rejects_failed_invocation_even_with_matching_output(self):
        result = self.run_guard("Swift version 6.4", exit_code=1)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unable to run", result.stderr)

    def test_rejects_missing_compiler(self):
        result = subprocess.run(["/bin/bash", str(self.guard)], env=self.environment,
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unable to run", result.stderr)

    def test_rejects_missing_pin_before_invoking_compiler(self):
        self.pin.unlink()
        result = self.run_guard()
        self.assertEqual(result.returncode, 2)
        self.assertIn("pin is missing", result.stderr)

    def test_rejects_changed_or_empty_pin(self):
        for pin in ("", "6.5\n", "6.4.0\n", "6.4\n6.5\n", "6.4\n\n"):
            with self.subTest(pin=pin):
                self.pin.write_text(pin)
                result = self.run_guard()
                self.assertEqual(result.returncode, 2)
                self.assertIn("Unsupported Swift compiler pin", result.stderr)


if __name__ == "__main__":
    unittest.main()
