#!/usr/bin/env bash
# Validate the caller-selected Swift compiler before repository verification.
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd -P)"
pin_file="$repository_root/.swift-version"
if [[ ! -f "$pin_file" ]]; then
  printf '%s\n' 'Swift compiler pin is missing: .swift-version' >&2
  exit 2
fi
compiler_line="$(cat "$pin_file")"
if [[ "$compiler_line" != 6.4 || "$(grep -c '^' "$pin_file")" != 1 ]]; then
  printf '%s\n' 'Unsupported Swift compiler pin; expected the 6.4 release line.' >&2
  exit 2
fi
if ! compiler_version="$(swift --version 2>&1)"; then
  printf 'Unable to run the selected Swift compiler:\n%s\n' "$compiler_version" >&2
  exit 2
fi
compiler_report_count="$(printf '%s\n' "$compiler_version" | grep -o 'Swift version' | grep -c . || true)"
# A numeric boundary rejects 6.40; a whitespace boundary rejects -dev suffixes.
# Snapshot markers can also occur later in Apple or upstream version output.
if [[ "$compiler_report_count" != 1 ]] \
    || ! printf '%s\n' "$compiler_version" | grep -Eq "^(swift-driver version: [^[:space:]]+ )?(Apple )?Swift version ${compiler_line//./\\.}(\\.[0-9]+)?([[:space:]]|$)" \
    || printf '%s\n' "$compiler_version" | grep -Eiq 'snapshot|development|[- ]dev([ .-]|$)'; then
  printf 'Expected Swift %s release compiler; selected compiler reports:\n%s\n' \
    "$compiler_line" "$compiler_version" >&2
  exit 2
fi
printf '%s\n' "$compiler_version"
