# SuperAgent v3 — Wave 3 (Methodology & Quality, v2.6.0 / v3.0.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the three Wave 3 components from the v3 spec — SPARC (5-phase gate-enforced pipeline), Testgen (coverage gap detection + scaffolding), and Diff-risk (per-diff impact + reviewer suggestion). After Wave 3, the router can enforce a strict methodology when complexity warrants, surface uncovered behavior before code lands, and rate every diff for blast radius before push.

**Architecture:** Three independent threads writing into `~/.superagent/` subdirs:

1. `sparc/<slug>/` — SPARC state machine + per-feature artifacts (`spec.md`, `pseudo.md`, `arch.md`, `refine.md`, `complete.md`, traceability matrix).
2. `testgen/` — coverage adapter cache, gap report, per-project min-coverage threshold.
3. `diff/` — last diff-risk report, cached for `ship` and `review` to consume.

**Wave 1 + Wave 2 are prerequisites.** SPARC consumes the `architect` and `tester` specialist agents (Wave 2) plus `agent-skills:test-driven-development` and `agent-skills:documentation-and-adrs`. Testgen integrates with `ship` and `review` (existing). Diff-risk integrates with `ship` and `review` and uses `git diff` parsing only — no GitHub API.

**Tech stack:** bash 5+, python3 (inline via heredoc), jq, git. No new runtime dependencies beyond what's already shipped. Tests are bash scripts under `test/` following the Wave 1 + Wave 2 style.

**Defaults:** Wave 3 components are **default ON for integration points** (`review`/`ship` will run `diff-risk` and consult cached `testgen` results) but each bin can be invoked independently. SPARC is opt-in per feature (`/sparc init <slug>` starts a session); it never auto-fires.

---

## File structure

### New files

**SPARC (§8.1):**
- `bin/superagent-sparc` — init/gate/advance/report/status CLI
- `skills/sparc/SKILL.md` — orchestrator skill
- `commands/sparc.md` — `/sparc` slash
- `test/test-sparc-init.sh` — scaffolding + dir layout
- `test/test-sparc-gate.sh` — gate eval per phase (pass + fail fixtures)
- `test/test-sparc-advance.sh` — phase bump refuses when gate not passed
- `test/test-sparc-report.sh` — traceability matrix output
- `test/fixtures/sparc/phase1-pass/spec.md` + `phase1-fail/spec.md` — gate fixtures
- `test/fixtures/sparc/phase3-pass/arch.md` + `phase3-fail/arch.md` — gate fixtures

**Testgen (§8.2):**
- `bin/superagent-testgen` — scan/suggest/status CLI
- `skills/testgen/SKILL.md` — coverage gap skill
- `commands/testgen.md` — `/testgen` slash
- `test/test-testgen-scan.sh` — coverage adapter parses jest + pytest output
- `test/test-testgen-gap.sh` — gap × LOC scoring ranks files correctly
- `test/test-testgen-suggest.sh` — markdown skeleton names tests for uncovered ranges
- `test/fixtures/testgen/jest-coverage-summary.json` — sample jest output
- `test/fixtures/testgen/pytest-cov.json` — sample pytest output
- `test/fixtures/testgen/sample-src/auth.ts` — toy file backing the suggest test

**Diff-risk (§8.3):**
- `bin/superagent-diff-risk` — classify/impact/risk/reviewers/report CLI
- `skills/diff-risk/SKILL.md` — diff risk skill
- `commands/diff-risk.md` — `/diff-risk` slash (legacy alias `/jujutsu`)
- `test/test-diff-risk-classify.sh` — 20-diff corpus assertions
- `test/test-diff-risk-impact.sh` — IMPACT_KEYWORDS scoring + risk-factor flags
- `test/test-diff-risk-reviewers.sh` — CODEOWNERS parsing returns matching owners
- `test/fixtures/diff-risk/corpus.jsonl` — 20 sample diffs (mix of feature/bugfix/refactor/docs/test/config/style)
- `test/fixtures/diff-risk/CODEOWNERS` — sample owners file

**Wave 3 cross-cutting:**
- `docs/video/reel-wave3/{index.html,hyperframes.json,meta.json}` — release reel composition

### Modified files

- `bin/superagent-classify` — new rules for `sparc | spec | PRD | methodology | gate` (Wave 3 §8.1 routing) and `coverage | untested | testgen` (§8.2 routing). diff-risk routing via existing `review`/`ship` skills.
- `skills/superagent/brain/rules.yaml` — +3 rules (`sparc`, `testgen`, `diff-risk`).
- `skills/review/SKILL.md` — adds a "Diff-risk pre-check" section that calls `superagent-diff-risk` and folds findings into the 6-point checklist.
- `skills/ship/SKILL.md` — adds a "Diff-risk pre-push gate" that force-confirms when impact is `high` or `critical`.
- `bench/prompts.jsonl` — +5 prompts (sparc init, testgen scan, diff-risk on PR, coverage gap, traceability matrix).
- `README.md` — Wave 3 highlight block + capability rows.
- `CHANGELOG.md` — v2.6.0 entry.
- `package.json` — version bump to 2.6.0.
- `install.sh` — scaffold `sparc/`, `testgen/`, `diff/` subdirs + drop `.wave-3.installed` marker.
- `hooks/superagent-state-init.sh` — add the same three subdirs (idempotent).

### Runtime state created at install

- `~/.superagent/sparc/` (empty until `sparc init` creates `<slug>/`)
- `~/.superagent/testgen/min-coverage.txt` (default `70`)
- `~/.superagent/testgen/cov-cmd.txt` (empty unless user overrides)
- `~/.superagent/diff/` (empty until first risk report)
- `~/.superagent/.wave-3.installed`

---

## Wave 3 ordering

1. **Tasks 1–6: SPARC** — biggest component; defines the 5-phase contract first since testgen and diff-risk plug into it.
2. **Tasks 7–11: Testgen** — depends on a coverage tool (project-provided); ships with 2 adapter fixtures.
3. **Tasks 12–16: Diff-risk** — independent surface; needs `git` only.
4. **Tasks 17–19: Wiring** — `review`/`ship` skill updates so the new bins fire automatically.
5. **Tasks 20–22: Bench + docs + ship.**

---

## Task 1: SPARC — bin scaffold (`init`)

**Files:**
- Create: `bin/superagent-sparc`
- Test: `test/test-sparc-init.sh`

- [ ] **Step 1: Red test**

`test/test-sparc-init.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-sparc"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT

HOME="$TMPHOME" "$BIN" init feat-darkmode >/dev/null

DIR="$TMPHOME/.superagent/sparc/feat-darkmode"
[[ -d "$DIR" ]] || { echo "FAIL: $DIR missing"; exit 1; }
[[ -f "$DIR/state.json" ]] || { echo "FAIL: state.json missing"; exit 1; }

STATE=$(cat "$DIR/state.json")
echo "$STATE" | jq -e '.slug == "feat-darkmode" and .phase == 1 and .gate_status == "open"' >/dev/null \
  || { echo "FAIL: state shape: $STATE"; exit 1; }

# Idempotency: re-running init on the same slug should not clobber existing artifacts
echo "preserve me" > "$DIR/spec.md"
HOME="$TMPHOME" "$BIN" init feat-darkmode >/dev/null
[[ "$(cat "$DIR/spec.md")" == "preserve me" ]] \
  || { echo "FAIL: init clobbered existing artifact"; exit 1; }

echo "test-sparc-init: PASS"
```

- [ ] **Step 2: Implement `init`**

`bin/superagent-sparc` (Bash + python heredoc). Subcommand `init <slug>` creates `~/.superagent/sparc/<slug>/` with `state.json`:

```json
{"slug":"<slug>","phase":1,"artifacts":[],"gate_status":"open","gate_failures":[],"createdAt":"<iso>","updatedAt":"<iso>"}
```

If `state.json` already exists, leave it untouched. Print absolute path on success.

- [ ] **Step 3: Commit**

```bash
git add bin/superagent-sparc test/test-sparc-init.sh
git commit -m "feat(sparc): bin scaffold + init subcommand"
```

---

## Task 2: SPARC — gate evaluation (`gate`)

**Files:**
- Modify: `bin/superagent-sparc`
- Test: `test/test-sparc-gate.sh` + 4 fixtures under `test/fixtures/sparc/`

Gate rules per spec §8.1 table. Booleans, not scores.

| Phase | Pass condition (all must hold) |
|---|---|
| 1 (spec) | ≥3 lines matching `^- AC:` OR `^- \[ \] AC` (acceptance criteria); ≥1 line `^Constraint:` or `^- Constraint:`; ≥1 line `^Edge case` or `^- Edge case` |
| 2 (pseudocode) | every AC id from spec.md appears in pseudo.md; ≥1 line starts with `Error:` or `^// error path`; ≥1 line containing `O(` or `complexity:` |
| 3 (architecture) | TypeScript/Python/Go function signatures present (regex `\b(function|def|fn|interface|type|class)\s+\w+`); no `import .*\.\..*from same module` loop; every constraint from spec has a matching mention in arch.md |
| 4 (refinement) | every AC has a matching test name (heuristic: AC label tokens appear in `it(`/`test(`/`describe(`); coverage ≥ threshold from `~/.superagent/testgen/min-coverage.txt`; review status `LGTM` |
| 5 (completion) | all tests green (use last cached `testgen` report); `docs/adrs/` contains an entry younger than `state.updatedAt`; `CHANGELOG.md` mentions the slug |

- [ ] **Step 1: Red test** — 4 fixtures (`phase1-pass/spec.md`, `phase1-fail/spec.md`, `phase3-pass/arch.md`, `phase3-fail/arch.md`). Run `sparc gate` against each; assert `gate_status == "passed"` or `"failed"` accordingly.
- [ ] **Step 2: Implement `gate`** — Python heredoc that reads current `phase`, matches against the per-phase rule set, writes `gate_status` and `gate_failures` to `state.json`. Failures carry `{phase, reason, ts}`.
- [ ] **Step 3: Commit**

---

## Task 3: SPARC — `advance`

**Files:**
- Modify: `bin/superagent-sparc`
- Test: `test/test-sparc-advance.sh`

- [ ] **Step 1: Red test** — call `advance` when `gate_status == "open"` → exit non-zero with stderr "gate must pass". Call `gate` (force pass), then `advance` → phase bumps from 1 to 2, gate resets to `open`.
- [ ] **Step 2: Implement `advance`** — refuses unless `gate_status == "passed"`. On success: increment phase (cap at 5), reset gate to `open`, clear `gate_failures` for the new phase, update `updatedAt`.
- [ ] **Step 3: Commit**

---

## Task 4: SPARC — `report` (traceability matrix)

**Files:**
- Modify: `bin/superagent-sparc`
- Test: `test/test-sparc-report.sh`

- [ ] **Step 1: Red test** — seed `spec.md` with 3 ACs, seed `refine.md` with test names. `sparc report` outputs a markdown table with one row per AC, columns `AC | Pseudocode ref | Architecture ref | Test name | Status`.
- [ ] **Step 2: Implement `report`** — parse spec.md for AC ids (`^- AC[: ]\s*(\w+)`), grep each id in pseudo.md / arch.md / refine.md to fill the row. Status = ✓ if all four columns populated, else ✗.
- [ ] **Step 3: Commit**

---

## Task 5: SPARC — `status`

**Files:**
- Modify: `bin/superagent-sparc`
- Test: `test/test-sparc-status.sh`

Trivial: print `phase`, `gate_status`, last `gate_failures` entry. Both human and `--json` modes.

---

## Task 6: SPARC — skill + slash + classifier rule

**Files:**
- Create: `skills/sparc/SKILL.md` + `commands/sparc.md`
- Modify: `skills/superagent/brain/rules.yaml` (+sparc rule)
- Test: `test/test-sparc-docs.sh`

Frontmatter triggers on `spec | PRD | methodology | gate | sparc | spike | RFC`. Procedure walks the 5 phases with checkpoints. Slash forwards args to bin.

---

## Task 7: Testgen — coverage adapter scaffold

**Files:**
- Create: `bin/superagent-testgen`
- Test: `test/test-testgen-scan.sh` + 2 fixtures

`scan` subcommand:

1. Read `~/.superagent/testgen/cov-cmd.txt` if present (user override).
2. Otherwise auto-detect by file presence: `package.json` + `jest.config.*` → jest; `vitest.config.*` → vitest; `pytest.ini`/`pyproject.toml` with pytest → pytest; `Cargo.toml` → tarpaulin; `go.mod` → go-cover.
3. Run the appropriate command, parse the standardized JSON output, normalize to `{file, lines: {total, covered, uncovered: [ranges]}, statements: {total, covered}}` per file.
4. Cache the normalized report at `~/.superagent/testgen/last-report.json`.

For the test, ship `test/fixtures/testgen/jest-coverage-summary.json` and `test/fixtures/testgen/pytest-cov.json`. Use `SA_TESTGEN_FIXTURE=<path>` env var to skip the spawn step and parse the fixture directly — keeps the test hermetic (no Node/Python deps for the test runner).

- [ ] **Step 1: Red test**
- [ ] **Step 2: Implement adapters** — one parser per format (jest summary, pytest cov)
- [ ] **Step 3: Commit**

---

## Task 8: Testgen — gap detection + ranking

**Files:**
- Modify: `bin/superagent-testgen`
- Test: `test/test-testgen-gap.sh`

`gap` subcommand reads `last-report.json` and `min-coverage.txt`. For each file, `gap = target - current`. Sort by `gap × LOC` (impact). Output top-N (default 10) as a markdown table.

- [ ] **Step 1: Red test** — seed a report with 5 files at varied coverages. Assert ranking matches expected order.
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit**

---

## Task 9: Testgen — `suggest`

**Files:**
- Modify: `bin/superagent-testgen`
- Create: `test/fixtures/testgen/sample-src/auth.ts`
- Test: `test/test-testgen-suggest.sh`

For one file, output a markdown skeleton listing uncovered line ranges and suggested test names. Use `claude-mem:smart-explore` if available to pin to exported symbols; fall back to simple regex `^(export\s+)?(function|const|class|async\s+function)\s+(\w+)` for symbol extraction.

`suggest` NEVER writes test bodies. It outputs a skeleton; users (or the `tester` agent) implement.

- [ ] **Step 1: Red test** — assert output mentions each uncovered range, each named symbol, and includes at least one `- [ ] should_…` bullet.
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit**

---

## Task 10: Testgen — `status` + project threshold

**Files:**
- Modify: `bin/superagent-testgen`
- Test: `test/test-testgen-status.sh`

`status` prints current coverage, threshold, gap count, top file. `--json` mode for `ship`/`review` to consult. Threshold lives in `~/.superagent/testgen/min-coverage.txt`; default 70 when missing.

---

## Task 11: Testgen — skill + slash

**Files:**
- Create: `skills/testgen/SKILL.md` + `commands/testgen.md`
- Modify: `skills/superagent/brain/rules.yaml` (+testgen rule)
- Test: `test/test-testgen-docs.sh`

Frontmatter triggers on `coverage | untested | testgen | tdd gap | test scaffolding`. Procedure walks scan → gap → suggest. Slash forwards args to bin.

---

## Task 12: Diff-risk — classifier (commit msg + paths)

**Files:**
- Create: `bin/superagent-diff-risk`
- Create: `test/fixtures/diff-risk/corpus.jsonl`
- Test: `test/test-diff-risk-classify.sh`

Verbatim port of ruflo's regex map (spec §8.3). Multi-label classification: every type whose patterns match. Primary = highest match count; secondary = the rest (tie-broken by alphabetical type name for determinism).

Corpus has 20 sample diffs (5 each of feature / bugfix / refactor / docs|test mixed) with gold-labelled primary. Gate: ≥18/20 correct primary.

- [ ] **Step 1: Red test**
- [ ] **Step 2: Implement `classify` subcommand**
- [ ] **Step 3: Commit**

---

## Task 13: Diff-risk — impact score + risk factors

**Files:**
- Modify: `bin/superagent-diff-risk`
- Test: `test/test-diff-risk-impact.sh`

`IMPACT_KEYWORDS` table per spec §8.3. Score from path tokens + branch name. Map to `low | medium | high | critical`.

Risk-factor booleans (all 5 from spec §8.3): high-churn files (`git log --oneline <file> | wc -l > 20`), security paths, large diffs (>500 LOC), cross-module (≥3 top-level dirs), DB migrations.

- [ ] **Step 1: Red test** — seed git fixtures or use `SA_DIFF_RISK_FIXTURE` env var to inject a path list. Assert impact level + which risk factors flagged.
- [ ] **Step 2: Implement**
- [ ] **Step 3: Commit**

---

## Task 14: Diff-risk — reviewer recommendation from CODEOWNERS

**Files:**
- Modify: `bin/superagent-diff-risk`
- Create: `test/fixtures/diff-risk/CODEOWNERS`
- Test: `test/test-diff-risk-reviewers.sh`

Parse CODEOWNERS lines: `<glob>  @owner1 @owner2`. For each changed file, match against each glob (use `fnmatch`). Return union of owners.

No GitHub API. Pure file parsing. Honor `.github/CODEOWNERS`, `docs/CODEOWNERS`, root-level fallback.

---

## Task 15: Diff-risk — `report` (full output)

**Files:**
- Modify: `bin/superagent-diff-risk`
- Test: `test/test-diff-risk-report.sh`

Compose classifier + impact + risk factors + reviewers into the markdown report from spec §8.3. Cache at `~/.superagent/diff/last.json` for `ship`/`review` to consult.

`/diff-risk` slash + `/jujutsu` deprecation alias (prints `legacy alias; use /diff-risk` to stderr but still runs).

---

## Task 16: Diff-risk — skill + slash

**Files:**
- Create: `skills/diff-risk/SKILL.md` + `commands/diff-risk.md` + `commands/jujutsu.md` (alias)
- Modify: `skills/superagent/brain/rules.yaml` (+diff-risk rule)
- Test: `test/test-diff-risk-docs.sh`

Frontmatter triggers on `diff risk | impact score | blast radius | reviewer suggest | jujutsu | code owners`. Procedure walks classify → impact → reviewers → report.

---

## Task 17: Wire diff-risk into `review` skill

**Files:**
- Modify: `skills/review/SKILL.md`
- Test: `test/test-review-diff-risk.sh`

Add a section to the review procedure: "Step 0 — run `superagent-diff-risk` for pre-check; fold impact level into the verdict." Test asserts `skills/review/SKILL.md` mentions `superagent-diff-risk` and `critical|high`.

---

## Task 18: Wire diff-risk into `ship` skill

**Files:**
- Modify: `skills/ship/SKILL.md`
- Test: `test/test-ship-diff-risk.sh`

Add a pre-push gate: when impact is `high` or `critical`, the ship procedure force-confirms. Test asserts the gate text is documented and references the cached report.

---

## Task 19: Wire testgen into `ship` + `review`

**Files:**
- Modify: `skills/review/SKILL.md`
- Modify: `skills/ship/SKILL.md`
- Test: `test/test-testgen-integration.sh`

Both skills consult `~/.superagent/testgen/last-report.json` if present. `review` mentions coverage in its output; `ship` warns when coverage dropped vs the cached previous report.

---

## Task 20: Wave 3 — bench + install + state scaffold

**Files:**
- Modify: `bench/prompts.jsonl` (+5 prompts)
- Modify: `install.sh` (scaffold + marker)
- Modify: `hooks/superagent-state-init.sh`
- Test: `test/test-install-wave3.sh`

New bench prompts (id 38–42):

```text
{"id": 38, "prompt": "start sparc for the new comments feature", "archetype": "sparc", "expected_chain": ["mempalace-wake", "sparc"]}
{"id": 39, "prompt": "scan coverage and tell me where the gaps are", "archetype": "testgen", "expected_chain": ["mempalace-wake", "testgen"]}
{"id": 40, "prompt": "analyze the risk of this diff before push", "archetype": "diff-risk", "expected_chain": ["mempalace-wake", "diff-risk"]}
{"id": 41, "prompt": "show me the traceability matrix for feat-auth", "archetype": "sparc", "expected_chain": ["mempalace-wake", "sparc"]}
{"id": 42, "prompt": "suggest tests for the uncovered branches in src/auth.ts", "archetype": "testgen", "expected_chain": ["mempalace-wake", "testgen"]}
```

install.sh scaffolds `~/.superagent/{sparc,testgen,diff}/`, seeds `min-coverage.txt=70`, drops `.wave-3.installed` marker. Idempotent.

---

## Task 21: Wave 3 — docs (CHANGELOG + README + package.json + reel)

**Files:**
- Modify: `CHANGELOG.md` (v2.6.0 section)
- Modify: `README.md` (Wave 3 highlight block)
- Modify: `package.json` (version → 2.6.0; consider 3.0.0 if v3.0 is the target)
- Create: `docs/video/reel-wave3/{index.html,hyperframes.json,meta.json}` — 28 s composition

README highlight block: 3-row table — SPARC / Testgen / Diff-risk.

---

## Task 22: Wave 3 ship checklist

- [ ] Run full Wave 3 test suite in sequence.
- [ ] Wave 1 + Wave 2 regression.
- [ ] Bench at 42 prompts, hard gate ≥0.85.
- [ ] Recompile adapters (7 platforms).
- [ ] Tag `v2.6.0` (or `v3.0.0` if shipping as the v3 capstone).
- [ ] Open PR with `--base main` — explicitly NOT stacked.
  - **Important:** This is a fresh PR off main, not stacked on `wave-2-autonomous`. See `~/.claude/projects/.../memory/feedback_pr_stacking.md` for the lesson learned during Wave 2.
- [ ] `git push origin v<version> --follow-tags` only with explicit user approval.

---

## Self-review checklist

Before declaring this plan complete, verify:

1. **Spec coverage.** Every Wave 3 component in `docs/superpowers/specs/2026-05-08-superagent-v3-upgrade-design.md` §8 has at least one task:
   - §8.1 SPARC → Tasks 1–6. ✓
   - §8.2 Testgen → Tasks 7–11. ✓
   - §8.3 Diff-risk → Tasks 12–16. ✓
   - §8.4 Wave 3 testing → covered across each task's red/green block + Task 22 ship checklist. ✓

2. **Cross-cutting (§9) for Wave 3:**
   - §9.2 state hygiene → Task 20 scaffolds 3 new subdirs.
   - §9.3 defaults.toml → no new sections required; testgen threshold lives in its own file.
   - §9.4 migration → `.wave-3.installed` marker prevents repeat scaffolding.
   - §9.5 adapter recompile → Task 22 step 4.
   - §9.6 bench gate → Task 20 + Task 22 step 3.
   - §9.7 docs → Task 21.

3. **Boolean gate discipline.** SPARC gates are pass/fail — no 0.0–1.0 quality scores. Spec §8.1 is explicit on this; the gate test fixtures enforce it.

4. **Default behavior.** SPARC is opt-in per feature. Testgen and Diff-risk are passive bins (no daemon, no background loop) — `review`/`ship` integration is the auto-firing surface.

5. **No new runtime deps.** All three components use bash/python3/jq/git only. Testgen calls the project's own coverage tool — never bundled.

6. **Integration not replacement.** Diff-risk augments `review` + `ship`, doesn't replace either. Testgen never writes test bodies — the `tester` agent (Wave 2) does.

7. **PR strategy.** Open Wave 3 PR with `--base main`, NOT stacked on Wave 2. Branch from latest main once PR #3 (Wave 2 → main) lands.

8. **Renames honored.** `jujutsu` is the legacy alias only; canonical is `diff-risk`. The slash command at `commands/diff-risk.md` is the primary; `commands/jujutsu.md` prints a deprecation note and forwards.
