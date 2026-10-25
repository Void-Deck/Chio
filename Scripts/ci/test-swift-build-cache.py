#!/usr/bin/env python3
"""Cache metadata and command-routing regressions; these do not build Swift."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location("swift_build_cache", Path(__file__).with_name("swift-build-cache.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
Cache = MODULE.SwiftBuildCache


class SwiftBuildCacheTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve() / "checkout"
        self.root.mkdir()
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.write(".gitignore", ".build/\n.swiftpm/\n*.generated.swift\n")
        self.write("Package.swift", "// manifest fixture\n")
        self.write("Package.resolved", '{"pins":[]}\n')
        self.write("Sources/Example.swift", "let answer = 42\n")
        self.write("Scripts/ci/verify.sh", "exit 0\n")
        self.write("Docs/Guide.md", "Docs are not compilation inputs.\n")
        subprocess.run(["git", "add", "."], cwd=self.root, check=True)
        # Metadata tests control the platform boundary; compiler discovery has
        # separate tests below and real builds remain a qualification requirement.
        self.environment = patch.object(Cache, "environment", return_value={"sdk": {}, "compiler": "fixture"})
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def write(self, relative, contents):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)
        return path

    def prepare(self):
        return Cache.prepare(self.root, "Void-Deck/Chio", "")

    def record(self):
        prepared = self.prepare()
        self.write(".build/ci-cache/tests/object.o", "test build")
        self.write(".build/ci-cache/products/object.o", "production build")
        Cache.record(self.root, prepared)
        return prepared

    def restore(self, prepared, is_exact_hit=True):
        with contextlib.redirect_stdout(io.StringIO()):
            return Cache.restore(self.root, prepared, is_exact_hit)

    def test_mtime_changes_and_docs_edits_reuse_key_but_never_restore_bytes(self):
        prepared = self.record()
        source = self.root / "Sources/Example.swift"
        original_timestamp = source.stat().st_mtime_ns
        os.utime(source, ns=(1_700_000_000_000_000_000, 1_700_000_000_000_000_000))
        self.write("Docs/Guide.md", "Changed documentation.\n")
        self.assertEqual(self.prepare()["key"], prepared["key"])
        self.assertTrue(self.restore(prepared))
        self.assertEqual(source.stat().st_mtime_ns, original_timestamp)
        self.assertEqual(source.read_text(), "let answer = 42\n")
        self.assertEqual((self.root / "Docs/Guide.md").read_text(), "Changed documentation.\n")
        self.assertEqual((self.root / ".build/ci-cache/tests/object.o").read_text(), "test build")
        self.assertEqual((self.root / ".build/ci-cache/products/object.o").read_text(), "production build")

    def test_changed_inputs_cannot_reuse_key_or_change_source_timestamps(self):
        prepared = self.record()
        for relative in ("Sources/Example.swift", "Package.resolved", "Package.swift", "Scripts/ci/verify.sh"):
            with self.subTest(relative=relative):
                target = self.root / relative
                original = target.read_text()
                target.write_text(original + "changed\n")
                timestamp = target.stat().st_mtime_ns
                self.assertNotEqual(self.prepare()["key"], prepared["key"])
                with self.assertRaisesRegex(ValueError, "inputs changed"):
                    self.restore(prepared)
                self.assertEqual(target.stat().st_mtime_ns, timestamp)
                self.assertEqual(target.read_text(), original + "changed\n")
                target.write_text(original)
        source = self.root / "Sources/Example.swift"
        source.chmod(0o755)
        self.assertNotEqual(self.prepare()["key"], prepared["key"])

    def test_new_deleted_ignored_generated_and_package_configuration_inputs(self):
        prepared = self.prepare()
        for relative in ("new-input.txt", "Sources/Model.generated.swift", ".swiftpm/configuration/mirrors.json"):
            with self.subTest(relative=relative):
                target = self.write(relative, "new input\n")
                self.assertNotEqual(self.prepare()["key"], prepared["key"])
                target.unlink()
                self.assertEqual(self.prepare()["key"], prepared["key"])
        subprocess.run(["git", "rm", "-f", "Sources/Example.swift"], cwd=self.root, check=True, capture_output=True)
        self.assertNotEqual(self.prepare()["key"], prepared["key"])
        (self.root / "Package.resolved").unlink()
        with self.assertRaises(ValueError):
            self.prepare()

    def test_repository_root_and_compiler_identity_isolate_keys(self):
        prepared = self.prepare()
        other_repository = Cache.prepare(self.root, "another/repository", "")
        self.assertNotEqual(other_repository["key"], prepared["key"])
        copied = self.root.parent / "other-checkout"
        shutil.copytree(self.root, copied)
        self.assertNotEqual(Cache.prepare(copied, "Void-Deck/Chio", "")["key"], prepared["key"])
        with self.assertRaisesRegex(ValueError, "Build path"):
            Cache.restore(copied, prepared, True)
        with patch.object(Cache, "environment", return_value={"sdk": {}, "compiler": "different"}):
            self.assertNotEqual(self.prepare()["key"], prepared["key"])
            with self.assertRaisesRegex(ValueError, "Compiler environment"):
                self.restore(prepared)

    def test_inventory_trust_is_scoped_to_the_requested_checkout(self):
        configuration = self.root.parent / "gitconfig"
        configuration.write_text("")
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith("GIT_CONFIG")}
        environment.update({"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": str(configuration),
                            "GIT_TEST_ASSUME_DIFFERENT_OWNER": "1", "LC_ALL": "C"})
        with patch.dict(os.environ, environment, clear=True):
            before = subprocess.run(["git", "ls-files"], cwd=self.root, capture_output=True, text=True)
            self.assertEqual(before.returncode, 128)
            self.assertIn("dubious ownership", before.stderr)
            inventory = Cache.inputs(self.root)
            self.assertEqual(set(inventory), {".gitignore", "Package.swift", "Package.resolved",
                                              "Sources/Example.swift", "Scripts/ci/verify.sh"})
            after = subprocess.run(["git", "ls-files"], cwd=self.root, capture_output=True, text=True)
            self.assertEqual(after.returncode, 128)
            self.assertIn("dubious ownership", after.stderr)
        self.assertEqual(configuration.read_text(), "")

    def test_miss_and_malformed_records_discard_only_owned_builds(self):
        prepared = self.record()
        record_path = self.root / Cache.cache_directory / Cache.record_name
        valid = json.loads(record_path.read_text())
        invalid_records = [None, [], {}, {**valid, "key": "wrong"}, {**valid, "inputs": {}},
                           {**valid, "timestamps": {}},
                           {**valid, "timestamps": {**valid["timestamps"], "../outside": 1}},
                           *[{**valid, "timestamps": {**valid["timestamps"], "Sources/Example.swift": bad}}
                             for bad in (True, "123", -1, 2**63)]]
        evidence = self.write(".build/ci-results/retained.xml", "evidence")
        rules = self.write(".build/swift-rules/compiler-context.json", "context")
        for record in invalid_records:
            with self.subTest(record=record):
                self.record()
                record_path.write_text(json.dumps(record))
                before = {name: (self.root / name).stat().st_mtime_ns for name in valid["inputs"]}
                self.assertFalse(self.restore(prepared))
                self.assertFalse((self.root / Cache.cache_directory).exists())
                self.assertEqual({name: (self.root / name).stat().st_mtime_ns for name in before}, before)
                self.assertEqual(evidence.read_text(), "evidence")
                self.assertEqual(rules.read_text(), "context")
        self.record()
        self.assertFalse(self.restore(prepared, False))
        self.assertEqual(evidence.read_text(), "evidence")

    def test_missing_build_role_and_record_are_cold_builds(self):
        for relative in (Cache.record_name, "tests", "products"):
            with self.subTest(relative=relative):
                prepared = self.record()
                target = self.root / Cache.cache_directory / relative
                if target.is_dir():
                    shutil.rmtree(target)
                else:
                    target.unlink()
                self.assertFalse(self.restore(prepared))
                self.assertFalse((self.root / Cache.cache_directory).exists())

    def test_symlink_ancestors_never_delete_or_write_outside_cache(self):
        prepared = self.prepare()
        outside = self.root.parent / "outside"
        outside.mkdir()
        marker = outside / "retained"
        marker.write_text("untouched")
        for relative in (".build", ".build/ci-cache"):
            with self.subTest(relative=relative):
                target = self.root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(outside, target_is_directory=True)
                for operation in (lambda: self.restore(prepared, False),
                                  lambda: Cache.record(self.root, prepared),
                                  self.prepare):
                    with self.assertRaisesRegex(ValueError, "Symlink"):
                        operation()
                self.assertEqual(marker.read_text(), "untouched")
                self.assertFalse((outside / Cache.record_name).exists())
                target.unlink()

    def test_symlink_record_is_discarded_without_following_target(self):
        prepared = self.record()
        outside = self.root.parent / "outside.json"
        outside.write_text("untouched")
        record = self.root / Cache.cache_directory / Cache.record_name
        record.unlink()
        record.symlink_to(outside)
        self.assertFalse(self.restore(prepared))
        self.assertEqual(outside.read_text(), "untouched")

    def test_symlink_sources_are_rejected_including_ignored_sources(self):
        outside = self.root.parent / "external.swift"
        outside.write_text("external")
        source = self.root / "Sources/Model.generated.swift"
        source.symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "Symlink"):
            self.prepare()

    def test_verification_always_runs_and_propagates_gate_failure(self):
        self.write("Scripts/ci/verify.sh", "printf 'ran\\n' >> .build/invocations; exit 7\n")
        prepared = self.record()
        self.assertTrue(self.restore(prepared))
        self.assertEqual(Cache.verify(self.root, prepared), 7)
        self.assertEqual(Cache.verify(self.root, prepared), 7)
        self.assertEqual((self.root / ".build/invocations").read_text(), "ran\nran\n")

    def test_gate_separates_build_roles_and_keeps_script_inputs_unchanged(self):
        scripts = Path(__file__).resolve().parent
        shutil.copyfile(scripts / "verify.sh", self.root / "Scripts/ci/verify.sh")
        shutil.copyfile(scripts.parent / "check-swift-version.sh", self.root / "Scripts/check-swift-version.sh")
        self.write(".swift-version", "6.4\n")
        shutil.copyfile(scripts / "terminal-smoke.py", self.root / "Scripts/ci/terminal-smoke.py")
        (self.root / "Scripts/maps").mkdir()
        shutil.copyfile(scripts.parent / "maps/terminal-probe.py", self.root / "Scripts/maps/terminal-probe.py")
        # Command doubles exercise real shell routing and parser imports without
        # compiling Swift, opening a PTY or running an HTTP fixture server.
        executable = self.write("bin/swift", "#!" + sys.executable + "\n" + '''
import json, pathlib, sys
arguments = sys.argv[1:]
with open(".build/commands.jsonl", "a") as log:
    log.write(json.dumps(arguments) + "\\n")
if arguments == ["--version"]:
    print("Swift version 6.4.0")
elif "--show-bin-path" in arguments:
    print(pathlib.Path("bin").resolve())
''')
        executable.chmod(0o755)
        for name in ("chio-dashboard", "chio-matrix"):
            self.write("bin/" + name, "#!/bin/sh\nexit 0\n").chmod(0o755)
        python = self.write("bin/python3", "#!" + sys.executable + "\n" + '''
import json, pathlib, subprocess, sys, time
arguments = sys.argv[1:]
with open(".build/python-commands.jsonl", "a") as log:
    log.write(json.dumps(arguments) + "\\n")
flags = []
while arguments and arguments[0].startswith("-"):
    flags.append(arguments.pop(0))
script = arguments.pop(0)
if script == "Scripts/maps/terminal-probe.py":
    imported = subprocess.run([sys.executable, "-E", *flags, "-c", IMPORT_PARSER,
                               script, *flags], capture_output=True, text=True)
    if imported.returncode:
        sys.stderr.write(imported.stderr)
        raise SystemExit(imported.returncode)
    with open(".build/parser-imports.jsonl", "a") as log:
        log.write(imported.stdout)
elif script == "Scripts/maps/online-fixture-server.py" and "--ready-file" in arguments:
    for option in ("--config-file", "--ready-file"):
        pathlib.Path(arguments[arguments.index(option) + 1]).write_text("{}")
    while True:
        time.sleep(60)
'''.replace("IMPORT_PARSER", repr('''
import json, pathlib, runpy, sys
# Some host Python installations disable writes by default. The unflagged
# control must permit writes; -B invocations keep the real interpreter setting.
if "-B" not in sys.argv[2:]:
    sys.dont_write_bytecode = False
sys.pycache_prefix = None
parser = runpy.run_path(sys.argv[1])["shared_parser"]()
assert parser.screen(b"Ready").startswith("Ready")
# Python 3.15 no longer sets this legacy attribute. Exercise that boundary
# on older interpreters too, while retaining the real import and cache file.
parser.__dict__.pop("__cached__", None)
bytecode = pathlib.Path(parser.__spec__.cached)
print(json.dumps({"bytecode": str(bytecode), "generated": bytecode.is_file()}))
''')))
        python.chmod(0o755)
        self.write("bin/uname", "#!/bin/sh\nprintf 'Linux\\n'\n").chmod(0o755)
        environment = {**os.environ, "PATH": str(self.root / "bin") + os.pathsep + os.environ["PATH"],
                       "SWIFT_BUILD_JOBS": "2"}
        prepared = self.record()
        result = subprocess.run(["bash", "Scripts/ci/verify.sh"], cwd=self.root, env=environment,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        python_commands = [json.loads(line) for line in
                           (self.root / ".build/python-commands.jsonl").read_text().splitlines()]
        map_probes = [command for command in python_commands if "Scripts/maps/terminal-probe.py" in command]
        self.assertEqual(len(map_probes), 4)
        imports = [json.loads(line) for line in (self.root / ".build/parser-imports.jsonl").read_text().splitlines()]
        self.assertEqual(len(imports), 4)
        self.assertFalse(any(imported["generated"] for imported in imports), imports)
        self.assertEqual(self.prepare(), prepared)
        Cache.record(self.root, prepared)
        parser_source = self.root / "Scripts/ci/terminal-smoke.py"
        parser_source.write_text(parser_source.read_text() + "\n# Changed script input.\n")
        self.assertNotEqual(self.prepare()["key"], prepared["key"])
        with self.assertRaisesRegex(ValueError, "inputs changed"):
            Cache.record(self.root, prepared)
        commands = [json.loads(line) for line in (self.root / ".build/commands.jsonl").read_text().splitlines()]
        tests = [command for command in commands if command[0] == "test"]
        products = [command for command in commands if "--product" in command]
        paths = [command for command in commands if "--show-bin-path" in command]
        self.assertEqual(len(tests), 2)
        self.assertEqual([command[command.index("--product") + 1] for command in products],
                         ["chio-dashboard", "chio-matrix", "chio-maps"])
        self.assertEqual(len(paths), 3)
        for command in tests + products + paths:
            expected_path = ".build/ci-cache/tests" if command[0] == "test" else ".build/ci-cache/products"
            self.assertEqual(command[command.index("--scratch-path") + 1], expected_path)
            self.assertEqual(command[command.index("-c") + 1], "release")
            self.assertNotIn("--build-system", command)
            if command not in paths:
                self.assertIn("--force-resolved-versions", command)
                self.assertEqual(command[command.index("--jobs") + 1], "2")
        for command in tests:
            self.assertIn("--no-parallel", command)
        self.assertEqual(tests[0][tests[0].index("--filter") + 1], "MapHTTPClientTests|OnlineMapInteractionTests")
        self.assertNotIn("--filter", tests[1])

        unflagged_import = subprocess.run([sys.executable, str(python), "Scripts/maps/terminal-probe.py"],
                                          cwd=self.root, capture_output=True, text=True)
        self.assertEqual(unflagged_import.returncode, 0, unflagged_import.stderr)
        imported = json.loads((self.root / ".build/parser-imports.jsonl").read_text().splitlines()[-1])
        self.assertTrue(imported["generated"])
        self.assertTrue(Path(imported["bytecode"]).is_file())

        parser_source.write_text('raise RuntimeError("parser import failure fixture")\n')
        failed_import = subprocess.run([sys.executable, str(python), "-B", "Scripts/maps/terminal-probe.py"],
                                       cwd=self.root, capture_output=True, text=True)
        self.assertNotEqual(failed_import.returncode, 0)
        self.assertIn("RuntimeError: parser import failure fixture", failed_import.stderr)


class CompilerIdentityTests(unittest.TestCase):
    def test_build_environment_changes_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary).resolve()
            for name in ("swift", "swift-frontend", "clang"):
                (directory / name).write_text("compiler fixture")
            image = "docker.io/library/swift:6.4.0-noble@sha256:" + "a" * 64
            def command_output(arguments):
                if "-print-target-info" in arguments:
                    return '{"target":{"triple":"x86_64-unknown-linux-gnu"}}'
                return "fixture version"
            with patch.object(MODULE.shutil, "which", return_value=str(directory / "swift")), \
                 patch.object(MODULE.platform, "system", return_value="Linux"), \
                 patch.object(Cache, "output", side_effect=command_output), \
                 patch.object(Path, "read_text", return_value="fixture os"), \
                 patch.dict(os.environ, {}, clear=True):
                before = Cache.environment(image)
                for name in ("SWIFT_BUILD_JOBS", "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "PKG_CONFIG_LIBDIR", "CFLAGS"):
                    with self.subTest(variable=name), patch.dict(os.environ, {name: "different"}):
                        self.assertNotEqual(Cache.environment(image), before)
                self.assertNotEqual(Cache.environment(image.replace("a" * 64, "b" * 64)), before)
                with self.assertRaisesRegex(ValueError, "digest-pinned"):
                    Cache.environment("swift:latest")


if __name__ == "__main__":
    unittest.main()
