# Source receipt

This Python standard-library composite action records the checked-out source and
workflow identities after checkout. It does not run builds, tests, Docker, API
requests, token acquisition, fallback admission, or a ledger. It grants no CI
eligibility and makes no live freshness, approval, authenticity or reproducibility
claim. Repository policy owns those decisions.

## Private repository usage

Use the canonical private action with a reviewed full 40-character commit SHA:

```yaml
- uses: actions/checkout@<reviewed-full-commit-SHA>
- id: source
  uses: Void-Deck/q-branch/ci/source-receipt@<reviewed-full-commit-SHA>
```

Place this step after checkout, before consuming its receipt. The job needs Python
3.9 or newer and Git. The runner must permit private action access. No action
input accepts an upstream revision. Remote invocation rejects a missing full
commit pin or a different action repository. `pull_request_target` and other
events are unsupported. Only `pull_request`, `push` and `workflow_dispatch` are
accepted. Refs must satisfy Git's `check-ref-format`; Unicode and punctuation in
valid branch names are preserved and JSON-escaped in the output channel.
Checkout must occupy `github.workspace` itself, not a nested checkout path. Each
read-only Git command trusts only that exact resolved directory for that command;
the action changes no persistent Git configuration.

The action emits one compact JSON receipt as `steps.source.outputs.receipt` and
stdout. It writes no files into the checked-out source.
The entrypoint disables Python bytecode cache writes before loading the receipt
implementation, independently of the runner's Python settings. Consumers may explicitly
retain that output as an artifact under their own workflow policy. No raw event
payload or subprocess diagnostic is printed. `GITHUB_OUTPUT` is a runner-owned
append channel; its availability is required. Only consume outputs from a
successful step.

An expected identity rejection reports only a fixed validation stage, such as
`event-merge-commit`, `merge-parents`, `checkout-commit` or `git-read`. These
categories identify the rejected check without printing observed values.
Unexpected errors retain the generic failure diagnostic. A category does not
prove why the rejected observation differed or authorize a retry.

## Receipt contract

Schema version 1 preserves separate target repository name/id, workflow ref and
commit, run ID and attempt, event/ref, checked-out commit, PR number, base
repository/commit, head repository/commit, and tested synthetic merge commit.
Numeric identifiers are canonical decimal strings. Push and manual events use
`null` for PR, base and tested merge; their head is the checked-out commit.
Component provenance identifies either a canonical remote full commit pin or a
reviewed copy with that upstream commit and allowlisted file SHA-256 hashes.

The receipt checks `HEAD == github.sha`. For PRs it checks the synthetic commit's
ordered parents against the distinct event base and head. These checks bind the
tested merge; commit object headers work with shallow checkouts.

A populated event `merge_commit_sha` must have valid SHA format, but does not
select or constrain the tested commit. [GitHub Actions identifies its source](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request)
through the merge branch and `github.sha`.
[PR merge metadata is computed asynchronously](https://docs.github.com/en/rest/guides/using-the-rest-api-to-interact-with-your-git-database#checking-mergeability-of-pull-requests);
the webhook observation has no documented atomic equality guarantee with that
Actions source. A different valid observation, or a missing/null field, does not
replace or weaken actual checkout or parent checks. The supplemental value is
not emitted; schema version 1 retains the actual tested merge identity.

Push events
must identify the same ref and non-deleted `after` commit. Target repository
name/id must agree with the event. Malformed, inconsistent and duplicate JSON
keys fail. Event and commit object reads are limited to 2 MiB. Workflow context and event payload
are observations supplied by the runner, not independent fresh API reads.

Checkout must select the event source: a PR head checkout cannot stand in for
the tested merge. A manual run on a branch has no implied PR base. Reusing a
receipt does not establish the current PR head, current base, successful tests,
required-check coverage, protected workflow integrity or merge authorization.

## Reviewed public copy

Public Chio may publish a separately reviewed local copy of the four generic
allowlisted component files and their manifest. Do not reference this private
action from a public workflow or publish unrelated private source, policy or data.
The exporter never copies NUC controllers, private policy, repository documents,
test fixtures or exporter code into the consuming repository.

From a clean source checkout at the reviewed full commit, run:

```sh
python3 -I ci/source-receipt/export-copy.py \
  --source-checkout /path/to/q-branch \
  --commit FULL_40_CHARACTER_COMMIT_SHA \
  --destination /path/to/Chio/.github/actions/source-receipt
```

The destination must not exist and its parent must exist. The exporter requires
one literal standard GitHub HTTPS or SSH `origin` for `Void-Deck/q-branch`.
That local configuration check prevents accidental repository mislabeling; it
does not authenticate the remote or establish review approval. The exporter
rejects dirty source checkouts, a different HEAD, non-regular source files and
abbreviated SHAs. Review the public diff and publication scope before committing it.
Use `uses: ./.github/actions/source-receipt` after checkout in Chio. Its adjacent
`reviewed-copy.json` records `Void-Deck/q-branch`, the full source commit,
`ci/source-receipt` and exactly `action.yml`, `entrypoint.py`, `receipt.py`, and
`README.md` hashes. Local invocation requires and checks this manifest before
loading the main implementation. Missing metadata and changed files fail.

For a manual copy check without writing a receipt, run:

```sh
python3 -I -c 'import runpy; m=runpy.run_path(".github/actions/source-receipt/entrypoint.py"); m["reviewed_copy"](__import__("pathlib").Path(".github/actions/source-receipt"))'
```

Hashes detect accidental drift; they do not authenticate the publisher or stop an
attacker who can edit the action and its manifest. Review and protected workflow
ownership establish that trust. No local revision input bypasses the manifest.
Updates require another explicit export and review; there is no automatic update
or universal vendoring framework.

## Verification

Run `python3 -I -m unittest discover -s ci/source-receipt/tests -v` from the source
repository. Tests use real disposable Git commits and subprocess CLI execution.
They establish local validation, copy drift detection and export boundaries.
Hosted composite-action evaluation, private action access, real GitHub event
payloads and live public-copy adoption require separate evidence.
