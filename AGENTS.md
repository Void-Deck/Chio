# Chio project guidance

Read [Docs/Design.md](Docs/Design.md) for current architecture and its decision
index, then the relevant topic files in `Docs/Decisions/` before changing behavior.
Read [Docs/Plan.md](Docs/Plan.md) for active work and
[Docs/Verification.md](Docs/Verification.md) for applicable checks. Accepted
decisions remain authoritative after delivery; proposals and shelved work do not
change shipped contracts. `Docs/Releases/` holds revision-specific evidence.
Update each owning document instead of duplicating contracts or history here.

## Project boundaries

- Chio means attractive or pretty in Singlish; it is not an acronym. Preserve
  the tagline "Beautiful terminal interfaces for Swift."
- Build an opinionated, declarative design and interaction layer over SwiftTUI.
  SwiftTUI owns rendering, lifecycle, layout, state, focus, input, and scrolling.
  Prefer native control styles and composition; new components must add reusable UX.
  Follow the [pure style and view contracts](Docs/Design.md#styles-and-view-contracts).
- Use immutable stored properties for owned domain and view-configuration values.
  Follow the value contracts and explicit state-owner exceptions in
  [Design.md](Docs/Design.md#value-contracts).
- Organize the library by component, then responsibility:
  `Sources/Chio/<Component>/<Domain|Protocol|Execution|Serialization|Presentation>`.
  Follow [source ownership](Docs/Design.md#source-ownership) for shared foundations
  and matching focused tests. This overrides the global default directory order.
- Keep one package and one public `Chio` library until real dependency boundaries
  justify more products. Examples default to local fixtures. Online map acquisition
  is an explicit opt-in. Follow the [approved map expansion](Docs/Plan.md#approved-map-expansion)
  for planned storage and service adapters; other external integrations remain deferred.
- Apply themes through the environment. Keep behavior in component options and
  application layout in SwiftTUI composition. Do not use private upstream APIs to
  conceal styling or focus limitations.
- Validate theme and input changes with public raster and hosted-session APIs.
  Native focus, stable selection, and search text are distinct contracts. Keep
  batched-input regressions when modifying the transition into search.
- Keep form validation rules and draft ownership in the application. Chio owns
  field presentation and error visibility; native controls and focus perform editing.
- Parse Markdown when content changes, then compose native views from the immutable
  document. Keep parser types internal; native scroll views own document navigation.

## Reviewed engineering checks

This public repository uses the complete reviewed EngineeringRules v0.2.1 source
copy in [Vendor/EngineeringRules](Vendor/EngineeringRules/PUBLIC-COPY-README.md),
exported from commit `b1ec7a16cdbce96b17a77eccc6384db3ec8708f7` by upstream
`Scripts/export-public-copy.py`. The copy manifest records source paths and
SHA-256 hashes. Do not hand-edit copied files. Refresh the complete copy through
a focused rollout PR: rerun the upstream exporter at the new release tag and
review its exact commit, file inventory and hashes before adoption.

Use the repository-owned setup and gate in
[Verification](Docs/Verification.md#shared-engineering-rules). Normal checking
verifies the copy and checks Chio's configuration and existing baseline without
rewriting them. Chio has no private EngineeringRules fetch or global installation
requirement. Native macOS and Linux qualification remain separate evidence;
there is no NUC fallback for missing platform checks.

## Q GitHub publication

For Q-owned work in `Void-Deck/Chio`, use the installed `q pr` CLI as
**Q Branch Bot** (`q-branch-bot[bot]`). Use `q pr help` for command details.
The local repository allowlist and GitHub App installation must both permit
`Void-Deck/Chio`; repository discovery alone does not enroll a checkout.
Keep credentials and local App configuration outside this public repository.
If Q access is unavailable, report the blocker instead of publishing through a
personal account.

Prepare a focused branch from the current remote default branch. Preserve
unrelated changes and unpublished history in other branches or worktrees.
Run the applicable [verification](Docs/Verification.md). Explicitly stage only
the focused changes on the feature branch. Create new Codex-authored commits
with installed `q commit` and the full lowercase parent SHA from `git rev-parse HEAD`:

```sh
q commit --message-file /absolute/path/to/commit-message.txt \
  --expected-head FULL_PARENT_SHA --json
```

Include `Co-authored-by: Codex <codex@openai.com>` in the message file. Q supplies
both author and committer identity; never fall back to personal attribution.
Preserve existing history, signatures and other authors' commits. New Q commits
are unsigned and skip hooks; verification and separate review remain required.
Read the private Q Branch
[commit contract](https://github.com/Void-Deck/q-branch/blob/main/docs/github-publishing.md#create-a-commit-as-q)
for captured staging and failure handling. After `uncertain_commit` (exit 4),
inspect the local branch and created commit before retrying.

Confirm that the checkout is clean. Its single `origin` URL must identify
`Void-Deck/Chio`. From that checkout, publish the exact full lowercase commit ID:

```sh
q pr check --repo Void-Deck/Chio --json
q pr publish --repo Void-Deck/Chio \
  --base main --head codex/example-change --commit FULL_COMMIT_SHA \
  --title 'Describe the resulting behavior' --body-file /path/to/pr-body.md
```

Replace the example branch, commit, title and body path with the reviewed
candidate's values. Publication pushes that commit and creates a draft PR.
Verify the returned repository, bot author, branch, commit and draft state.
For an existing Q-owned PR, sync from its clean head checkout:

```sh
q pr sync --repo Void-Deck/Chio --pr PR_NUMBER \
  --expected-commit FULL_COMMIT_SHA --json
```
For workflow-file publication or sync, add `--allow-workflows` only when that
change and the required installation permission are authorized.

Keep the PR draft until applicable checks and separate engineering review pass.
Then use `q pr ready --pr PR_NUMBER --expected-head FULL_COMMIT_SHA --json`.
Readiness does not approve or merge the PR. A human retains merge authority;
merge requires explicit approval covering that PR and revision or defined scope.
The owner's defined standing scope (2026-10-31): the coordinator merges refreshes of
the reviewed `Vendor/EngineeringRules` copy (re-export at a new release tag, reviewed
by hash) and other shared-tooling rollout PRs after separate review and green checks.
Do not enable automatic merging or bypass repository protections.
After an uncertain write, inspect remote state before any further mutation.

Global engineering, organization, and worker-routing policies belong in
`~/.codex/AGENTS.md` and its companion instructions, not in this file.
