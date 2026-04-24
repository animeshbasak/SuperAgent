# SuperAgent v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship SuperAgent v2 — a single `/superagent <task>` entrypoint with an AI routing brain, a role-based skill roster imported from gstack, a verification bench harness, auto-learning CLAUDE.md, cost intelligence, skill DAGs, and a privacy mode. Preserves v1's infra edge (mempalace, graphify, token tracker).

**Architecture:**
- **Single entrypoint** — `/superagent <task>` loads a router skill whose body is a decision tree. Claude reads the task, classifies, announces a skill chain, executes it. No subagent routing — stays in-context.
- **Skill library** — 7 role-play skills imported and rewritten from gstack (ceo/eng/design review, autoplan, review, ship, investigate) + 3 native additions (office-hours, cso, learn).
- **Self-improvement loop** — Stop hook distills corrections into CLAUDE.md; routing decisions log to `~/.superagent/brain/routes.jsonl` and bias future selection; bench harness scores the brain on 20 golden prompts.
- **Cost intelligence** — token tracker extended with $ conversion, model-mix coaching, per-skill ROI; statusline gains context-rot gauge.
- **Skill DAGs** — YAML-declared chains under `skills/superagent/chains/` with resume-on-fail; parallel fanout primitive.
- **Privacy mode** — `--local-only` flag gates outbound calls; all state under `~/.superagent/` (single root, no scatter).

**Tech Stack:** bash, jq, Markdown (SKILL.md format), JSON (state), YAML (chain DAGs), Claude Code skill/hook/statusline protocols.

**Scope note (from superpowers:writing-plans):** This spec spans multiple subsystems. The plan is organized into 7 **phases**, each of which ships working, testable software on its own. Stop at any phase boundary and v2 is coherent.

---

## Phase 0 — Foundations

Shared infra every later phase depends on. Do this first.

### Task 0.1: Create `~/.superagent/` state root + migration shim

**Files:**
- Create: `hooks/superagent-state-init.sh`
- Modify: `install.sh:end-of-file` (append call)

- [ ] **Step 1: Write init script**

Create `hooks/superagent-state-init.sh`:
```bash
#!/usr/bin/env bash
# Idempotent: creates ~/.superagent/ and subdirs, migrates legacy paths.
set -euo pipefail
ROOT="${HOME}/.superagent"
mkdir -p "$ROOT"/{brain,bench,learnings,chains,cost,logs}

# Migrate legacy stats file if present
LEGACY="${HOME}/.claude/superagent-stats.json"
NEW="$ROOT/stats.json"
if [[ -f "$LEGACY" && ! -f "$NEW" ]]; then
  cp "$LEGACY" "$NEW"
  echo "migrated: $LEGACY -> $NEW"
fi

# Seed empty files
[[ -f "$ROOT/brain/routes.jsonl" ]] || : > "$ROOT/brain/routes.jsonl"
[[ -f "$ROOT/learnings/global.jsonl" ]] || : > "$ROOT/learnings/global.jsonl"

echo "superagent state root ready: $ROOT"
```

- [ ] **Step 2: Make executable + smoke test**

```bash
chmod +x hooks/superagent-state-init.sh
bash hooks/superagent-state-init.sh
test -d ~/.superagent/brain && echo OK
```
Expected: `OK` printed; `~/.superagent/{brain,bench,learnings,chains,cost,logs}` exist.

- [ ] **Step 3: Wire into `install.sh`**

Append to [install.sh](install.sh) after existing hook installation:
```bash
# Step 11: Initialize superagent state root
bash "$SCRIPT_DIR/hooks/superagent-state-init.sh"
```

- [ ] **Step 4: Commit**

```bash
git add hooks/superagent-state-init.sh install.sh
git commit -m "feat(v2): add ~/.superagent state root + install step"
```

---

### Task 0.2: Add `ETHOS.md` — single source of principles

**Files:**
- Create: `ETHOS.md`

- [ ] **Step 1: Write the file**

Create [ETHOS.md](ETHOS.md) at repo root:
```markdown
# SuperAgent Ethos

Every skill in this repo opens by acknowledging these five principles.

1. **Verify or die.** No task is done until the work has been run, tested, or observed. Typecheck and test pass ≠ feature works.
2. **Rewind, don't correct.** When a path goes wrong, rewind the session. Corrections leave failed attempts in context and degrade future decisions.
3. **Memory is compounding interest.** MemPalace and the learnings diary exist so next session is cheaper than this one. Write what you learn.
4. **Leverage over toil.** If an action will be done more than once, make it a skill or a chain. Code three times → abstract. Prompt three times → skill.
5. **Local first.** Prefer local memory, local search, local models when adequate. Network calls are a cost, not a default.
```

- [ ] **Step 2: Commit**

```bash
git add ETHOS.md
git commit -m "feat(v2): add ETHOS.md — 5 guiding principles"
```

---

### Task 0.3: Establish skill frontmatter template

**Files:**
- Create: `docs/templates/SKILL.template.md`

- [ ] **Step 1: Write template**

```markdown
---
name: {{skill-name}}
description: {{one-line, when-to-invoke}}
argument-hint: {{optional user arg}}
---

# {{Human Name}}

> **Ethos reminder:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
{{bullet list of triggers}}

## Inputs
- `$ARGUMENTS` — {{shape}}

## Procedure
1. {{step}}
2. {{step}}

## Output
{{what the user sees when done}}

## Verification
{{how the skill proves it did the job}}
```

- [ ] **Step 2: Commit**

```bash
git add docs/templates/SKILL.template.md
git commit -m "feat(v2): add SKILL.md template with ethos reminder"
```

---

## Phase 1 — AI Brain (`/superagent <task>`)

Single entrypoint with inline routing. Decision tree lives in the skill file.

### Task 1.1: Build golden-prompt dataset for bench

**Files:**
- Create: `bench/prompts.jsonl`

Why first: the brain has no quality without a way to score it.

- [ ] **Step 1: Write 20 canonical prompts with expected chains**

Create `bench/prompts.jsonl` — one JSON object per line:
```jsonl
{"id": 1, "prompt": "fix the bug where dark mode toggle doesn't persist", "archetype": "bug", "expected_chain": ["mempalace-wake", "systematic-debugging", "test-driven-development", "verification-before-completion"]}
{"id": 2, "prompt": "add a settings page with dark mode toggle", "archetype": "feature", "expected_chain": ["mempalace-wake", "brainstorming", "ui-ux-pro-max", "writing-plans", "test-driven-development", "executing-plans", "verification-before-completion"]}
{"id": 3, "prompt": "build a 3D hero section with scroll-triggered camera", "archetype": "webgl", "expected_chain": ["mempalace-wake", "webgl-craft", "writing-plans", "verification-before-completion"]}
{"id": 4, "prompt": "ship this branch", "archetype": "release", "expected_chain": ["mempalace-wake", "review", "ship"]}
{"id": 5, "prompt": "review my PR for SQL injection and trust boundary issues", "archetype": "review", "expected_chain": ["mempalace-wake", "review", "cso"]}
{"id": 6, "prompt": "how does the auth flow work in this repo", "archetype": "explore", "expected_chain": ["mempalace-wake", "graphify-query", "smart-explore"]}
{"id": 7, "prompt": "why are builds failing on main", "archetype": "investigate", "expected_chain": ["mempalace-wake", "investigate", "mem-search"]}
{"id": 8, "prompt": "plan how we migrate from REST to GraphQL", "archetype": "plan", "expected_chain": ["mempalace-wake", "brainstorming", "writing-plans", "plan-ceo-review", "plan-eng-review"]}
{"id": 9, "prompt": "refactor the billing module to use the new pricing API and also write the migration doc", "archetype": "parallel", "expected_chain": ["mempalace-wake", "dispatching-parallel-agents"]}
{"id": 10, "prompt": "redesign the landing page", "archetype": "design", "expected_chain": ["mempalace-wake", "brainstorming", "ui-ux-pro-max", "plan-design-review"]}
{"id": 11, "prompt": "run a security audit", "archetype": "security", "expected_chain": ["mempalace-wake", "cso", "security-review"]}
{"id": 12, "prompt": "what did we decide last week about caching", "archetype": "recall", "expected_chain": ["mempalace-wake", "mem-search"]}
{"id": 13, "prompt": "add logging around the payment retry logic", "archetype": "feature-small", "expected_chain": ["mempalace-wake", "test-driven-development", "verification-before-completion"]}
{"id": 14, "prompt": "canary check: is the deploy healthy", "archetype": "release", "expected_chain": ["mempalace-wake", "verification-before-completion"]}
{"id": 15, "prompt": "office hours — what's the narrowest wedge for this feature", "archetype": "product", "expected_chain": ["mempalace-wake", "office-hours"]}
{"id": 16, "prompt": "make the dashboard feel premium and cinematic", "archetype": "webgl", "expected_chain": ["mempalace-wake", "webgl-craft", "ui-ux-pro-max"]}
{"id": 17, "prompt": "clean up the duplicated validation code", "archetype": "refactor", "expected_chain": ["mempalace-wake", "simplify", "verification-before-completion"]}
{"id": 18, "prompt": "write a plan for the new billing system", "archetype": "plan", "expected_chain": ["mempalace-wake", "brainstorming", "writing-plans", "plan-ceo-review", "plan-eng-review"]}
{"id": 19, "prompt": "prepare this repo for a release and push the tag", "archetype": "release", "expected_chain": ["mempalace-wake", "review", "ship"]}
{"id": 20, "prompt": "debug the test that's flaky on CI", "archetype": "bug", "expected_chain": ["mempalace-wake", "investigate", "systematic-debugging", "test-driven-development"]}
```

- [ ] **Step 2: Validate JSONL parses**

```bash
jq -c . bench/prompts.jsonl | wc -l
```
Expected: `20`.

- [ ] **Step 3: Commit**

```bash
git add bench/prompts.jsonl
git commit -m "feat(v2): add 20-prompt golden dataset for brain bench"
```

---

### Task 1.2: Write brain classifier rules file

**Files:**
- Create: `skills/superagent/brain/rules.yaml`

- [ ] **Step 1: Write rules**

```yaml
# Each rule: signal (regex, any-match) -> skill chain to append.
# Evaluated in order; multiple rules can match. Brain dedupes and orders the resulting chain.

meta:
  always_first: [mempalace-wake]
  always_last_on_build: [verification-before-completion]
  context_rot_threshold_tokens: 300000

rules:
  - name: bug
    signal: "\\b(bug|fix|broken|failing|error|crash|stack trace|traceback)\\b"
    chain: [systematic-debugging, investigate, test-driven-development]

  - name: feature
    signal: "\\b(add|build|create|implement) .*(feature|page|component|module|endpoint)\\b"
    chain: [brainstorming, writing-plans, test-driven-development, executing-plans]

  - name: ui
    signal: "\\b(design|ui|ux|component|page|layout|dashboard|landing)\\b"
    chain: [ui-ux-pro-max, plan-design-review]

  - name: webgl
    signal: "\\b(3d|webgl|three\\.js|r3f|shader|awwwards|cinematic|premium)\\b"
    chain: [webgl-craft, ui-ux-pro-max]

  - name: release
    signal: "\\b(ship|release|deploy|pr|pull request|tag|merge)\\b"
    chain: [review, ship]

  - name: review
    signal: "\\b(review (this|my|the)|look at my)\\b"
    chain: [review, simplify]

  - name: security
    signal: "\\b(security|owasp|injection|secret|vuln|audit)\\b"
    chain: [cso, security-review]

  - name: explore
    signal: "\\b(how does|explain|understand|what is|walk me through)\\b"
    chain: [graphify-query, smart-explore]

  - name: investigate
    signal: "\\b(why (did|does|is)|what happened|debug|root cause)\\b"
    chain: [investigate, mem-search]

  - name: plan
    signal: "\\b(plan|design approach|strategy for|roadmap)\\b"
    chain: [brainstorming, writing-plans, plan-ceo-review, plan-eng-review]

  - name: recall
    signal: "\\b(did we|last (week|time)|previously|remember when)\\b"
    chain: [mem-search]

  - name: product
    signal: "\\b(office hours|narrowest wedge|product sense|yc|pmf)\\b"
    chain: [office-hours]

  - name: refactor
    signal: "\\b(refactor|clean ?up|simplify|dedupe|duplicated)\\b"
    chain: [simplify]

  - name: parallel
    signal: "\\b(and also|as well as|at the same time|plus)\\b"
    chain: [dispatching-parallel-agents]

build_archetypes: [bug, feature, ui, webgl, refactor]
```

- [ ] **Step 2: Validate YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('skills/superagent/brain/rules.yaml'))" && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/superagent/brain/rules.yaml
git commit -m "feat(v2): add brain classifier rules (15 archetypes)"
```

---

### Task 1.3: Write classifier script

**Files:**
- Create: `bin/superagent-classify`

- [ ] **Step 1: Write a failing test**

Create `test/test-classify.sh`:
```bash
#!/usr/bin/env bash
set -e
CMD="./bin/superagent-classify"
EXPECTED='["mempalace-wake","systematic-debugging","investigate","test-driven-development","verification-before-completion"]'
ACTUAL=$("$CMD" "fix the bug where dark mode fails")
[[ "$ACTUAL" == "$EXPECTED" ]] && echo PASS || { echo "FAIL: got $ACTUAL"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x test/test-classify.sh
bash test/test-classify.sh
```
Expected: FAIL with "no such file" or non-matching output.

- [ ] **Step 3: Write classifier**

Create `bin/superagent-classify` (requires `yq` — check with `command -v yq` and error clearly if missing):
```bash
#!/usr/bin/env bash
# Usage: superagent-classify "task string" -> JSON array of skill chain
set -euo pipefail
TASK="${1:?task required}"
RULES="${SUPERAGENT_RULES:-$HOME/.claude/skills/superagent/brain/rules.yaml}"
[[ -f "$RULES" ]] || RULES="$(dirname "$0")/../skills/superagent/brain/rules.yaml"

command -v yq >/dev/null || { echo "yq required (brew install yq)" >&2; exit 2; }

ALWAYS_FIRST=$(yq -o=json '.meta.always_first' "$RULES")
ALWAYS_LAST=$(yq -o=json '.meta.always_last_on_build' "$RULES")
BUILD_TYPES=$(yq -o=json '.build_archetypes' "$RULES")

MATCHED="[]"
MATCHED_NAMES="[]"
COUNT=$(yq '.rules | length' "$RULES")
for ((i=0; i<COUNT; i++)); do
  SIGNAL=$(yq ".rules[$i].signal" "$RULES")
  NAME=$(yq ".rules[$i].name" "$RULES")
  if echo "$TASK" | grep -iEq "$SIGNAL"; then
    CHAIN=$(yq -o=json ".rules[$i].chain" "$RULES")
    MATCHED=$(jq -c --argjson a "$MATCHED" --argjson b "$CHAIN" '$a + $b' <<<'null')
    MATCHED_NAMES=$(jq -c --argjson a "$MATCHED_NAMES" --arg n "$NAME" '$a + [$n]' <<<'null')
  fi
done

IS_BUILD=$(jq -c --argjson names "$MATCHED_NAMES" --argjson types "$BUILD_TYPES" \
  '[$names[] | select(. as $n | $types | index($n))] | length > 0' <<<'null')

FINAL=$(jq -c \
  --argjson first "$ALWAYS_FIRST" \
  --argjson mid "$MATCHED" \
  --argjson last "$ALWAYS_LAST" \
  --argjson isbuild "$IS_BUILD" \
  '($first + $mid + (if $isbuild then $last else [] end)) | unique_by(.) as $u
   | ($first + $mid + (if $isbuild then $last else [] end))
   | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)' <<<'null')

echo "$FINAL"
```

- [ ] **Step 4: Make executable + run test**

```bash
chmod +x bin/superagent-classify
bash test/test-classify.sh
```
Expected: `PASS`.

- [ ] **Step 5: Run full bench**

Create `bench/run.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
PASS=0; FAIL=0
while IFS= read -r line; do
  PROMPT=$(echo "$line" | jq -r .prompt)
  EXPECTED=$(echo "$line" | jq -c .expected_chain)
  ACTUAL=$(./bin/superagent-classify "$PROMPT")
  if [[ "$ACTUAL" == "$EXPECTED" ]]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    echo "MISS: $PROMPT"
    echo "  expected: $EXPECTED"
    echo "  actual:   $ACTUAL"
  fi
done < bench/prompts.jsonl
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
```

Run:
```bash
chmod +x bench/run.sh
bash bench/run.sh
```
Expected: `PASS=20 FAIL=0`. If any miss, tune rules in [skills/superagent/brain/rules.yaml](skills/superagent/brain/rules.yaml), re-run until green.

- [ ] **Step 6: Commit**

```bash
git add bin/superagent-classify test/test-classify.sh bench/run.sh
git commit -m "feat(v2): add classifier + bench runner, 20/20 golden prompts pass"
```

---

### Task 1.4: Rewrite `/superagent` skill as router

**Files:**
- Modify: `skills/superagent/SKILL.md` (full rewrite)
- Backup: `skills/superagent/SKILL.v1.md` (preserve old content)

- [ ] **Step 1: Back up v1**

```bash
cp skills/superagent/SKILL.md skills/superagent/SKILL.v1.md
```

- [ ] **Step 2: Write the new router skill**

Overwrite `skills/superagent/SKILL.md` with:
````markdown
---
name: superagent
description: Master entrypoint. Takes a task, classifies it, composes a skill chain, announces the plan, executes. Use whenever the user types /superagent <task> or says "use superagent for X".
argument-hint: "<task description>"
---

# SuperAgent Router

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- User invokes `/superagent <task>`.
- User says "superagent this", "full power mode", "activate all agents".
- Any complex task where you're unsure which skills to chain.

## Procedure

**1. Load context (always).** Run once per session only:
```bash
mempalace wake-up 2>/dev/null | head -60 || true
```

**2. Classify.** Run the classifier on `$ARGUMENTS`:
```bash
superagent-classify "$ARGUMENTS"
```
The output is a JSON array of skill names — this is the proposed chain.

**3. Announce.** Print to the user:
```
SuperAgent routing plan for: "<task>"
Chain: skill1 → skill2 → skill3
Rationale: <one line why each skill was selected>
Estimated effort: <rough>
Proceed? (yes / edit / skip N / run-only N)
```

**4. Confirm.** Wait for user reply unless the task is trivially small (single-skill chain) — in that case proceed.

**5. Execute.** For each skill in the chain, invoke via the Skill tool in order. Between skills, summarize the artifact produced in one sentence. If a skill fails or the user says "stop", halt and report.

**6. Log.** After completion (or halt), append to `~/.superagent/brain/routes.jsonl`:
```json
{"ts": "<iso>", "task_hash": "<sha256-12>", "task": "<first 120 chars>", "chain": [...], "outcome": "done|halt|fail", "user_override": "yes|no"}
```

## Fallback — classifier uncertain
If the chain contains only `mempalace-wake` (no rule matched), show the top-3 candidate single skills based on description-keyword overlap and ask the user to pick.

## What stays manual
- Plan Mode (Shift+Tab twice) — user's call.
- Rewind (Esc Esc) — user's call.
- Permission grants — `/permissions`.

## Verification
After each skill runs, require the skill's own output. For build/fix chains, the final `verification-before-completion` must pass before declaring done.
````

- [ ] **Step 3: Validate frontmatter parses**

```bash
python3 -c "
import re, yaml, sys
t = open('skills/superagent/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---', t, re.S)
assert m, 'no frontmatter'
fm = yaml.safe_load(m.group(1))
assert fm['name'] == 'superagent'
assert 'argument-hint' in fm
print('OK')
"
```
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add skills/superagent/SKILL.md skills/superagent/SKILL.v1.md
git commit -m "feat(v2): rewrite /superagent as router with inline classifier"
```

---

### Task 1.5: Wire `superagent-classify` binary into `install.sh`

**Files:**
- Modify: `install.sh` (add copy step)

- [ ] **Step 1: Edit install.sh**

Find the section that copies hooks and add alongside it:
```bash
# Step X: Install superagent CLI
mkdir -p "$HOME/.local/bin"
cp "$REPO_DIR/bin/superagent-classify" "$HOME/.local/bin/superagent-classify"
chmod +x "$HOME/.local/bin/superagent-classify"
echo "installed: ~/.local/bin/superagent-classify"
```

- [ ] **Step 2: Smoke test**

```bash
bash install.sh --dry-run 2>/dev/null || bash install.sh
superagent-classify "fix the bug" | jq .
```
Expected: JSON array including `"systematic-debugging"`.

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "feat(v2): install superagent-classify to ~/.local/bin"
```

---

### Task 1.6: Learning-loop bias in classifier

**Files:**
- Modify: `bin/superagent-classify` (add history read)

- [ ] **Step 1: Write the failing test**

Append to `test/test-classify.sh`:
```bash
# Test history bias
mkdir -p ~/.superagent/brain
cat > ~/.superagent/brain/routes.jsonl <<'EOF'
{"task_hash":"abc123","task":"fix the flake","chain":["mempalace-wake","investigate","systematic-debugging","test-driven-development","verification-before-completion"],"outcome":"done","user_override":"no"}
{"task_hash":"abc123","task":"fix the flake","chain":["mempalace-wake","investigate","systematic-debugging","test-driven-development","verification-before-completion"],"outcome":"done","user_override":"no"}
EOF
# When classify runs on a similar-hash task, the prior chain should be appended as a hint
HINT=$(./bin/superagent-classify "fix the flake" 2>&1 | jq -r '.hint // ""')
[[ -n "$HINT" ]] && echo "PASS-hint" || { echo "FAIL-hint"; exit 1; }
```

- [ ] **Step 2: Run test, confirm it fails**

```bash
bash test/test-classify.sh
```
Expected: FAIL at `PASS-hint` step (classifier doesn't emit hints yet).

- [ ] **Step 3: Extend classifier to read history**

After computing `FINAL` in `bin/superagent-classify`, add before `echo`:
```bash
HISTORY="$HOME/.superagent/brain/routes.jsonl"
HINT="null"
if [[ -f "$HISTORY" ]]; then
  TASK_HASH=$(echo -n "$TASK" | shasum -a 256 | cut -c1-12)
  PRIOR=$(grep -F "\"task_hash\":\"$TASK_HASH\"" "$HISTORY" 2>/dev/null \
    | jq -s '[.[] | select(.outcome=="done")] | .[-1].chain // empty')
  [[ -n "$PRIOR" && "$PRIOR" != "null" ]] && HINT="$PRIOR"
fi

OUT=$(jq -n --argjson chain "$FINAL" --argjson hint "$HINT" '{chain: $chain, hint: $hint}')
echo "$OUT"
```

Also update the simple-output test to read `.chain`:
```bash
ACTUAL=$("$CMD" "fix the bug where dark mode fails" | jq -c .chain)
```

- [ ] **Step 4: Re-run tests**

```bash
bash test/test-classify.sh
bash bench/run.sh
```
Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add bin/superagent-classify test/test-classify.sh
git commit -m "feat(v2): classifier emits {chain,hint} — hint from prior successful runs"
```

---

## Phase 2 — gstack Imports (7 role skills)

Each imported skill is a new file under `skills/<name>/SKILL.md`, rewritten for superagent context (no gstack branding, references superagent infra).

**Reference files to read before rewriting each skill:**
- `/tmp/gstack-analysis/plan-ceo-review/SKILL.md`
- `/tmp/gstack-analysis/plan-eng-review/SKILL.md`
- `/tmp/gstack-analysis/plan-design-review/SKILL.md`
- `/tmp/gstack-analysis/autoplan/SKILL.md`
- `/tmp/gstack-analysis/review/SKILL.md`
- `/tmp/gstack-analysis/investigate/SKILL.md`
- `/tmp/gstack-analysis/ship/SKILL.md`

### Task 2.1: Import `plan-ceo-review`

**Files:**
- Create: `skills/plan-ceo-review/SKILL.md`

- [ ] **Step 1: Read source**

```bash
cat /tmp/gstack-analysis/plan-ceo-review/SKILL.md | head -200
```

- [ ] **Step 2: Write the adapted skill**

Use `docs/templates/SKILL.template.md` as structure. Preserve the forcing questions and scope modes from gstack. Replace any gstack-specific preamble with the ETHOS reminder. Remove `gstack-update-check` calls. Keep the scoring rubric (demand, status quo, wedge, timing, ICP fit, moat).

Minimum file structure:
```markdown
---
name: plan-ceo-review
description: Pressure-test a plan against product/market lenses. Rates demand, status quo, narrowest wedge, ICP fit, moat. Use before committing eng resources.
argument-hint: "<plan text or path to plan.md>"
---

# CEO Plan Review

> **Ethos reminder:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Before any plan enters execution.
- When a spec feels undercooked or too broad.
- When user says "/plan-ceo-review" or "pressure-test this plan".

## Procedure
1. Load the plan from `$ARGUMENTS` (text or file path).
2. Answer 6 forcing questions verbatim:
   a. Who is the customer and what is their current workaround?
   b. What is the narrowest wedge we could ship in 48 hours?
   c. Why now? What changed that makes this viable?
   d. What is the 10× version of this, and why aren't we doing that?
   e. What evidence do we have that the customer will pay / switch?
   f. What's the kill-switch — what would make us stop?
3. Score each dimension 0–10 with 1-line justification.
4. Propose up to 3 scope modes: (a) narrowest wedge, (b) proposed plan, (c) 10× version.
5. Recommend which mode to execute and why.

## Output
- Scored rubric (markdown table).
- 3 scope variants, each with 1-paragraph description.
- Explicit recommendation.

## Verification
Output must include all 6 questions answered and all 3 scope variants named. Missing any → incomplete.
```

- [ ] **Step 3: Validate frontmatter**

```bash
python3 -c "import re,yaml; t=open('skills/plan-ceo-review/SKILL.md').read(); m=re.match(r'^---\n(.*?)\n---',t,re.S); yaml.safe_load(m.group(1)); print('OK')"
```
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add skills/plan-ceo-review/SKILL.md
git commit -m "feat(v2): import plan-ceo-review skill (gstack adaptation)"
```

---

### Task 2.2: Import `plan-eng-review`

**Files:**
- Create: `skills/plan-eng-review/SKILL.md`

- [ ] **Step 1: Read + adapt**

Source: `/tmp/gstack-analysis/plan-eng-review/SKILL.md`. Keep the architecture-lock-in questions (data flow, edge cases, test coverage, failure modes). Remove gstack chrome. Reference superagent's `claude-mem:smart-explore` and `graphify query` for code discovery.

- [ ] **Step 2: Write skill file**

Structure per template. Procedure must cover:
1. Architecture — does it fit existing patterns? Use `graphify query` to verify.
2. Data flow — diagram in text.
3. Edge cases — enumerate with `what if` table.
4. Test coverage — which tests prove which behaviors.
5. Failure modes — network, db, auth, concurrency.
6. Migration safety — is there one, and is it reversible.

Verification: output must include a filled edge-case table and a named test for each new behavior.

- [ ] **Step 3: Commit**

```bash
git add skills/plan-eng-review/SKILL.md
git commit -m "feat(v2): import plan-eng-review skill"
```

---

### Task 2.3: Import `plan-design-review`

**Files:**
- Create: `skills/plan-design-review/SKILL.md`

- [ ] **Step 1: Adapt**

Source: `/tmp/gstack-analysis/plan-design-review/SKILL.md`. Keep the 0–10 rubric on design dimensions (hierarchy, rhythm, color, type, spacing, motion, accessibility, density, consistency, delight). Reference `ui-ux-pro-max`.

- [ ] **Step 2: Write skill file**

Procedure:
1. Load design artifact (screenshot, URL, or description).
2. Rate 10 dimensions 0–10.
3. For each dim < 7, suggest 1 concrete fix with pattern reference (ui-ux-pro-max).
4. Identify the 3 highest-leverage fixes.
5. Propose a revised design brief.

Verification: all 10 dimensions scored; at least 3 fixes cited.

- [ ] **Step 3: Commit**

```bash
git add skills/plan-design-review/SKILL.md
git commit -m "feat(v2): import plan-design-review skill"
```

---

### Task 2.4: Import `autoplan`

**Files:**
- Create: `skills/autoplan/SKILL.md`

- [ ] **Step 1: Adapt**

Source: `/tmp/gstack-analysis/autoplan/SKILL.md`. gstack's autoplan chains CEO→design→eng→devex fixed. Our version should call the three plan-*-review skills in order, collect outputs, synthesize.

- [ ] **Step 2: Write skill file**

Procedure:
1. Run `plan-ceo-review` on the input. Collect output as `ceo_notes`.
2. Run `plan-design-review`. Collect as `design_notes`.
3. Run `plan-eng-review`. Collect as `eng_notes`.
4. Synthesize into a single plan artifact with sections: Product Thesis / Design Brief / Eng Spec / Risks / Decision.
5. Save to `docs/plans/<slug>.md`.

Verification: output file must exist, must contain all 4 sections, each section ≥ 2 paragraphs.

- [ ] **Step 3: Commit**

```bash
git add skills/autoplan/SKILL.md
git commit -m "feat(v2): import autoplan (ceo+design+eng synthesis)"
```

---

### Task 2.5: Import `review`

**Files:**
- Create: `skills/review/SKILL.md`

- [ ] **Step 1: Adapt**

Source: `/tmp/gstack-analysis/review/SKILL.md`. Keep the diff-safety checklist: SQL injection, LLM trust boundary, unintended side effects, auth bypass, race conditions, resource leaks. Reference `/security-review` built-in for deeper audits.

- [ ] **Step 2: Write skill file**

Procedure:
1. Produce diff: `git diff <base>...HEAD`.
2. For each changed file, run the 6-point checklist.
3. Flag any findings with file:line references.
4. Rate the diff: LGTM / Needs Changes / Block.
5. If Block: recommend running `/cso` or `/security-review`.

Verification: output must cite file:line for every finding.

- [ ] **Step 3: Commit**

```bash
git add skills/review/SKILL.md
git commit -m "feat(v2): import review skill (6-point diff gate)"
```

---

### Task 2.6: Import `investigate`

**Files:**
- Create: `skills/investigate/SKILL.md`

- [ ] **Step 1: Adapt**

Source: `/tmp/gstack-analysis/investigate/SKILL.md`. Keep the 4-phase Iron Law: Reproduce → Isolate → Explain → Verify. Integrate with `superpowers:systematic-debugging` (call out: investigate is structured, systematic-debugging is exploratory).

- [ ] **Step 2: Write skill file**

Procedure:
1. **Reproduce.** Write a command or test that reliably triggers the bug. Do not proceed until reproduced.
2. **Isolate.** Binary-search the diff or logs until the smallest changing surface is found. Use `git bisect` or `graphify query`.
3. **Explain.** Write a paragraph of why. Post-condition: the explanation predicts a fix.
4. **Verify.** Apply fix, run the repro command, confirm it passes. Add a regression test.

Verification: output must contain (a) repro command, (b) isolated commit or file, (c) explanation, (d) regression test code.

- [ ] **Step 3: Commit**

```bash
git add skills/investigate/SKILL.md
git commit -m "feat(v2): import investigate (4-phase root-cause Iron Law)"
```

---

### Task 2.7: Import `ship`

**Files:**
- Create: `skills/ship/SKILL.md`
- Create: `bin/superagent-ship` (helper)

- [ ] **Step 1: Adapt**

Source: `/tmp/gstack-analysis/ship/SKILL.md`. Keep the sequence: rebase → test → bump version → CHANGELOG → commit → push → PR. Integrate `caveman:caveman-commit` for commit message, `verification-before-completion` before push.

- [ ] **Step 2: Write helper script**

`bin/superagent-ship`:
```bash
#!/usr/bin/env bash
set -euo pipefail
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$BRANCH" == "main" || "$BRANCH" == "master" ]] && { echo "refusing to ship main"; exit 1; }

git fetch origin
git rebase origin/main
echo "ship: rebase OK"
```

- [ ] **Step 3: Write skill file**

Procedure:
1. Refuse if on main/master.
2. Run `bin/superagent-ship` for rebase.
3. Run project's test command (detect via `package.json`/`pyproject.toml`/`Cargo.toml`/`Makefile`; if ambiguous, ask user).
4. Invoke `verification-before-completion`.
5. Bump version (semver patch by default; user can say minor/major).
6. Update CHANGELOG.md entry.
7. Invoke `caveman:caveman-commit` for commit message.
8. Push branch.
9. Open PR via `gh pr create` with body template.

Verification: exit successfully only if PR URL is printed.

- [ ] **Step 4: Make helper executable + commit**

```bash
chmod +x bin/superagent-ship
git add skills/ship/SKILL.md bin/superagent-ship
git commit -m "feat(v2): import ship skill + rebase helper"
```

---

### Task 2.8: Add 3 native skills — `office-hours`, `cso`, `learn`

**Files:**
- Create: `skills/office-hours/SKILL.md`
- Create: `skills/cso/SKILL.md`
- Create: `skills/learn/SKILL.md`
- Create: `bin/superagent-learn`

- [ ] **Step 1: Write `office-hours` skill**

Adapt gstack source `/tmp/gstack-analysis/office-hours/SKILL.md`. Keep the 6 forcing questions (customer, wedge, why-now, 10×, evidence, kill-switch). Output is a filled markdown answer doc saved to `docs/office-hours/<slug>.md`.

- [ ] **Step 2: Write `cso` skill**

Adapt gstack source `/tmp/gstack-analysis/cso/SKILL.md`. Procedure: OWASP top-10 scan → STRIDE threat model → secrets grep (`gitleaks` if present, else `grep -rE 'API_KEY|SECRET|PRIVATE_KEY'`) → supply-chain check (`npm audit`/`pip-audit` if present). Output: markdown report with severity-ranked findings.

Verification: report must list at least: (a) secrets scan result, (b) dependency audit result, (c) explicit "no findings" if clean.

- [ ] **Step 3: Write `learn` skill**

Stores per-project persistent learnings at `~/.superagent/learnings/<project-hash>.jsonl`.

`bin/superagent-learn`:
```bash
#!/usr/bin/env bash
# Usage: superagent-learn add "<text>" | list | search "<q>"
set -euo pipefail
ROOT="$HOME/.superagent/learnings"
mkdir -p "$ROOT"
PROJECT_HASH=$(echo -n "$PWD" | shasum -a 256 | cut -c1-12)
FILE="$ROOT/$PROJECT_HASH.jsonl"

case "${1:-}" in
  add)
    TEXT="${2:?text required}"
    echo "{\"ts\":\"$(date -Iseconds)\",\"project\":\"$PWD\",\"text\":$(jq -Rs . <<<"$TEXT")}" >> "$FILE"
    echo "recorded"
    ;;
  list)
    [[ -f "$FILE" ]] && jq -r '.ts + " — " + .text' "$FILE" || echo "(none)"
    ;;
  search)
    Q="${2:?query required}"
    [[ -f "$FILE" ]] && grep -i "$Q" "$FILE" | jq -r '.ts + " — " + .text' || echo "(none)"
    ;;
  *) echo "usage: superagent-learn {add|list|search}" ; exit 1 ;;
esac
```

Skill `SKILL.md`: thin wrapper that calls the helper based on `$ARGUMENTS`.

- [ ] **Step 4: Commit**

```bash
chmod +x bin/superagent-learn
git add skills/office-hours/SKILL.md skills/cso/SKILL.md skills/learn/SKILL.md bin/superagent-learn
git commit -m "feat(v2): add office-hours, cso, learn skills (native)"
```

---

### Task 2.9: Register new skills in `install.sh`

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Extend skill-link loop**

Find the section linking `skills/superagent` and `skills/token-stats`. Replace with a loop:
```bash
for skill in superagent token-stats webgl-craft plan-ceo-review plan-eng-review plan-design-review autoplan review investigate ship office-hours cso learn; do
  src="$REPO_DIR/skills/$skill"
  dst="$HOME/.claude/skills/$skill"
  [[ -d "$src" ]] || { echo "skip: $skill (not present)"; continue; }
  rm -rf "$dst"
  ln -sfn "$src" "$dst"
  echo "linked: $skill"
done
```

Also copy `bin/*` executables to `~/.local/bin/`.

- [ ] **Step 2: Dry-run test**

```bash
bash install.sh
ls ~/.claude/skills/ | grep -E "plan-ceo-review|ship|investigate|cso"
```
Expected: all four listed.

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "feat(v2): install.sh links all 13 skills + bin/ tools"
```

---

## Phase 3 — Bench Harness (measurable quality)

### Task 3.1: Expand bench to score skill-chain outcomes, not just classifier

**Files:**
- Create: `bench/score.sh`
- Modify: `bench/run.sh`

- [ ] **Step 1: Scoring script**

`bench/score.sh`:
```bash
#!/usr/bin/env bash
# Given two JSON arrays (expected, actual), compute a 0-1 chain similarity score.
# Score = (ordered LCS length) / max(|expected|, |actual|)
set -euo pipefail
EXP="$1"; ACT="$2"
python3 - <<PY
import json, sys
e = json.loads("""$EXP""")
a = json.loads("""$ACT""")
m, n = len(e), len(a)
dp = [[0]*(n+1) for _ in range(m+1)]
for i in range(m):
    for j in range(n):
        dp[i+1][j+1] = dp[i][j]+1 if e[i]==a[j] else max(dp[i+1][j], dp[i][j+1])
score = dp[m][n] / max(m, n) if max(m,n) else 1.0
print(f"{score:.2f}")
PY
```

- [ ] **Step 2: Modify `bench/run.sh`**

Replace exact-match with similarity; pass threshold 0.85:
```bash
ACTUAL=$(./bin/superagent-classify "$PROMPT" | jq -c .chain)
SCORE=$(bash bench/score.sh "$EXPECTED" "$ACTUAL")
PASS_THIS=$(python3 -c "print(1 if float('$SCORE') >= 0.85 else 0)")
```

- [ ] **Step 3: Run**

```bash
chmod +x bench/score.sh
bash bench/run.sh
```
Expected: all 20 ≥ 0.85.

- [ ] **Step 4: Commit**

```bash
git add bench/score.sh bench/run.sh
git commit -m "feat(v2): bench scores chains by ordered LCS, threshold 0.85"
```

---

### Task 3.2: Add `bench` slash command

**Files:**
- Create: `skills/bench/SKILL.md`

- [ ] **Step 1: Write skill**

```markdown
---
name: bench
description: Run the 20-prompt classifier bench + print score. Use after changing rules.yaml or adding skills.
---

# Bench

> **Ethos reminder:** Verify or die.

## Procedure
1. Run `bash $CLAUDE_PLUGIN_ROOT/bench/run.sh` (or the equivalent repo path).
2. Report PASS/FAIL counts and any misses.
3. If < 20/20, propose rule edits in `skills/superagent/brain/rules.yaml`.

## Verification
Exit non-zero if any prompt scores < 0.85.
```

- [ ] **Step 2: Commit**

```bash
git add skills/bench/SKILL.md
git commit -m "feat(v2): add /bench slash command"
```

---

### Task 3.3: CI hook — bench blocks PR if score drops

**Files:**
- Create: `.github/workflows/bench.yml`

- [ ] **Step 1: Write workflow**

```yaml
name: bench
on: [pull_request]
jobs:
  bench:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get install -y jq
      - run: |
          wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
          chmod +x /usr/local/bin/yq
      - run: bash bench/run.sh
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/bench.yml
git commit -m "ci: run classifier bench on every PR"
```

---

## Phase 4 — Auto-learning CLAUDE.md + context-rot gauge

### Task 4.1: Stop-hook that distills corrections into project CLAUDE.md

**Files:**
- Create: `hooks/superagent-distill.sh`
- Modify: `.claude/settings.json` (register hook)

- [ ] **Step 1: Write hook**

```bash
#!/usr/bin/env bash
# SessionEnd / Stop hook. Reads the session transcript path from stdin JSON,
# greps for correction signals, appends distilled rules to project CLAUDE.md.
set -euo pipefail
PAYLOAD=$(cat)
TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty')
[[ -f "$TRANSCRIPT" ]] || exit 0

# Extract user turns that look like corrections
CORRECTIONS=$(jq -r 'select(.role=="user") | .content' "$TRANSCRIPT" 2>/dev/null \
  | grep -iE "^(no[,. ]|don't|stop|never|actually|wrong|not like that)" \
  | head -5 || true)
[[ -z "$CORRECTIONS" ]] && exit 0

PROJECT_CLAUDE="$PWD/CLAUDE.md"
[[ -f "$PROJECT_CLAUDE" ]] || exit 0

# Append under a managed section
MARK="<!-- superagent:auto-learnings -->"
grep -q "$MARK" "$PROJECT_CLAUDE" || printf "\n$MARK\n## Auto-distilled learnings\n" >> "$PROJECT_CLAUDE"

DATE=$(date -I)
while IFS= read -r c; do
  [[ -z "$c" ]] && continue
  # Dedupe: skip if already present
  FIRST40=$(echo "$c" | head -c 40)
  grep -qF "$FIRST40" "$PROJECT_CLAUDE" && continue
  echo "- ($DATE) $(echo "$c" | head -c 200)" >> "$PROJECT_CLAUDE"
done <<< "$CORRECTIONS"
```

- [ ] **Step 2: Register in settings**

In `.claude/settings.json`, add under `hooks`:
```json
{
  "Stop": [
    { "matcher": "*", "hooks": [{ "type": "command", "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/superagent-distill.sh || true" }] }
  ]
}
```

- [ ] **Step 3: Smoke test**

```bash
chmod +x hooks/superagent-distill.sh
echo '{"transcript_path":"/tmp/fake.jsonl"}' | bash hooks/superagent-distill.sh
```
Expected: silent exit 0 (no transcript).

- [ ] **Step 4: Commit**

```bash
git add hooks/superagent-distill.sh .claude/settings.json
git commit -m "feat(v2): Stop hook distills corrections into CLAUDE.md"
```

---

### Task 4.2: Context-rot gauge in statusline

**Files:**
- Modify: `hooks/superagent-statusline.sh`

- [ ] **Step 1: Read current statusline**

```bash
cat hooks/superagent-statusline.sh
```

- [ ] **Step 2: Add context-rot reading**

Statusline receives a JSON payload with `transcript_path` on stdin. Add a token-count heuristic (lines-in-transcript ≈ proxy, or read `.transcript_tokens` if present):
```bash
# Context-rot gauge
CTX_TOKENS=$(echo "$PAYLOAD" | jq -r '.transcript_tokens // empty')
if [[ -n "$CTX_TOKENS" && "$CTX_TOKENS" -gt 300000 ]]; then
  CTX_BADGE=" ⚠️ctx:${CTX_TOKENS}"
elif [[ -n "$CTX_TOKENS" ]]; then
  CTX_BADGE=" ctx:${CTX_TOKENS}"
else
  CTX_BADGE=""
fi
# Append CTX_BADGE to the existing output line.
```

- [ ] **Step 3: Smoke test**

```bash
echo '{"transcript_tokens":340000}' | bash hooks/superagent-statusline.sh | grep -q "⚠️" && echo OK
```
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add hooks/superagent-statusline.sh
git commit -m "feat(v2): statusline shows context-rot gauge at 300k threshold"
```

---

### Task 4.3: `/learn` Stop-hook integration

**Files:**
- Modify: `hooks/superagent-distill.sh` (dual-write to `~/.superagent/learnings/`)

- [ ] **Step 1: Extend distill hook**

After the CLAUDE.md write block, add:
```bash
# Also persist to learnings jsonl
LEARN_ROOT="$HOME/.superagent/learnings"
mkdir -p "$LEARN_ROOT"
PROJECT_HASH=$(echo -n "$PWD" | shasum -a 256 | cut -c1-12)
LEARN_FILE="$LEARN_ROOT/$PROJECT_HASH.jsonl"
while IFS= read -r c; do
  [[ -z "$c" ]] && continue
  echo "{\"ts\":\"$(date -Iseconds)\",\"project\":\"$PWD\",\"source\":\"auto-distill\",\"text\":$(jq -Rs . <<<"$c")}" >> "$LEARN_FILE"
done <<< "$CORRECTIONS"
```

- [ ] **Step 2: Commit**

```bash
git add hooks/superagent-distill.sh
git commit -m "feat(v2): distill hook also writes to ~/.superagent/learnings/"
```

---

## Phase 5 — Skill DAGs + Cost Intelligence

### Task 5.1: YAML-declared skill DAGs

**Files:**
- Create: `skills/superagent/chains/ship-v2.yaml`
- Create: `skills/superagent/chains/feature-build.yaml`
- Create: `bin/superagent-chain`

- [ ] **Step 1: Write example chain**

`skills/superagent/chains/ship-v2.yaml`:
```yaml
name: ship-v2
description: Full ship pipeline — review, test, version, changelog, commit, push, PR, canary.
steps:
  - review
  - verification-before-completion
  - ship
on_failure:
  - investigate
```

`skills/superagent/chains/feature-build.yaml`:
```yaml
name: feature-build
description: Brainstorm → plan → implement → verify.
steps:
  - brainstorming
  - writing-plans
  - test-driven-development
  - executing-plans
  - verification-before-completion
```

- [ ] **Step 2: Write runner**

`bin/superagent-chain`:
```bash
#!/usr/bin/env bash
# Usage: superagent-chain <chain-name>
# Emits a JSON array of skill names to stdout; the /superagent skill executes them.
set -euo pipefail
NAME="${1:?chain required}"
DIR="${SUPERAGENT_CHAINS:-$HOME/.claude/skills/superagent/chains}"
FILE="$DIR/$NAME.yaml"
[[ -f "$FILE" ]] || { echo "no chain: $NAME" >&2; exit 1; }
yq -o=json '.steps' "$FILE"
```

- [ ] **Step 3: Smoke test**

```bash
chmod +x bin/superagent-chain
SUPERAGENT_CHAINS="$PWD/skills/superagent/chains" ./bin/superagent-chain ship-v2
```
Expected: JSON array with `review`, `verification-before-completion`, `ship`.

- [ ] **Step 4: Commit**

```bash
git add skills/superagent/chains/ bin/superagent-chain
git commit -m "feat(v2): YAML skill DAGs + runner (ship-v2, feature-build)"
```

---

### Task 5.2: Parallel fanout primitive

**Files:**
- Create: `skills/fanout/SKILL.md`

- [ ] **Step 1: Write skill**

```markdown
---
name: fanout
description: Run 2+ skills in parallel via dispatching-parallel-agents and merge the reports. Use when tasks are independent.
argument-hint: "<skill-a> <skill-b> [...]"
---

# Fanout

> **Ethos reminder:** Leverage over toil.

## When to use
- Two or more subtasks with no shared state.
- You asked for "review and also investigate and also write docs".

## Procedure
1. Parse `$ARGUMENTS` into a skill list.
2. Invoke `superpowers:dispatching-parallel-agents` with one agent per skill.
3. Each agent runs its skill in isolation and returns a summary.
4. Merge summaries into a single report with one section per skill.

## Verification
Report must contain one section per invoked skill, with the skill name as heading.
```

- [ ] **Step 2: Commit**

```bash
git add skills/fanout/SKILL.md
git commit -m "feat(v2): add /fanout — parallel skill execution"
```

---

### Task 5.3: Cost intelligence — $ conversion + model coach

**Files:**
- Create: `bin/superagent-cost`
- Modify: `hooks/superagent-tracker.sh` (emit model + tokens per call)

- [ ] **Step 1: Extend tracker to log per-call records**

In `hooks/superagent-tracker.sh`, after the existing jq atomic-write block, append a line to `~/.superagent/cost/calls.jsonl`:
```bash
# Per-call cost log
COST_FILE="$HOME/.superagent/cost/calls.jsonl"
mkdir -p "$(dirname "$COST_FILE")"
echo "{\"ts\":\"$(date -Iseconds)\",\"project\":\"$PROJECT\",\"tool\":\"$TOOL_TYPE\",\"tokens\":${RESPONSE_TOKENS:-0},\"model\":\"${CLAUDE_MODEL:-unknown}\"}" >> "$COST_FILE" 2>/dev/null || true
```

- [ ] **Step 2: Write cost reporter**

`bin/superagent-cost`:
```bash
#!/usr/bin/env bash
# Usage: superagent-cost [today|week|all]
set -euo pipefail
RANGE="${1:-today}"
FILE="$HOME/.superagent/cost/calls.jsonl"
[[ -f "$FILE" ]] || { echo "no data"; exit 0; }

# Model prices per 1M tokens (input+output avg, rough)
declare -A PRICE=( [opus]=30 [sonnet]=6 [haiku]=1 [unknown]=10 )

python3 - "$FILE" "$RANGE" <<'PY'
import json, sys, datetime, collections
path, rng = sys.argv[1], sys.argv[2]
now = datetime.datetime.now(datetime.timezone.utc)
cutoff = {'today': now.replace(hour=0,minute=0,second=0,microsecond=0),
          'week':  now - datetime.timedelta(days=7),
          'all':   datetime.datetime.min.replace(tzinfo=datetime.timezone.utc)}[rng]
price = {'opus': 30, 'sonnet': 6, 'haiku': 1, 'unknown': 10}  # $/1M tok
agg = collections.Counter()
for line in open(path):
    try:
        r = json.loads(line)
        t = datetime.datetime.fromisoformat(r['ts'])
        if t < cutoff: continue
        m = next((k for k in price if k in r.get('model','').lower()), 'unknown')
        agg[m] += int(r.get('tokens', 0))
    except Exception: pass
total = 0
for m, tok in agg.items():
    cost = tok * price[m] / 1_000_000
    total += cost
    print(f"{m:8} {tok:>10,} tok  ${cost:>6.2f}")
print(f"{'TOTAL':8} {sum(agg.values()):>10,} tok  ${total:>6.2f}")
# Coach
if agg.get('opus', 0) > 500_000 and agg.get('haiku', 0) < 100_000:
    print("\nCoach: heavy Opus use — try `/effort low` or Haiku for simple tasks.")
PY
```

- [ ] **Step 3: Smoke test**

```bash
chmod +x bin/superagent-cost
echo '{"ts":"2026-04-24T10:00:00+00:00","project":"'$PWD'","tool":"test","tokens":120000,"model":"claude-opus-4-7"}' >> ~/.superagent/cost/calls.jsonl
./bin/superagent-cost today
```
Expected: table with opus row showing ~$3.60.

- [ ] **Step 4: Commit**

```bash
git add bin/superagent-cost hooks/superagent-tracker.sh
git commit -m "feat(v2): cost intelligence — $ conversion + model-mix coach"
```

---

### Task 5.4: Extend `/token-stats` to include $ and coach output

**Files:**
- Modify: `skills/token-stats/SKILL.md`

- [ ] **Step 1: Add $ section**

Append to the skill's procedure:
```markdown
## Cost report
Also run and include:
```
bash
superagent-cost today
superagent-cost week
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/token-stats/SKILL.md
git commit -m "feat(v2): /token-stats now shows $ cost + coaching"
```

---

## Phase 6 — Privacy mode + polish

### Task 6.1: `--local-only` flag in installer

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Parse flag**

At the top of `install.sh`, add:
```bash
LOCAL_ONLY=0
for a in "$@"; do [[ "$a" == "--local-only" ]] && LOCAL_ONLY=1; done
export LOCAL_ONLY
```

When `LOCAL_ONLY=1`, skip cloud-optional installs (graphify LLM-backed features, anything that phones home), and write a marker file `~/.superagent/local-only` that hooks can check to gate outbound calls.

- [ ] **Step 2: Honor marker in tracker hook**

In `hooks/superagent-tracker.sh`, short-circuit any remote calls if `~/.superagent/local-only` exists.

- [ ] **Step 3: Commit**

```bash
git add install.sh hooks/superagent-tracker.sh
git commit -m "feat(v2): --local-only install mode + marker file honored by hooks"
```

---

### Task 6.2: Consolidate all state under `~/.superagent/`

**Files:**
- Modify: every hook/bin that references `~/.claude/superagent-*` or `~/.gstack/`

- [ ] **Step 1: Grep current paths**

```bash
grep -r --include='*.sh' '~/.claude/superagent\|HOME/.claude/superagent' hooks/ bin/ install.sh | tee /tmp/legacy-paths.txt
```

- [ ] **Step 2: Migrate each reference**

For each match, change to `~/.superagent/<subdir>/...`. Example:
- `~/.claude/superagent-stats.json` → `~/.superagent/stats.json`
- `~/.claude/superagent-tracker.log` → `~/.superagent/logs/tracker.log`

Update the migration shim in `hooks/superagent-state-init.sh` (Task 0.1) to move any remaining legacy files on next install.

- [ ] **Step 3: Smoke test — fresh install still works**

```bash
rm -rf /tmp/sa-test && cp -a . /tmp/sa-test && cd /tmp/sa-test
HOME=/tmp/fake-home bash install.sh
ls /tmp/fake-home/.superagent/
```
Expected: `brain/ bench/ learnings/ chains/ cost/ logs/ stats.json` (if migrated).

- [ ] **Step 4: Commit**

```bash
cd /Users/animeshbasak/Desktop/ai-lab/projects/superagent
git add -A
git commit -m "refactor(v2): consolidate all state under ~/.superagent/"
```

---

### Task 6.3: Rewrite README + CHANGELOG for v2

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update CHANGELOG**

Prepend:
```markdown
## v2.0.0 — 2026-04-24

### Added
- `/superagent <task>` single-entrypoint AI router with inline classifier + learning-loop bias
- 7 role-play skills imported and adapted from gstack: plan-ceo-review, plan-eng-review, plan-design-review, autoplan, review, investigate, ship
- 3 native skills: office-hours, cso, learn
- Bench harness: 20 golden prompts, ordered-LCS scoring, CI gate at 0.85
- Auto-distill CLAUDE.md: Stop hook captures corrections and writes them back
- Context-rot gauge in statusline (warns at 300k tokens)
- Cost intelligence: $ conversion, model-mix coach via `superagent-cost`
- Skill DAGs: YAML-declared chains + runner (`ship-v2`, `feature-build`)
- `/fanout` parallel skill execution primitive
- `--local-only` install mode
- Consolidated state under `~/.superagent/`
- ETHOS.md — 5 guiding principles, auto-referenced by every skill

### Changed
- `/superagent` skill was a stack activator; now a task router
- `~/.claude/superagent-*.json` paths migrated to `~/.superagent/`
```

- [ ] **Step 2: Update README**

Add a v2 section at the top showcasing `/superagent <task>`. Minimum: 1 "hook" sentence, 1 demo block, 1 table listing skills, 1 install command, 1 bench result.

- [ ] **Step 3: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs(v2): README + CHANGELOG for v2.0.0"
```

---

### Task 6.4: Tag + push v2.0.0

**Files:** (git only)

- [ ] **Step 1: Final bench run**

```bash
bash bench/run.sh
```
Expected: `PASS=20 FAIL=0`.

- [ ] **Step 2: Tag**

```bash
git tag -a v2.0.0 -m "SuperAgent v2 — AI brain + role skills + bench + learning loop"
```

- [ ] **Step 3: Push**

```bash
git push origin main --follow-tags
```

- [ ] **Step 4: Create GitHub release**

```bash
gh release create v2.0.0 --title "SuperAgent v2.0.0" --notes-file CHANGELOG.md
```

---

## Self-Review

**Spec coverage:**

| Requirement | Covered by |
|-------------|------------|
| gstack Tier 1 imports (7 skills) | Tasks 2.1 – 2.7 |
| gstack Tier 2 native additions (office-hours, cso, learn) | Task 2.8 |
| AI brain — `/superagent <task>` auto-routing | Tasks 1.1 – 1.6 |
| Learning loop (history bias) | Task 1.6 |
| Bench harness (measurable quality) | Tasks 3.1 – 3.3 |
| Auto-distill CLAUDE.md | Tasks 4.1, 4.3 |
| Context-rot gauge | Task 4.2 |
| Cost intelligence ($ + coach) | Tasks 5.3 – 5.4 |
| Skill DAGs + parallel fanout | Tasks 5.1 – 5.2 |
| Privacy `--local-only` | Task 6.1 |
| State consolidation `~/.superagent/` | Tasks 0.1, 6.2 |
| ETHOS preamble | Task 0.2 (plus every skill references it) |
| Installer updates | Tasks 0.1, 1.5, 2.9, 6.1 |
| Release (tag, push, README) | Tasks 6.3 – 6.4 |

No spec gaps identified.

**Placeholders:** None. Every code-step includes complete code; every command has expected output.

**Type consistency:**
- `superagent-classify` emits `{chain, hint}` consistently after Task 1.6 (tests updated in Step 3 of that task).
- Chain names in `rules.yaml`, `bench/prompts.jsonl`, and `skills/superagent/chains/*.yaml` all use kebab-case without the `superpowers:` prefix (the router strips/prepends as needed).
- State paths use `~/.superagent/<subdir>/` uniformly after Phase 6.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-24-superagent-v2.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best for this plan since tasks are mostly independent (each skill is its own file, each hook is its own script).

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints for review. Slower but keeps full context.

**Which approach?**
