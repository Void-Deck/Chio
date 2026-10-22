#!/usr/bin/env bash
# Local gate only: EngineeringRules is private and must already be available.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash Scripts/ci/check-rules.sh /path/to/EngineeringRules" >&2
  exit 2
fi

# Resolve relative input against the caller's directory before entering Chio.
case "$1" in
  /*) rules_checkout="$1" ;;
  *) rules_checkout="$PWD/$1" ;;
esac
cd "$(dirname "$0")/../.."
repository_root="$(pwd -P)"
gate_directory="$repository_root/.build/swift-rules"
scratch_path="$gate_directory/native"
compiler_context="$gate_directory/compiler-context.json"
helper_directory=""
rules_version=0.1.10
rules_commit=756987b0d0e4bf8245abe05611f43aab8ffc700e
launcher="$HOME/.local/bin/swift-rules"
documentation_python="$rules_checkout/.build/docs-venv/bin/python"

fail() {
  echo "check-rules: $*" >&2
  exit 2
}

cleanup() {
  status=$?
  if [[ -n "$helper_directory" ]]; then
    rm -rf "$helper_directory"
  fi
  if [[ "$status" -ne 0 ]]; then
    rm -f "$compiler_context"
  fi
  exit "$status"
}
trap cleanup EXIT

# A failed prerequisite, build, export or check must not leave previous evidence.
rm -f "$compiler_context"
for command in git python3 swift; do
  command -v "$command" >/dev/null || fail "Required command is unavailable: $command"
done
[[ -x "$launcher" ]] || fail "Install SwiftRules $rules_version at $launcher first"
[[ -x "$documentation_python" ]] || fail "Prepare the pinned documentation environment at $documentation_python first"

if [[ "$(uname -s)" == Darwin ]]; then
  # Respect the caller's selection; never change the system developer directory.
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
  [[ -d "$DEVELOPER_DIR" ]] || fail "Full Xcode is unavailable at DEVELOPER_DIR=$DEVELOPER_DIR"
fi

release_commit="$(git -C "$rules_checkout" rev-parse "v$rules_version^{commit}")"
[[ "$release_commit" == "$rules_commit" ]] || fail "EngineeringRules v$rules_version must resolve to $rules_commit"
installed_version="$("$launcher" --version)"
[[ "$installed_version" == "$rules_version" ]] || fail "Chio must pin the installed SwiftRules $rules_version"

mkdir -p "$gate_directory"
helper_directory="$(mktemp -d "$gate_directory/helper.XXXXXX")"
helper="$helper_directory/compiler-context.py"
# Read immutable Git objects, never a possibly modified working-tree helper.
git -C "$rules_checkout" show "$rules_commit:Scripts/compiler-context.py" > "$helper"
documentation_checker="$helper_directory/check-docs.py"
git -C "$rules_checkout" show "$rules_commit:Scripts/check-docs.py" > "$documentation_checker"

# The released checker validates exact parser versions before scanning.
# Checking never installs dependencies or fetches the private tool repository.
"$documentation_python" -B "$documentation_checker" --root "$repository_root"

# Refresh the native build before exporting; SwiftPM checks current inputs while
# retaining already-built dependencies in this gate's dedicated scratch path.
build_options=(-c release --target Chio --build-system native --force-resolved-versions
  --scratch-path "$scratch_path" --jobs "${SWIFT_BUILD_JOBS:-2}")
swift build "${build_options[@]}"
binary_directory="$(swift build "${build_options[@]}" --show-bin-path)"
build_description="$binary_directory/description.json"
[[ -f "$build_description" ]] || fail "Native build description is missing at $build_description"

python3 -B "$helper" --root "$repository_root" \
  --build-description "$build_description" --module Chio \
  --output "$compiler_context"
[[ -s "$compiler_context" ]] || fail "Compiler-context export did not produce $compiler_context"
"$launcher" check --root "$repository_root" --compiler-context "$compiler_context"
