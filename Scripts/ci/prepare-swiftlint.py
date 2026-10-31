#!/usr/bin/env python3
"""Prepare or verify the official SwiftLint 0.65.1 sibling executable."""

import argparse
import hashlib
import io
from pathlib import Path, PurePosixPath
import platform
import stat
import sys
import urllib.request
import zipfile


VERSION = "0.65.1"
# Official release asset pins also used by EngineeringRules v0.2.1's installer.
ASSETS = {
    "Darwin": ("portable_swiftlint.zip", "c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"),
    "Linux-arm64": ("swiftlint_linux_arm64.zip", "9ffa52f478e6d8eb485d37d14715ffac90abc81c58f3370d598bf75be05605f8"),
    "Linux-x86_64": ("swiftlint_linux_amd64.zip", "caeed6f4a679c35539ffaf124f6c4ab4a8416917f7d8796279dc52b74026059d"),
}
DOWNLOADS = Path(__file__).resolve().parents[2] / ".build/swift-rules/downloads"


def asset_for_host(system, machine):
    if machine in ("arm64", "aarch64"):
        architecture = "arm64"
    elif machine in ("x86_64", "amd64"):
        architecture = "x86_64"
    else:
        raise ValueError(f"Unsupported SwiftLint architecture: {machine}")
    key = system if system == "Darwin" else f"{system}-{architecture}"
    if key not in ASSETS:
        raise ValueError(f"Unsupported SwiftLint platform: {system}")
    return ASSETS[key]


def verified_archive(contents, expected_digest):
    if hashlib.sha256(contents).hexdigest() != expected_digest:
        raise ValueError("SwiftLint archive SHA-256 mismatch")
    return contents


def archive_tools(contents):
    tools = {}
    with zipfile.ZipFile(io.BytesIO(contents)) as archive:
        for member in archive.infolist():
            path = PurePosixPath(member.filename)
            mode = member.external_attr >> 16
            if (path.is_absolute() or ".." in path.parts or "\\" in member.filename
                    or stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR)):
                raise ValueError(f"Unsafe SwiftLint archive member: {member.filename}")
            if member.is_dir() or (path.name != "swiftlint" and path.suffix != ".dylib"):
                continue
            if path.name in tools:
                raise ValueError(f"Duplicate SwiftLint tool: {path.name}")
            tools[path.name] = archive.read(member)
    if "swiftlint" not in tools:
        raise ValueError("SwiftLint archive has no executable")
    return tools


def verify_tools(directory, tools):
    for name, contents in tools.items():
        path = directory / name
        mode = path.lstat().st_mode
        if not stat.S_ISREG(mode) or not mode & 0o111 or path.read_bytes() != contents:
            raise ValueError(f"SwiftLint installed tool differs from the pinned archive: {path}")


def prepare(binary_directory, verify_only):
    filename, digest = asset_for_host(platform.system(), platform.machine().lower())
    archive_path = DOWNLOADS / filename
    if archive_path.exists() or archive_path.is_symlink():
        if not stat.S_ISREG(archive_path.lstat().st_mode):
            raise ValueError("SwiftLint archive must be a regular file")
        contents = verified_archive(archive_path.read_bytes(), digest)
    else:
        if verify_only:
            raise ValueError("SwiftLint archive is missing; run bash Scripts/ci/prepare-rules.sh")
        url = f"https://github.com/realm/SwiftLint/releases/download/{VERSION}/{filename}"
        print(f"Download {url} (sha256:{digest})", flush=True)
        with urllib.request.urlopen(url, timeout=60) as response:
            contents = verified_archive(response.read(), digest)
        DOWNLOADS.mkdir(parents=True, exist_ok=True)
        archive_path.write_bytes(contents)
    tools = archive_tools(contents)
    if not verify_only:
        if not binary_directory.is_dir():
            raise ValueError("Build swift-rules before preparing its SwiftLint sibling")
        for name, contents in tools.items():
            destination = binary_directory / name
            if destination.is_symlink():
                raise ValueError(f"Refusing SwiftLint output symlink: {destination}")
            destination.write_bytes(contents)
            destination.chmod(0o755)
    verify_tools(binary_directory, tools)
    print(f"SwiftLint {VERSION}: official archive and {len(tools)} installed tool file(s) verified")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin-directory", required=True, type=Path)
    parser.add_argument("--verify-only", action="store_true", help="Do not download or write tools")
    arguments = parser.parse_args()
    try:
        prepare(arguments.bin_directory, arguments.verify_only)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"prepare-swiftlint: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
