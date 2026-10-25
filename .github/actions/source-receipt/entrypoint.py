#!/usr/bin/env python3
"""Validate the reviewed-copy boundary before loading the receipt implementation."""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import sys

COMPONENT_FILES = ("action.yml", "entrypoint.py", "receipt.py", "README.md")
UPSTREAM_REPOSITORY = "Void-Deck/q-branch"
UPSTREAM_PATH = "ci/source-receipt"


class ReceiptError(Exception):
    """Safe fixed diagnostics only; never event or subprocess text."""


def full_sha(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def regular_file(path):
    try:
        return stat.S_ISREG(path.lstat().st_mode)
    except OSError:
        return False


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ReceiptError("duplicate JSON key")
        result[key] = value
    return result


def reviewed_copy(directory):
    manifest_path = directory / "reviewed-copy.json"
    if not regular_file(manifest_path) or manifest_path.stat().st_size > 16384:
        raise ReceiptError("missing or invalid reviewed-copy manifest")
    try:
        manifest = json.loads(manifest_path.read_text(), object_pairs_hook=unique_object)
    except (ValueError, OSError):
        raise ReceiptError("invalid reviewed-copy manifest") from None
    if not isinstance(manifest, dict) or set(manifest) != {
        "schemaVersion", "upstreamRepository", "upstreamCommit", "upstreamPath", "files"
    }:
        raise ReceiptError("invalid reviewed-copy manifest fields")
    if (type(manifest["schemaVersion"]) is not int or manifest["schemaVersion"] != 1
            or manifest["upstreamRepository"] != UPSTREAM_REPOSITORY
            or manifest["upstreamPath"] != UPSTREAM_PATH
            or not full_sha(manifest["upstreamCommit"])):
        raise ReceiptError("invalid reviewed-copy upstream identity")
    hashes = manifest["files"]
    if not isinstance(hashes, dict) or set(hashes) != set(COMPONENT_FILES):
        raise ReceiptError("invalid reviewed-copy file allowlist")
    for name in COMPONENT_FILES:
        path = directory / name
        expected = hashes[name]
        if (not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected)
                or not regular_file(path)):
            raise ReceiptError("invalid reviewed-copy file")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ReceiptError("reviewed-copy content drift")
    return {"kind": "reviewed-copy", "repository": UPSTREAM_REPOSITORY,
            "commit": manifest["upstreamCommit"], "path": UPSTREAM_PATH,
            "fileSHA256": hashes}


def component_provenance(directory, environment):
    repository = environment.get("SOURCE_RECEIPT_ACTION_REPOSITORY", "")
    revision = environment.get("SOURCE_RECEIPT_ACTION_REF", "")
    if repository or revision:
        if repository != UPSTREAM_REPOSITORY or not full_sha(revision):
            raise ReceiptError("remote action requires the canonical repository and full commit pin")
        return {"kind": "remote-action", "repository": repository,
                "commit": revision, "path": UPSTREAM_PATH}
    return reviewed_copy(directory)


def main():
    # A local action lives inside the consumer checkout. Importing its validated
    # implementation must not create bytecode files there, regardless of ambient
    # Python settings; isolated mode alone does not disable bytecode writes.
    sys.dont_write_bytecode = True
    directory = Path(__file__).resolve().parent
    provenance = component_provenance(directory, os.environ)
    spec = importlib.util.spec_from_file_location("source_receipt", directory / "receipt.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    try:
        module.record(os.environ, provenance)
    except module.IdentityError as error:
        if not isinstance(error.stage, module.ValidationStage):
            raise
        raise ReceiptError("source identity validation failed (" + error.stage.value + ")") from None


if __name__ == "__main__":
    try:
        main()
    except ReceiptError as error:
        print("source receipt: " + str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:
        print("source receipt: unable to record validated source identity", file=sys.stderr)
        sys.exit(1)
