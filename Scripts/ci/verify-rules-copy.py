#!/usr/bin/env python3
"""Verify the exact inventory and hashes of Chio's reviewed EngineeringRules copy."""

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import sys


UPSTREAM_COMMIT = "b1ec7a16cdbce96b17a77eccc6384db3ec8708f7"
DEFAULT_COPY = Path(__file__).resolve().parents[2] / "Vendor/EngineeringRules"


def unique_object(pairs):
    result = {}
    for name, value in pairs:
        if name in result:
            raise ValueError(f"Duplicate receipt key: {name}")
        result[name] = value
    return result


def relative_path(value):
    if (not isinstance(value, str) or not value or "\\" in value
            or any(ord(character) < 32 for character in value)):
        raise ValueError(f"Invalid receipt path: {value!r}")
    path = PurePosixPath(value)
    if not path.parts or path.is_absolute() or str(path) != value or ".." in path.parts:
        raise ValueError(f"Invalid receipt path: {value!r}")
    return path


def verify_copy(directory):
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError("Copy must be a real directory")
    receipt_path = directory / "reviewed-copy.json"
    if not stat.S_ISREG(receipt_path.lstat().st_mode):
        raise ValueError("Receipt must be a regular file")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)
    fields = {"schemaVersion", "upstreamRepository", "upstreamPath", "upstreamCommit", "files"}
    if not isinstance(receipt, dict) or set(receipt) != fields:
        raise ValueError("Invalid receipt fields")
    if (type(receipt["schemaVersion"]) is not int or receipt["schemaVersion"] != 1
            or receipt["upstreamRepository"] != "Void-Deck/EngineeringRules"
            or receipt["upstreamPath"] != "." or receipt["upstreamCommit"] != UPSTREAM_COMMIT):
        raise ValueError("Receipt must identify the reviewed EngineeringRules v0.2.1 commit")
    files = receipt["files"]
    if not isinstance(files, dict) or not files or "reviewed-copy.json" in files:
        raise ValueError("Invalid receipt inventory")
    expected_directories = set()
    for name, entry in files.items():
        path = relative_path(name)
        if not isinstance(entry, dict) or set(entry) != {"source", "sha256"}:
            raise ValueError(f"Invalid receipt entry: {name}")
        relative_path(entry["source"])
        if not isinstance(entry["sha256"], str) or not re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]):
            raise ValueError(f"Invalid SHA-256: {name}")
        expected_directories.update(str(parent) for parent in path.parents if str(parent) != ".")

    actual_files = set()
    actual_directories = set()

    def inventory(parent):
        # Do not follow links or ignore traversal errors, including extra empty dirs.
        for path in parent.iterdir():
            name = path.relative_to(directory).as_posix()
            mode = path.lstat().st_mode
            if stat.S_ISDIR(mode):
                actual_directories.add(name)
                inventory(path)
            elif stat.S_ISREG(mode):
                actual_files.add(name)
            else:
                raise ValueError(f"Nonregular path in copy: {name}")

    inventory(directory)
    expected_files = set(files) | {"reviewed-copy.json"}
    if actual_files != expected_files or actual_directories != expected_directories:
        missing = sorted(expected_files - actual_files)
        extra = sorted((actual_files - expected_files) | (actual_directories - expected_directories))
        raise ValueError(f"Copy inventory differs; missing={missing}, extra={extra}")
    for name, entry in files.items():
        if hashlib.sha256((directory / name).read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError(f"Copy SHA-256 mismatch: {name}")
    return len(files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("copy", nargs="?", type=Path, default=DEFAULT_COPY)
    arguments = parser.parse_args()
    try:
        count = verify_copy(arguments.copy)
    except (OSError, ValueError) as error:
        print(f"verify-rules-copy: {error}", file=sys.stderr)
        return 1
    print(f"EngineeringRules v0.2.1: {count} reviewed file hashes and exact inventory verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
