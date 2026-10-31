#!/usr/bin/env python3
"""Offline regressions for reviewed-copy and downloaded-tool integrity boundaries."""

import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile


sys.dont_write_bytecode = True
SCRIPTS = Path(__file__).resolve().parent


def load_script(name):
    specification = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


copy_checker = load_script("verify-rules-copy")
swiftlint = load_script("prepare-swiftlint")


class ReviewedCopyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        source = self.directory / "Sources/Example.swift"
        source.parent.mkdir()
        source.write_bytes(b"reviewed source\n")
        self.receipt = {
            "schemaVersion": 1,
            "upstreamRepository": "Void-Deck/EngineeringRules",
            "upstreamPath": ".",
            "upstreamCommit": "b1ec7a16cdbce96b17a77eccc6384db3ec8708f7",
            "files": {"Sources/Example.swift": {
                "source": "Sources/Example.swift",
                "sha256": hashlib.sha256(b"reviewed source\n").hexdigest(),
            }},
        }
        self.write_receipt()

    def write_receipt(self):
        (self.directory / "reviewed-copy.json").write_text(json.dumps(self.receipt), encoding="utf-8")

    def test_accepts_exact_copy(self):
        self.assertEqual(copy_checker.verify_copy(self.directory), 1)

    def test_rejects_changed_source(self):
        (self.directory / "Sources/Example.swift").write_bytes(b"modified source\n")
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            copy_checker.verify_copy(self.directory)

    def test_rejects_missing_file(self):
        (self.directory / "Sources/Example.swift").unlink()
        with self.assertRaisesRegex(ValueError, "inventory differs"):
            copy_checker.verify_copy(self.directory)

    def test_rejects_extra_file_and_empty_directory(self):
        for name, is_directory in (("unreviewed.txt", False), (".build", True)):
            with self.subTest(name=name):
                path = self.directory / name
                if is_directory:
                    path.mkdir()
                else:
                    path.write_bytes(b"extra")
                with self.assertRaisesRegex(ValueError, "inventory differs"):
                    copy_checker.verify_copy(self.directory)
                if is_directory:
                    path.rmdir()
                else:
                    path.unlink()

    def test_rejects_source_and_receipt_symlinks(self):
        for name in ("Sources/Example.swift", "reviewed-copy.json"):
            with self.subTest(name=name):
                path = self.directory / name
                contents = path.read_bytes()
                path.unlink()
                path.symlink_to(self.directory / "outside")
                with self.assertRaises((OSError, ValueError)):
                    copy_checker.verify_copy(self.directory)
                path.unlink()
                path.write_bytes(contents)

    def test_rejects_different_release(self):
        self.receipt["upstreamCommit"] = "0" * 40
        self.write_receipt()
        with self.assertRaisesRegex(ValueError, "reviewed.*commit"):
            copy_checker.verify_copy(self.directory)

    def test_rejects_duplicate_json_key(self):
        path = self.directory / "reviewed-copy.json"
        path.write_text('{"schemaVersion":1,' + path.read_text()[1:], encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Duplicate receipt key"):
            copy_checker.verify_copy(self.directory)

    def test_rejects_receipt_path_escape(self):
        entry = self.receipt["files"].pop("Sources/Example.swift")
        self.receipt["files"]["../outside"] = entry
        self.write_receipt()
        with self.assertRaisesRegex(ValueError, "Invalid receipt path"):
            copy_checker.verify_copy(self.directory)


def tool_archive(entries):
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w") as archive:
        for name, contents in entries:
            archive.writestr(name, contents)
    return output.getvalue()


class SwiftLintIntegrityTests(unittest.TestCase):
    def test_digest_rejects_tampered_download(self):
        digest = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        self.assertEqual(swiftlint.verified_archive(b"abc", digest), b"abc")
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            swiftlint.verified_archive(b"abd", digest)

    def test_selects_binary_and_macos_libraries(self):
        contents = tool_archive([
            ("bin/swiftlint", b"executable"), ("lib/library.dylib", b"library"), ("LICENSE", b"license")])
        self.assertEqual(swiftlint.archive_tools(contents), {"swiftlint": b"executable", "library.dylib": b"library"})

    def test_rejects_archive_escape_links_and_duplicate_tools(self):
        link = zipfile.ZipInfo("linked")
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        cases = [
            [("../escape", b"bad")], [("/escape", b"bad")], [(link, b"target")],
            [("bin/swiftlint", b"first"), ("other/swiftlint", b"second")],
        ]
        for entries in cases:
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                swiftlint.archive_tools(tool_archive([("swiftlint", b"tool")] + entries))

    def test_rejects_archive_without_executable(self):
        with self.assertRaisesRegex(ValueError, "no executable"):
            swiftlint.archive_tools(tool_archive([("README", b"text")]))

    def test_verify_only_has_no_network_or_write_and_rejects_changed_binary(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            contents = tool_archive([("swiftlint", b"verified binary")])
            (directory / "fixture.zip").write_bytes(contents)
            binary = directory / "swiftlint"
            binary.write_bytes(b"verified binary")
            binary.chmod(0o755)
            digest = hashlib.sha256(contents).hexdigest()
            before = {path.name: path.read_bytes() for path in directory.iterdir()}
            with (patch.object(swiftlint, "DOWNLOADS", directory),
                  patch.object(swiftlint, "asset_for_host", return_value=("fixture.zip", digest)),
                  patch.object(swiftlint.urllib.request, "urlopen", side_effect=AssertionError("network access"))):
                swiftlint.prepare(directory, verify_only=True)
                self.assertEqual(before, {path.name: path.read_bytes() for path in directory.iterdir()})
                binary.write_bytes(b"unreviewed replacement")
                with self.assertRaisesRegex(ValueError, "differs from the pinned archive"):
                    swiftlint.prepare(directory, verify_only=True)

    def test_verify_only_rejects_missing_archive_without_network(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            with (patch.object(swiftlint, "DOWNLOADS", directory),
                  patch.object(swiftlint.urllib.request, "urlopen", side_effect=AssertionError("network access"))):
                with self.assertRaisesRegex(ValueError, "archive is missing"):
                    swiftlint.prepare(directory, verify_only=True)
            self.assertEqual(list(directory.iterdir()), [])


class GateEvidenceTests(unittest.TestCase):
    def test_failed_prerequisite_removes_stale_compiler_context(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scripts = root / "Scripts/ci"
            scripts.mkdir(parents=True)
            for name in ("check-rules.sh", "verify-rules-copy.py"):
                shutil.copy2(SCRIPTS / name, scripts / name)
            # Use the unmodified reviewed inventory; missing docs venv must stop
            # this run before any real compiler, package resolution or network.
            shutil.copytree(copy_checker.DEFAULT_COPY, root / "Vendor/EngineeringRules")
            context = root / ".build/swift-rules/compiler-context.json"
            context.parent.mkdir(parents=True)
            context.write_text("stale evidence", encoding="utf-8")
            commands = root / "bin"
            commands.mkdir()
            swift = commands / "swift"
            swift.write_text("#!/bin/sh\necho 'unexpected compiler invocation' >&2\nexit 99\n", encoding="utf-8")
            swift.chmod(0o755)
            environment = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ.get("PATH", ""))
            result = subprocess.run(["bash", str(scripts / "check-rules.sh")],
                                    capture_output=True, text=True, timeout=15, env=environment)
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn("prepare-rules.sh", result.stderr)
            self.assertFalse(context.exists())

    def test_failed_checker_version_cannot_pass_with_expected_stdout(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            scripts = root / "Scripts/ci"
            scripts.mkdir(parents=True)
            for name in ("check-rules.sh", "verify-rules-copy.py", "prepare-swiftlint.py"):
                shutil.copy2(SCRIPTS / name, scripts / name)
            shutil.copy2(SCRIPTS.parent / "check-swift-version.sh", scripts.parent / "check-swift-version.sh")
            (root / ".swift-version").write_text("6.4\n", encoding="utf-8")
            shutil.copytree(copy_checker.DEFAULT_COPY, root / "Vendor/EngineeringRules")
            gate = root / ".build/swift-rules"
            documentation_python = gate / "docs-venv/bin/python"
            documentation_python.parent.mkdir(parents=True)
            documentation_python.write_text("#!/bin/sh\nexit 99\n", encoding="utf-8")
            documentation_python.chmod(0o755)
            binaries = gate / "tool/release"
            binaries.mkdir(parents=True)
            checker = binaries / "swift-rules"
            checker.write_text("#!/bin/sh\nprintf '%s\\n' '0.2.1'\nexit 7\n", encoding="utf-8")
            checker.chmod(0o755)
            commands = root / "bin"
            commands.mkdir()
            swift = commands / "swift"
            # Simulate successful package builds without invoking SwiftPM.
            swift.write_text(
                "#!/bin/sh\n"
                "if [ \"$1\" = --version ]; then echo 'Swift version 6.4.0'; exit 0; fi\n"
                "if [ \"$1\" != build ]; then exit 99; fi\n"
                "for argument in \"$@\"; do\n"
                "  if [ \"$argument\" = --show-bin-path ]; then echo \"$RULES_TEST_BINARY_DIRECTORY\"; fi\n"
                "done\n", encoding="utf-8")
            swift.chmod(0o755)
            context = gate / "compiler-context.json"
            context.write_text("stale evidence", encoding="utf-8")
            # Exercise the portable gate path without requiring full Xcode.
            uname = commands / "uname"
            uname.write_text("#!/bin/sh\necho Linux\n", encoding="utf-8")
            uname.chmod(0o755)
            environment = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ.get("PATH", ""),
                               RULES_TEST_BINARY_DIRECTORY=str(binaries))
            result = subprocess.run(["bash", str(scripts / "check-rules.sh")],
                                    capture_output=True, text=True, timeout=15, env=environment)
            # Seven is emitted only by the failing checker version process. A
            # masked failure would continue into the missing SwiftLint archive.
            self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
            self.assertFalse(context.exists())


if __name__ == "__main__":
    unittest.main()
