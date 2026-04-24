# ship

> Full ship pipeline — detect platform, rebase on base, run tests, audit coverage + scope drift, pre-landing review, bump version, update CHANGELOG, commit in bisectable chunks, verification gate, push, open PR. Refuses to ship main/master.

# Ship

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Feature branch is complete.
- Tests are green locally.
- You want one command to take it from "done locally" to "PR open + verified".

## Pre-flight refusals
- Refuse if current branch is `main` or `master`.
- Refuse if `git status` shows uncommitted changes that aren't part of this ship.
- Refuse if no test command can be detected.

## The 20 Steps

### 1. Detect platform
- Read `package.json`, `pyproject.toml`, `Cargo.toml`, or `Makefile` to decide test command.
- Priority order:
  - `package.json` → `npm test` / `pnpm test` / `bun test` (honor the `scripts.test` field).
  - `pyproject.toml` → `pytest` (or the configured `[tool.pytest.ini_options]` runner).
  - `Cargo.toml` → `cargo test`.
  - `Makefile` with a `test` target → `make test`.
- If ambiguous: ask user which command to run; remember the answer in `~/.superagent/ship/test-cmd.<project-hash>`.

### 2. Pre-flight check
- Run `bin/superagent-ship` (the helper) — it refuses to ship main and does the rebase.
- Confirm current branch is not main/master.
- Confirm no uncommitted changes outside the ship scope (`git status --porcelain` must be clean, or only contain files the ship intends to commit).

### 3. Rebase on base branch
- Via the helper: `git fetch origin && git rebase origin/<base>`.
- Default `<base>` is `main`; honor `$ARGUMENTS` if the user passed a base branch.
- Abort ship if rebase has conflicts — user must resolve first.
- Never run `git rebase --abort` silently; surface the conflict and stop.

### 4. Run tests
- Execute the test command detected in step 1.
- Capture stdout/stderr + duration; store summary for step 15.
- Abort ship if tests fail. Do not "fix and retry" silently — surface failure, let user triage.

### 5. Coverage audit
- If the project has a coverage tool (`jest --coverage`, `pytest --cov`, `cargo tarpaulin`, etc.): run it, record baseline + new number.
- Compare against the last stored coverage in `~/.superagent/ship/coverage.<project-hash>.json`.
- If coverage dropped >5% — flag to user, ask to proceed or abort.
- Update stored coverage on successful ship.

### 6. Plan completion audit
- If a plan file exists at `docs/plans/<slug>.md` (or `$ARGUMENTS` referenced a plan): read it.
- Check that every `- [ ]` task is now `- [x]`.
- If not all checked: list incomplete tasks, abort ship. User can either complete them or explicitly override.

### 7. Scope drift detection
- Run `git diff origin/<base>...HEAD --stat` — list files changed.
- Cross-reference against the plan's stated scope (the "Files touched" section, if present).
- If any files are outside scope: surface to user, show the drift, ask to confirm or abort.

### 8. Pre-landing review
- Invoke the `review` skill on the diff (`git diff origin/<base>...HEAD`).
- Parse the verdict:
  - `BLOCK`: abort ship, surface findings.
  - `Needs Changes`: surface findings, ask user to proceed anyway or fix first.
  - `LGTM` / `Approve`: continue.

### 9. Version bump
- Read current version from `package.json` / `pyproject.toml` / `Cargo.toml` / `VERSION` (first one found).
- Default: patch bump.
- If `$ARGUMENTS` contains `minor` or `major`: bump accordingly.
- Write the new version back to the same file. Keep formatting stable (don't rewrite the whole file).

### 10. CHANGELOG update
- Prepend a new section at the top of `CHANGELOG.md`: `## vX.Y.Z — <today>` (ISO date).
- Auto-generate bullets from commit messages since the merge base with `<base>`.
- Group by Conventional Commit type:
  - `feat:` → Added
  - `refactor:` / `perf:` / `style:` → Changed
  - `fix:` → Fixed
  - `revert:` / deletion commits → Removed
- Preserve the rest of the file verbatim below the new section.

### 11. Commit in bisectable chunks
- Group staged-but-uncommitted work by logical file-group (one concern per commit).
- For each group: `git add <files> && git commit -m "<caveman-commit-style message>"`.
- Invoke `caveman:caveman-commit` for message generation if available. Otherwise fall back to a short imperative subject ≤50 chars.
- Discipline: if one of these commits breaks the build, `git bisect` should surface exactly that one. Do not mash unrelated changes into a single "misc" commit.

### 12. Verification gate
- Re-run the test command from step 1 on the rebased HEAD. This catches the case where rebase merged cleanly but semantically broke something.
- Run `graphify update` if `graph.json` exists at the repo root (keeps knowledge graph fresh for downstream sessions).
- Invoke the `verification-before-completion` skill (superpowers:verification-before-completion). Require evidence of green tests before continuing.
- If verification fails: abort ship, do not push.

### 13. Push
- `git push -u origin <current-branch>`.
- If push fails (non-fast-forward, auth, hook rejection): surface remote error verbatim, do not retry with `--force`.
- If remote branch already exists and diverged from local: stop and ask the user — never force-push silently.

### 14. Open PR
- `gh pr create --base <base> --title "<caveman-style title>" --body "<body template below>"`.
- Title: use `caveman:caveman-commit` logic (≤70 chars, imperative).
- Capture the PR URL from `gh` output.

### 15. Ship metrics
- Append one JSON line to `~/.superagent/cost/ship.jsonl`:
  ```json
  {"ts":"<iso-8601>","branch":"<name>","base":"<base>","files_changed":<n>,"test_duration_s":<n>,"coverage_delta":<n>,"pr_url":"<url>","version":"<x.y.z>"}
  ```
- Create `~/.superagent/cost/` if it doesn't exist.

### 16. Status + summary
Print to user:

```
SHIPPED
Branch: <b>
Version: <v>
PR: <url>
Tests: <n>/<n> pass
Coverage: <pct> (<delta>)
Files: <n> changed
```

## PR body template

```markdown
## Summary
- <bullet 1>
- <bullet 2>

## Test plan
- [x] <test you ran>
- [x] Tests pass locally
- [x] Rebased on latest <base>

## Linked plan
[<slug>](docs/plans/<slug>.md)
```

## Output
- Committed chain of bisectable commits on the feature branch.
- Updated `CHANGELOG.md` + bumped version file.
- Open PR URL printed to stdout.
- One-line entry in `~/.superagent/cost/ship.jsonl`.

## Verification
- PR URL printed (not empty).
- All tests green on the rebased HEAD (verified in step 12, not just step 4).
- CHANGELOG entry present for the bumped version.
- No commits directly to `main` or `master`.
- `git log --oneline origin/<base>..HEAD` shows the bisectable chain — each commit scoped to one concern.

## Abort conditions — summary
Ship refuses (or aborts mid-flight) when any of the following hold:

1. Current branch is `main` / `master`.
2. No test command can be detected and user declines to specify one.
3. Rebase produces conflicts.
4. Tests fail (step 4 or step 12).
5. Coverage drops >5% and user declines to proceed.
6. Plan has unchecked tasks and user declines to override.
7. Review skill returns `BLOCK`.
8. Push fails with non-fast-forward (no silent force-push).
9. `verification-before-completion` refuses to confirm.

In every abort case: leave the repo in a clean state (no half-written CHANGELOG, no partial commits of ship machinery), surface the exact reason, and exit non-zero.
