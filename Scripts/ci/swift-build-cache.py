#!/usr/bin/env python3
"""Reuse Swift build products only for identical inputs and compiler environments.

Actions owns archive transport and repository/ref isolation. This helper owns
only .build/ci-cache, never source contents, test results or verification evidence.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys


class SwiftBuildCache:
    schema = 1
    key_prefix = "chio-swift-v1-"
    cache_directory = Path(".build/ci-cache")
    record_name = "source-timestamps.json"
    # Neither the manifest nor verification reads these as build inputs.
    # Unknown paths, including all source-root READMEs, remain inputs.
    excluded_roots = {"Docs"}
    excluded_files = {"README.md", "AGENTS.md", "LICENSE", ".github/PULL_REQUEST_TEMPLATE.md"}
    source_roots = ("Sources", "Examples", "Tests", "Spikes", ".swiftpm/configuration")

    @staticmethod
    def digest(value):
        encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
        return hashlib.sha256(encoded).hexdigest()

    @staticmethod
    def file_digest(path):
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    @staticmethod
    def output(arguments):
        return subprocess.run(arguments, check=True, capture_output=True, text=True).stdout.strip()

    @staticmethod
    def reject_symlink(path):
        if any(parent.is_symlink() for parent in (path, *path.parents)):
            raise ValueError("Symlink path is unsupported: " + str(path))

    @classmethod
    def inputs(cls, root):
        # Container jobs can run as a different user from the checkout owner.
        # Trust this checkout for this command without changing global Git state.
        listed = subprocess.run(
            ["git", "-c", "safe.directory=" + str(root), "ls-files", "-z",
             "--cached", "--others", "--exclude-standard"],
            cwd=root, check=True, capture_output=True,
        ).stdout.decode().split("\0")
        paths = set(listed) - {""}
        # Generated/ignored source and package configuration can affect builds too.
        # Do not follow symlinks, or inventory SwiftPM's own scratch directories.
        for relative in cls.source_roots:
            directory = root / relative
            cls.reject_symlink(directory)
            for parent, directories, files in os.walk(directory):
                for name in directories:
                    cls.reject_symlink(Path(parent) / name)
                paths.update(str((Path(parent) / name).relative_to(root)) for name in files)
        inputs = {}
        for relative in sorted(paths):
            path = Path(relative)
            if path.parts[0] in cls.excluded_roots or relative in cls.excluded_files:
                continue
            if path.is_absolute() or ".." in path.parts:
                raise ValueError("Invalid build input path")
            target = root / path
            cls.reject_symlink(target)
            if not target.is_file():
                raise ValueError("Missing regular build input: " + relative)
            inputs[relative] = {"sha256": cls.file_digest(target), "mode": target.stat().st_mode & 0o777}
        if not {"Package.swift", "Package.resolved"} <= inputs.keys():
            raise ValueError("Package.swift and Package.resolved are required")
        return inputs

    @classmethod
    def environment(cls, image):
        selected = shutil.which("swift")
        if selected is None:
            raise ValueError("Missing Swift compiler")
        # Keep argv[0]: the driver selects its mode from the swift symlink name.
        swift = Path(selected).absolute()
        system = platform.system()
        if system == "Darwin":
            frontend = Path(cls.output(["xcrun", "--find", "swift-frontend"]))
            clang = Path(cls.output(["xcrun", "--find", "clang"]))
            sdk_path = Path(cls.output(["xcrun", "--sdk", "macosx", "--show-sdk-path"]))
            sdk = {
                "path": str(sdk_path.resolve()),
                "build": cls.output(["xcrun", "--sdk", "macosx", "--show-sdk-build-version"]),
                "settings": cls.file_digest(sdk_path / "SDKSettings.json"),
                "xcode": cls.output(["xcodebuild", "-version"]),
            }
        elif system == "Linux":
            if not re.fullmatch(r"docker\.io/library/swift:[\w.-]+@sha256:[0-9a-f]{64}", image):
                raise ValueError("Linux cache requires the digest-pinned Swift job image")
            frontend = swift.parent / "swift-frontend"
            clang = swift.parent / "clang"
            sdk = {
                "image": image,
                "os": Path("/etc/os-release").read_text(),
                "packages": cls.output(["dpkg-query", "-W", "-f=${Package}=${Version}\\n"]),
            }
        else:
            raise ValueError("Unsupported cache platform")
        names = {
            "PATH", "HOME", "SDKROOT", "DEVELOPER_DIR", "TOOLCHAINS", "CC", "CXX",
            "CFLAGS", "CXXFLAGS", "CPPFLAGS", "LDFLAGS", "CPATH", "LIBRARY_PATH",
            "C_INCLUDE_PATH", "CPLUS_INCLUDE_PATH", "OBJC_INCLUDE_PATH",
            "MACOSX_DEPLOYMENT_TARGET", "LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH",
            "DYLD_FRAMEWORK_PATH", "PKG_CONFIG", "SOURCE_DATE_EPOCH",
        }
        variables = {key: value for key, value in os.environ.items()
                     if key in names or key.startswith(("SWIFT", "CLANG", "LLVM", "PKG_CONFIG_"))}
        return {
            "system": system, "architecture": platform.machine(), "sdk": sdk,
            "compilerPath": str(swift), "compilerBinary": str(swift.resolve(strict=True)),
            "compiler": cls.file_digest(swift), "frontend": cls.file_digest(frontend),
            "clang": cls.file_digest(clang), "version": cls.output([str(swift), "--version"]),
            "target": json.loads(cls.output([str(swift), "-print-target-info"])),
            "variables": variables,
            # verify.sh owns the actual commands and is itself a hashed input.
            "builds": {"backend": "default", "configuration": "release",
                       "tests": ".build/ci-cache/tests", "products": ".build/ci-cache/products"},
        }

    @classmethod
    def prepare(cls, root, repository, image):
        cls.reject_symlink(root / cls.cache_directory)
        identity = {"schema": cls.schema, "repository": repository, "root": str(root),
                    "environment": cls.environment(image), "inputs": cls.inputs(root)}
        return {"key": cls.key_prefix + cls.digest(identity), "identity": identity}

    @classmethod
    def checked_inputs(cls, root, prepared):
        identity = prepared["identity"]
        if identity["root"] != str(root) or identity["schema"] != cls.schema:
            raise ValueError("Build path or cache schema changed")
        if prepared["key"] != cls.key_prefix + cls.digest(identity):
            raise ValueError("Invalid cache identity")
        inputs = cls.inputs(root)
        if inputs != identity["inputs"]:
            raise ValueError("Build inputs changed after cache preparation")
        return inputs

    @classmethod
    def checked_environment(cls, prepared):
        environment = prepared["identity"]["environment"]
        if cls.environment(environment["sdk"].get("image", "")) != environment:
            raise ValueError("Compiler environment changed after cache preparation")

    @classmethod
    def discard(cls, root):
        directory = root / cls.cache_directory
        cls.reject_symlink(directory)
        if directory.exists():
            shutil.rmtree(directory)

    @classmethod
    def restore(cls, root, prepared, is_exact_hit):
        inputs = cls.checked_inputs(root, prepared)
        cls.checked_environment(prepared)
        directory = root / cls.cache_directory
        cls.reject_symlink(directory)
        try:
            if not is_exact_hit:
                raise ValueError("No exact cache hit")
            record_path = directory / cls.record_name
            cls.reject_symlink(record_path)
            record = json.loads(record_path.read_text())
            if record["key"] != prepared["key"] or record["inputs"] != inputs:
                raise ValueError("Cache record does not match current inputs")
            timestamps = record["timestamps"]
            if not isinstance(timestamps, dict) or set(timestamps) != set(inputs):
                raise ValueError("Incomplete cached timestamps")
            if any(type(value) is not int or value < 0 or value > 2**63 - 1 for value in timestamps.values()):
                raise ValueError("Invalid cached timestamps")
            for role in ("tests", "products"):
                cls.reject_symlink(directory / role)
                if not (directory / role).is_dir():
                    raise ValueError("Missing build role: " + role)
        except (OSError, ValueError, KeyError, TypeError) as error:
            cls.discard(root)
            print("swift-build-cache: cold build: " + str(error))
            return False
        # Validate the entire record before changing any input metadata.
        try:
            for relative, timestamp in timestamps.items():
                target = root / relative
                os.utime(target, ns=(target.stat().st_atime_ns, timestamp), follow_symlinks=False)
        except (OSError, OverflowError) as error:
            cls.discard(root)
            print("swift-build-cache: cold build: timestamp restoration failed: " + str(error))
            return False
        print("swift-build-cache: exact inputs restored; the full gate still runs")
        return True

    @classmethod
    def record(cls, root, prepared):
        inputs = cls.checked_inputs(root, prepared)
        cls.checked_environment(prepared)
        directory = root / cls.cache_directory
        for role in ("tests", "products"):
            cls.reject_symlink(directory / role)
            if not (directory / role).is_dir():
                raise ValueError("Missing build role: " + role)
        record = {"key": prepared["key"], "inputs": inputs,
                  "timestamps": {relative: (root / relative).stat().st_mtime_ns for relative in inputs}}
        target = directory / cls.record_name
        cls.reject_symlink(target)
        target.write_text(json.dumps(record, sort_keys=True) + "\n")

    @classmethod
    def verify(cls, root, prepared):
        cls.checked_inputs(root, prepared)
        cls.checked_environment(prepared)
        cls.reject_symlink(root / cls.cache_directory)
        return subprocess.run(["bash", "Scripts/ci/verify.sh"], cwd=root, check=False).returncode

    @classmethod
    def main(cls):
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("operation", choices=["prepare", "restore", "record", "verify"])
        parser.add_argument("--identity", type=Path, required=True, help="Job-local file outside the checkout")
        parser.add_argument("--repository", default="Void-Deck/Chio")
        parser.add_argument("--image", default="")
        parser.add_argument("--hit", choices=["true", "false", ""], default="")
        arguments = parser.parse_args()
        root = Path.cwd().resolve()
        cls.reject_symlink(arguments.identity.absolute())
        identity_path = arguments.identity.resolve()
        if identity_path == root or root in identity_path.parents:
            raise ValueError("Prepared identity must be outside the checkout")
        if arguments.operation == "prepare":
            prepared = cls.prepare(root, arguments.repository, arguments.image)
            identity_path.write_text(json.dumps(prepared, sort_keys=True) + "\n")
            print("key=" + prepared["key"])
        else:
            prepared = json.loads(identity_path.read_text())
            if arguments.operation == "restore":
                cls.restore(root, prepared, arguments.hit == "true")
            elif arguments.operation == "record":
                cls.record(root, prepared)
            elif arguments.operation == "verify":
                return cls.verify(root, prepared)
        return 0


if __name__ == "__main__":
    try:
        sys.exit(SwiftBuildCache.main())
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print("swift-build-cache: " + str(error), file=sys.stderr)
        sys.exit(2)
