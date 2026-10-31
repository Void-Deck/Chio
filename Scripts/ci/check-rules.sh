#!/usr/bin/env bash
# Check with the reviewed public copy; prepare external tools separately.
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: bash Scripts/ci/check-rules.sh" >&2
  exit 2
fi

cd "$(dirname "$0")/../.."
repository_root="$(pwd -P)"
rules_copy="$repository_root/Vendor/EngineeringRules"
gate_directory="$repository_root/.build/swift-rules"
tool_scratch="$gate_directory/tool"
scratch_path="$gate_directory/native"
compiler_context="$gate_directory/compiler-context.json"
documentation_python="$gate_directory/docs-venv/bin/python"

fail() {
  echo "check-rules: $*" >&2
  exit 2
}

cleanup() {
  status=$?
  if [[ "$status" -ne 0 ]]; then
    rm -f "$compiler_context"
  fi
  exit "$status"
}
trap cleanup EXIT

# A failed prerequisite, build, export or check must not leave previous evidence.
rm -f "$compiler_context"
for command in python3 swift; do
  command -v "$command" >/dev/null || fail "Required command is unavailable: $command"
done
python3 -B Scripts/ci/verify-rules-copy.py
[[ -x "$documentation_python" ]] || fail "Run bash Scripts/ci/prepare-rules.sh to prepare the pinned tools first"

if [[ "$(uname -s)" == Darwin ]]; then
  # Respect the caller's selection; never change the system developer directory.
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
  [[ -d "$DEVELOPER_DIR" ]] || fail "Full Xcode is unavailable at DEVELOPER_DIR=$DEVELOPER_DIR"
fi
bash Scripts/check-swift-version.sh

# Artifacts stay outside the exact copy. Force the reviewed public lockfile.
tool_options=(--package-path "$rules_copy" --scratch-path "$tool_scratch"
  -c release --product swift-rules --build-system native --force-resolved-versions
  --jobs "${SWIFT_BUILD_JOBS:-2}")
swift build "${tool_options[@]}"
tool_binary_directory="$(swift build "${tool_options[@]}" --show-bin-path)"
checker="$tool_binary_directory/swift-rules"
installed_version="$("$checker" --version)"
[[ "$installed_version" == 0.2.1 ]] || fail "Require copied SwiftRules 0.2.1"
# Check both the archive pin and the extracted sibling bytes, without downloads.
python3 -B Scripts/ci/prepare-swiftlint.py --verify-only --bin-directory "$tool_binary_directory"

"$documentation_python" -B "$rules_copy/Scripts/check-docs.py" --root "$repository_root"

# Refresh Chio's native release build before exporting real compiler arguments.
build_options=(-c release --target Chio --build-system native --force-resolved-versions
  --scratch-path "$scratch_path" --jobs "${SWIFT_BUILD_JOBS:-2}")
swift build "${build_options[@]}"
binary_directory="$(swift build "${build_options[@]}" --show-bin-path)"
build_description="$binary_directory/description.json"
[[ -f "$build_description" ]] || fail "Native build description is missing at $build_description"

python3 -B "$rules_copy/Scripts/compiler-context.py" --root "$repository_root" \
  --build-description "$build_description" --module Chio \
  --output "$compiler_context"
[[ -s "$compiler_context" ]] || fail "Compiler-context export did not produce $compiler_context"
"$checker" check --root "$repository_root" --compiler-context "$compiler_context"
python3 -B Scripts/ci/verify-rules-copy.py
