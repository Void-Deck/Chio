# SwiftRules reviewed source copy

This directory contains the complete reviewed public source surface of a tagged
EngineeringRules release. `reviewed-copy.json` records the upstream commit and,
for each destination file, its release source path and SHA-256. `Package.swift`
comes from the release's explicit public manifest; all other paths are unchanged.
Refresh the whole copy through a consumer rollout PR reviewed by these hashes.
Do not edit individual copied files or add private upstream material.

Build with Swift 6.4 using a separate scratch directory:

```sh
swift build --package-path /path/to/copy --scratch-path /path/to/build \
  -c release --product swift-rules
```

`Package.resolved` pins SwiftSyntax 604.0.0 and its exact commit. SwiftPM needs
access to that public dependency or a previously populated dependency cache.
The public manifest declares only production targets; no tests are distributed.

Normal Swift checks also require the official SwiftLint **0.65.1** executable
beside the built `swift-rules` executable. Consumer setup must obtain and verify
that binary separately. On macOS select full Xcode through `DEVELOPER_DIR` for
SourceKit. On Linux use Ubuntu Noble or compatible libraries: the SwiftLint binary
requires GLIBC 2.38 and GLIBCXX 3.4.32.

```sh
cp /path/to/verified/swiftlint /path/to/build/release/swiftlint
/path/to/build/release/swift-rules check --root /path/to/consumer
/path/to/build/release/swift-rules review-candidates --root /path/to/consumer --format json
```

The consumer owns `.swift-rules.json`, source/import scopes and reviewed baseline.
Its `toolVersion` must match the copied executable's `--version`; configuration
schema 2 is required. Source-only checks do not establish compiler witness
placement. For that coverage, export the consumer's completed native release build
with `Scripts/compiler-context.py` and supply its context to `check`.
Native macOS/Linux evidence and independent review remain separate obligations.

The documentation checker runs separately, with Python 3.9+ and its hash-pinned
dependencies installed explicitly outside the copy:

```sh
python3 -m venv /path/to/docs-venv
/path/to/docs-venv/bin/python -m pip install --require-hashes \
  -r /path/to/copy/Configuration/documentation-requirements.txt
/path/to/docs-venv/bin/python /path/to/copy/Scripts/check-docs.py --root /path/to/consumer
```

The consumer owns `.documentation-rules.json` and its required invocation.
Normal checking never installs tools, updates baselines or rewrites sources.
Keep build artifacts and environments outside the copy so its exact file inventory
and recorded hashes remain verifiable. Hashes establish byte identity, not review
approval, platform qualification or authentic execution.
