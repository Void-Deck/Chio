#!/usr/bin/env bash
# Explicit setup may fetch public dependencies. Normal checks use these tools.
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: bash Scripts/ci/prepare-rules.sh" >&2
  exit 2
fi
cd "$(dirname "$0")/../.."
repository_root="$(pwd -P)"
rules_copy="$repository_root/Vendor/EngineeringRules"
gate_directory="$repository_root/.build/swift-rules"

python3 -B Scripts/ci/verify-rules-copy.py
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi
bash Scripts/check-swift-version.sh

tool_options=(--package-path "$rules_copy" --scratch-path "$gate_directory/tool"
  -c release --product swift-rules --build-system native --force-resolved-versions
  --jobs "${SWIFT_BUILD_JOBS:-2}")
swift build "${tool_options[@]}"
binary_directory="$(swift build "${tool_options[@]}" --show-bin-path)"
python3 -B Scripts/ci/prepare-swiftlint.py --bin-directory "$binary_directory"

python3 -m venv "$gate_directory/docs-venv"
"$gate_directory/docs-venv/bin/python" -m pip --disable-pip-version-check install \
  --require-hashes -r "$rules_copy/Configuration/documentation-requirements.txt"
python3 -B Scripts/ci/verify-rules-copy.py
