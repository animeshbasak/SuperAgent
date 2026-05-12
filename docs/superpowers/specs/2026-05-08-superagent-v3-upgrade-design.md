# SuperAgent v3 Upgrade — Design Spec

**Date:** 2026-05-08
**Status:** Approved (brainstorming complete; awaiting user spec review before writing implementation plan)
**Owner:** animeshbasak
**Target versions:** v2.4.0 (Wave 1) → v2.5.0 (Wave 2) → v2.6.0 / v3.0.0 (Wave 3)
**Estimated total effort:** 4–5.5 weeks

---

## 1. Goal

Port ten capabilities from ruflo (`@claude-flow` v3.6) into SuperAgent without duplicating the memory and knowledge-graph layers we already get from MemPalace, claude-mem, and graphify. Ship in three dependency-ordered waves so each wave is independently shippable and the classifier becomes self-improving as early as Wave 1.

The lift makes three structural changes:

1. **The classifier learns.** Today's `bin/superagent-classify` is static. Wave 1 wires a pattern store that feeds back successful routes.
2. **Hooks become the integration surface.** Today SuperAgent has four hook events wired. Wave 1 raises that to all nine official Claude Code events; Waves 2–3 plug in along the same spine.
3. **Cost becomes enforceable.** Today `superagent-cost` reports totals. Wave 1 adds budget alerts and an auto-downgrade path that consumes the existing `auto-fallback` flag.

## 2. Scope

In scope (this spec): the ten ruflo picks listed in §3, grouped into three waves.

Out of scope (deferred to follow-up specs):

- Extracting ideas from jcode, Scrapling, octogent.
- SuperAgent UI (web or TUI).
- Federation (cross-machine agents).
- WASM kernels, AgentDB / HNSW backend, ONNX, OTel libraries.
- ruflo-ddd scaffolding plugin.
- ruflo-neural-trader, ruflo-market-data, ruflo-iot-cognitum (entirely out of scope).

Out of scope because already covered by the existing stack:

- Vector memory and semantic recall (MemPalace + claude-mem `mem-search`).
- Knowledge graph extraction (graphify).
- Cross-session corpora and "have we solved this?" workflows (claude-mem `knowledge-agent`).
- Cross-session context restore (mempalace `wake-up` + SessionStart hook).

## 3. The ten picks

| # | Pick | Wave | Why |
|---|---|---|---|
| 1 | Learning loop (pattern promote / decay / dedup) | 1 | Classifier compounds across sessions instead of drifting. |
| 2 | Full hooks lifecycle (5 net-new events) | 1 | Every other Wave plugs into hook events. |
| 3 | SPARC pipeline (5-phase gate-enforced) | 3 | Methodology layer; converts plan-* skills from review into enforced process. |
| 4 | Cost-tracker + budget alerts (4-dim pricing) | 1 | Existing `superagent-cost` reports; Wave 1 enforces. |
| 5 | Autopilot + prediction | 2 | Pairs `/loop` with pattern-driven next-action prediction. |
| 6 | Observability (JSONL spans + metrics) | 2 | Zero traces today; needed for everything else's diagnostics. |
| 7 | AIDefence (per-prompt PII + injection scan) | 2 | `cso` scans the repo; this scans each prompt. Different attack surface. |
| 8 | Specialist agents (architect / coder / reviewer / security-architect / tester) | 2 | One brain agent today; specialist dispatch unlocks parallel work. |
| 9 | Testgen (coverage gap detection) | 3 | TDD skill is process; testgen is automation. |
| 10 | Diff-risk (renamed from `jujutsu`) | 3 | `review` is LGTM/Block; diff-risk adds per-file impact + reviewer suggestion. |

---

## 4. Existing baseline (reuse, don't rebuild)

### 4.1 Skills (21)

`auto-fallback, autoplan, bench, cso, fanout, framer-motion, free-llm, investigate, learn, office-hours, plan-ceo-review, plan-design-review, plan-eng-review, review, ship, superagent, superagent-safety, superagent-switch, token-stats, video-craft, webgl-craft`

The `superagent` skill is the master router. `learn` is per-project JSONL — not a learning loop. `superagent-safety` already does the PreToolUse reversibility gate.

### 4.2 Bins (8)

`superagent-chain, superagent-classify, superagent-compile, superagent-cost, superagent-learn, superagent-oneshot, superagent-ship, superagent-switch`. Wave 1 extends `superagent-cost` and `superagent-learn`; later waves add new bins.

### 4.3 Hooks (today)

| Event | Script | Purpose |
|---|---|---|
| PreToolUse | `superagent-safety.py` | Reversibility gate, sensitive-path block |
| PostToolUse:Bash | `superagent-tracker.sh` | Cost JSONL + savings stats |
| SessionStart | `superagent-session-start.py` | Inject 50-line context block |
| Stop | `superagent-distill.sh` | Distill corrections into CLAUDE.md |

Missing (to be added across the waves): `UserPromptSubmit, SubagentStop, Notification, PermissionRequest, PreCompact`.

### 4.4 State root: `~/.superagent/`

```
agent-memory/         brain/routes.jsonl    cost/calls.jsonl
auto-fallback.flag    canary-last.json      free-claude-code/
bench/                chains/                free-llm.env
learnings/            limit-watch.lock       local-models.json
logs/                 safety/allow.txt       stats.json
switch.lock           switch.log
```

All v3 additions land as new subdirs under this root.

### 4.5 superagent-brain agent

`agents/superagent-brain.md` — auto-fires on every build/fix/explore/design/review/ship task. Carries its own scoped `hooks:` block so safety enforcement survives subagent dispatch. Wave 2 specialist agents follow the same pattern.

---

## 5. Architecture overview

### 5.1 Wave dependency graph

```
Wave 1 (Foundation, v2.4)
   ├─ Hooks lifecycle     ──┐
   ├─ Learning loop       ──┼──> Wave 2 (Autonomous & Safe, v2.5)
   └─ Cost-tracker schema ──┘     ├─ AIDefence (UserPromptSubmit hook)
                                   ├─ Specialist agents
                                   ├─ Observability (PreToolUse + PostToolUse spans)
                                   └─ Autopilot (patterns + budget gate)
                                        │
                                        v
                                   Wave 3 (Methodology & Quality, v2.6 / v3.0)
                                        ├─ SPARC
                                        ├─ Testgen
                                        └─ Diff-risk
```

### 5.2 Net-new artefacts

| Type | Count | Files |
|---|---|---|
| Bins | 10 | `superagent-aidefence, autopilot, diff, metrics, patterns, sparc, testgen, trace` (8 new) + extensions to `superagent-cost, superagent-learn` |
| Skills | 8 + 2 extended | `aidefence, autopilot, cost-budget, diff-risk, observability, sparc, testgen, superagent-learn-loop` (8 new) + extensions to `superagent, learn` |
| Agents | 5 | `architect, coder, reviewer, security-architect, tester` |
| Hooks | 5 | `prompt-submit, subagent-stop, notification, permission, precompact` |
| State subdirs | 9 | `aidefence, autopilot, brain/patterns, cost/budget+alerts, diff, obs, sparc, testgen` |
| Slash commands | 6 | `/aidefence, /autopilot, /diff-risk (alias /jujutsu), /observe, /sparc, /testgen` |

Estimated: ~2,500–4,000 lines Python/bash, ~1,750 lines markdown. Zero new global dependencies (no ONNX, sqlite, OTel libs, HNSW, WASM, AgentDB).

The only Claude Code-specific dependency is the `ScheduleWakeup` MCP tool, already available. All other features run on `python3 + bash + jq + git`.

---

## 6. Wave 1 — Foundation (v2.4)

### 6.1 Hooks lifecycle — 5 net-new scripts

5 Python hook scripts under `SA:/hooks/`, each ≤100 lines, following `superagent-safety.py`'s shape. Wired into `~/.claude/settings.json` by `install.sh` extending the `hooks.json` template.

| Event | Script | Behaviour |
|---|---|---|
| `UserPromptSubmit` | `superagent-prompt-submit.py` | Classify task; write announce block to stdout `additionalContext`. Wave 2 plugs aidefence into the same script. |
| `SubagentStop` | `superagent-subagent-stop.py` | Append outcome to `~/.superagent/brain/routes.jsonl` with `subagent:true` flag and cost attribution. |
| `Notification` | `superagent-notification.py` | Filter noisy notifications. Pass-through for `error`; drop most `info`. |
| `PermissionRequest` | `superagent-permission.py` | Auto-approve patterns matching `~/.superagent/safety/allow.txt`. Emits `{decision:"allow", reason}`. |
| `PreCompact` | `superagent-precompact.py` | Before window compacts: dump current routes/learnings into claude-mem. |

The four existing hooks (`PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`) are unchanged in shape; Wave 1 extends their **schema** but does not replace them.

Hook output contract follows the Claude Code 2026-04+ form:

```json
{"hookSpecificOutput":{
   "hookEventName":"<event>",
   "permissionDecision":"allow|ask|deny",
   "permissionDecisionReason":"..."}}
```

All hooks are configured with `continueOnError: true`. A crashing hook never blocks the user.

### 6.2 Learning loop — `~/.superagent/brain/patterns.jsonl`

Append-only JSONL, deduplicated by `(signal, chain)` SHA. Record shape:

```json
{"id":"p-<sha8>",
 "kind":"task-routing",
 "signal":"<keyword set, space-joined>",
 "chain":["skill1","skill2","skill3"],
 "successRate":0.83,
 "useCount":12,
 "lastUsed":"2026-05-08T19:30:00+00:00",
 "protected":false}
```

**Promote.** Stop hook calls `bin/superagent-patterns promote`. For routes whose `(signal,chain)` hash recurs ≥3 times with `outcome:done`, write or update a pattern record. Increment `useCount`; bump `successRate += 0.03` capped at `1.0`.

**Decay.** Same Stop hook calls `bin/superagent-patterns decay`. Per record:

```
successRate *= exp(-0.005 * hours_since_lastUsed)
```

Drop below `0.1`. Floor at `0.3` for `protected:true`.

**Protect.** `bin/superagent-patterns protect <id>` flips `protected:true`. Used for hand-curated "don't forget" routes.

**Classifier integration.** `bin/superagent-classify` reads `patterns.jsonl` after `rules.yaml`. The highest-confidence pattern match (signal-overlap × `successRate`) is prepended to the chain — but **only when** `successRate ≥ 0.6 AND useCount ≥ 5`. Below that gate, static rules win. Prevents one-off coincidence routing.

No EWC matrix, no embeddings. Pure JSONL plus Python.

### 6.3 Cost-tracker schema bump

**`calls.jsonl` schema v2** (v1 records auto-detected and migrated lazily on read):

```json
{"ts":"2026-05-08T19:30:00+00:00",
 "project":"<abs-path>",
 "tool":"<tool-name>",
 "model":"sonnet",
 "input_tokens":N,
 "output_tokens":N,
 "cache_write_tokens":N,
 "cache_read_tokens":N,
 "task_id":"<sha8>",
 "http_status":200,
 "pricing_version":"2026-Q2"}
```

`hooks/superagent-tracker.sh` extracts the four token dimensions from the transcript. Anthropic SDK exposes these as `usage.cache_creation_input_tokens` and `usage.cache_read_input_tokens`.

**Pricing config.** `bin/superagent-cost` carries a hardcoded default 4-dimension pricing table (Haiku/Sonnet/Opus × input/output/cache_write/cache_read), overridable via `~/.superagent/cost/pricing.json`. The `pricing_version` field on every record means rate changes don't corrupt historical totals.

Default pricing table (per 1M tokens, lifted from ruflo):

| Model | Input | Output | Cache Write | Cache Read |
|---|---|---|---|---|
| Haiku | $0.25 | $1.25 | $0.30 | $0.03 |
| Sonnet | $3.00 | $15.00 | $3.75 | $0.30 |
| Opus | $15.00 | $75.00 | $18.75 | $1.50 |

**Budget config.** New file `~/.superagent/cost/budget.json`:

```json
{"daily_usd":20,
 "monthly_usd":400,
 "alert_thresholds":[0.5,0.75,0.9,1.0],
 "auto_downgrade":{"at":0.9,"target":"sonnet"},
 "hard_stop":{"at":1.0,"mode":"prompt"}}
```

**Alert emit.** Each `superagent-cost` run computes `pct = used_usd / budget.daily_usd`. Crossing a threshold appends to `~/.superagent/cost/alerts.jsonl`:

```json
{"ts":"...","level":"warning","pct":0.78,
 "used_usd":15.6,"budget_usd":20,"action":"suggest-downgrade"}
```

At `0.9` the script drops `~/.superagent/auto-downgrade.flag` containing the target model. The `auto-fallback` skill already reads similar flags for Anthropic↔local switching; it is extended to honor downgrade for in-Anthropic tier shifts (Opus→Sonnet→Haiku).

**Hard-stop is a prompt, not a halt.** At 100% the script writes a confirm-required announce block. ruflo's silent halt is dangerous mid-ship.

### 6.4 Wave 1 data flow

```
UserPromptSubmit  ─► classify(rules.yaml + patterns.jsonl) ─► announce
PreToolUse        ─► safety gate (existing)
PostToolUse       ─► tracker.sh: 4-dim tokens + task_id ─► calls.jsonl
Stop              ─► distill (existing)
                  ─► patterns promote/decay ─► patterns.jsonl
superagent-cost   ─► pct check ─► alerts.jsonl + auto-downgrade.flag
auto-fallback     ─► reads downgrade.flag ─► swaps model
```

### 6.5 Wave 1 testing

- Extend `bench` to 25 prompts (5 added covering hooks/learning/cost keywords). Gate: ≥85%.
- Unit tests under `test/` for pattern decay/promote math (Python).
- Hook smoke tests: pipe sample stdin JSON to each hook; assert valid stdout JSON.

---

## 7. Wave 2 — Autonomous & Safe (v2.5)

Four components, ordered by independence: aidefence and specialist agents (low risk, high visibility) ship first, then observability (instrumentation), then autopilot (depends on patterns + budget gate from Wave 1, plus observability).

### 7.1 AIDefence — per-prompt scan

Wired into the `UserPromptSubmit` hook from Wave 1. Pure regex; no embeddings.

**Pattern store.** `skills/aidefence/patterns.json` ships with the skill. 50+ patterns lifted from ruflo's `threat-detection-service.ts:36-90`, each:

```json
{"regex":"ignore\\s+(all\\s+)?(previous\\s+)?instructions",
 "type":"instruction_override",
 "severity":"critical",
 "baseConfidence":0.95,
 "description":"..."}
```

Categories covered: `instruction_override, role_switching, prompt_injection, jailbreak, encoding_attack, context_manipulation`. PII regexes: emails, phone numbers, SSNs, credit cards, API keys (`sk-…`, `AKIA…`).

**Hook integration.** `superagent-prompt-submit.py` calls `bin/superagent-aidefence scan`, which returns:

```json
{"safe":false,
 "threats":[{"id":"...","type":"instruction_override","severity":"critical",
              "confidence":0.95,"location":{"start":0,"end":42}}],
 "detectionTimeMs":12.3,
 "piiFound":false,
 "inputHash":"<sha>"}
```

**Decision policy.**

| Severity | Decision |
|---|---|
| critical | `deny` (block tool use, message user) |
| high | `ask` (force-confirm) |
| medium | log only |
| PII detected | log + warn, don't block |

The PII rule is intentionally lenient: false-positive cost on legitimate code is too high to default to block.

**Adaptive learning.** `~/.superagent/aidefence/learned.jsonl` stores `{pattern_id, was_accurate, ts}` feedback pairs. EMA update on `effectiveness` (alpha=0.1):

```
effectiveness = 0.1 * (success ? 1 : 0) + 0.9 * effectiveness
```

Stop hook decays `effectiveness *= 0.99` per day. Drop ruflo's `recursionDepth` field — metaphysical fluff.

**Default off.** `~/.superagent/aidefence/enabled` flag absent at install. User opts in via `superagent-aidefence enable`. Reason: dev workflows mention "ignore previous" in legitimate contexts; too many false positives at first.

**Escape hatches.** Prompts inside fenced code blocks or starting with `// quote:` skip the gate.

**Performance budget.** <25ms per prompt (50 regexes × ~0.5ms compiled). Compiled patterns cached at module load.

### 7.2 Specialist agents — 5 new agent files

Markdown-with-frontmatter under `SA:/agents/`. Claude Code expects `.md` agents, not bare yaml.

| File | Model | Tools | Trigger |
|---|---|---|---|
| `architect.md` | sonnet | Read, Glob, Grep, Write, Edit | "design API", "system architecture", "DDD" |
| `coder.md` | sonnet | Bash, Read, Write, Edit, MultiEdit | "implement", "refactor", "debug X" |
| `reviewer.md` | haiku | Read, Glob, Grep, Bash | "review code", "audit diff" |
| `security-architect.md` | sonnet | Read, Glob, Grep, Bash | "threat model", "security review" |
| `tester.md` | sonnet | Bash, Read, Write, Edit | "write tests", "TDD", "coverage" |

Each file is ~50–80 lines: frontmatter, system prompt, skill chain hint, per-agent `hooks:` block scoping the safety hook to itself when dispatched as subagent (same pattern as `superagent-brain.md`).

**Routing rules.** `skills/superagent/brain/rules.yaml` extended with five rule blocks mapping keyword → specialist agent. Classifier prefers specialist when chain length > 4 OR complexity = high.

The `superagent-brain` agent remains the master router; specialists are dispatch targets, not replacements.

### 7.3 Observability — JSONL spans + metrics

No OTel libraries. Pure JSONL.

**Span store.** `~/.superagent/obs/spans.jsonl`:

```json
{"traceId":"t-<sha8>","spanId":"s-<sha8>","parentSpanId":null,
 "op":"superagent-route",
 "startMs":1715000000000,"endMs":1715000001234,
 "status":"OK",
 "attrs":{"chain_len":3,"backend":"anthropic","task_id":"..."}}
```

Status values: `OK | ERROR | TIMEOUT`.

**Metric store.** `~/.superagent/obs/metrics.jsonl`:

```json
{"ts":"...","name":"agent_task_duration_seconds",
 "kind":"histogram","value":1.23,
 "labels":{"task_type":"build"}}
```

Six canonical metric names lifted from ruflo: `agent_task_duration_seconds, agent_token_usage, agent_active_count, agent_error_rate, swarm_span_duration_ms, memory_operations_total`.

Metric kinds: `counter | gauge | histogram`.

**Trace ID propagation.** `superagent` skill sets `SA_TRACE_ID` env var at chain start. Downstream bins read it; if unset, generate new (root span). Cross-session boundary = new traceId. Don't try to span across SessionStart.

**Bins.**
- `bin/superagent-trace <traceId>` — read spans.jsonl, build parent-child tree, ASCII-print with timing and bottleneck flag (`> p95` of its `op`).
- `bin/superagent-metrics [period]` — aggregate counters/gauges/histograms over period; print table; p50/p95/p99 = sorted-position lookup.

**Anomaly detection.** Rolling mean + stddev over last `N=100` metric values per `name`. Flag values exceeding `mean + 2σ`. Output a flag line; never halt.

**Hook integration.** `PreToolUse` adds span-start, `PostToolUse` adds span-end. Folded into the existing `superagent-tracker.sh` rather than new scripts.

**Rotation.** Daily: rename to `spans.<YYYYMMDD>.jsonl`, prune > 30 days. Same for metrics.

**Histogram buckets.** Hardcoded `[0.1, 0.5, 1, 5, 10, 30, 60]` seconds.

### 7.4 Autopilot — `/loop` + prediction

**State.** `~/.superagent/autopilot/state.json`:

```json
{"sessionId":"...","enabled":false,
 "startTime":1715000000000,
 "iterations":3,"maxIterations":50,"timeoutMinutes":240,
 "taskSources":["markdown-checkboxes","routes-halt","tasks-md"],
 "lastCheck":1715000005000,
 "history":[{"ts":...,"iteration":1,"completed":2,"total":5}]}
```

Bounds enforced: `maxIterations ∈ [1, 1000]`, `timeoutMinutes ∈ [1, 1440]`. History capped at 50 entries.

**Task sources** (SA-specific, not ruflo's):

1. Markdown checkboxes in `cwd`: `grep -rE '^- \[ \]'`.
2. `~/.superagent/brain/routes.jsonl` records with `outcome:halt` (resumeable).
3. User-supplied `tasks.md` in `cwd`.

**Predict.** `bin/superagent-autopilot predict` reads pending tasks plus `~/.superagent/brain/patterns.jsonl` (Wave 1). Returns `{action, confidence, target}` where confidence = matched `pattern.successRate`.

**Confidence threshold.** `> 0.7` → execute prediction. `≤ 0.7` → fall back to highest-priority pending task. Empty → disable autopilot.

**Cache-warm wakeup.** Calls `ScheduleWakeup({delaySeconds: 270, reason: "autopilot iter"})`. Stays under Anthropic's 300s prompt-cache TTL. Tunable via `SUPERAGENT_CACHE_TTL_S` (default 270).

**Budget guardrail.** Cost-tracker (Wave 1) at 0.9 budget pauses autopilot until budget resets. Precedence: budget > rate-limit > preference. Resolves the autopilot/auto-fallback ping-pong.

**Slash:** `/autopilot enable | disable | config | status | predict`.

### 7.5 Wave 2 testing

- AIDefence corpus: 100 prompts (50 benign, 50 known-attack). Gate: <5% false-positive on benign, >85% true-positive on attack.
- Bench extended to 30 prompts; verify specialist routing keywords land on correct agent.
- Observability: synthetic span generator + trace-tree assertion. Verify rotation logic.
- Autopilot: mock `ScheduleWakeup`; verify state transitions and budget gate.

---

## 8. Wave 3 — Methodology & Quality (v2.6 / v3.0)

### 8.1 SPARC pipeline — 5-phase gate-enforced

Thin orchestrator that chains existing SA skills with hard boolean gate checks. Sequences skills; doesn't replace them.

| # | Phase | Output | Gate (must all pass) | SA skills used |
|---|---|---|---|---|
| 1 | Specification | `spec.md` | ≥3 acceptance criteria, constraints listed, edge cases identified | `agent-skills:spec-driven-development`, `office-hours` |
| 2 | Pseudocode | `pseudo.md` | covers all ACs, error paths explicit, complexity notes per algo | `agent-skills:planning-and-task-breakdown` |
| 3 | Architecture | `arch.md` | typed APIs, no circular deps, all constraints addressed | `architect` agent (Wave 2), `plan-eng-review` |
| 4 | Refinement | `refine.md` + traceability matrix | every AC has a passing test, no critical review issues, coverage ≥ project threshold | `agent-skills:incremental-implementation`, `agent-skills:test-driven-development`, `tester` agent, `review` |
| 5 | Completion | `complete.md` + ADRs | all tests green, docs complete, deploy checklist verified, traceability matrix complete | `agent-skills:documentation-and-adrs`, `superpowers:verification-before-completion`, `ship` |

**Gates are boolean, not 0.0–1.0 quality scores.** Easier to verify objectively; no fake-precision quality numbers.

**State.** `~/.superagent/sparc/<slug>/state.json`:

```json
{"slug":"feat-x","phase":3,
 "artifacts":["spec.md","pseudo.md","arch.md"],
 "gate_status":"open|passed|failed",
 "gate_failures":[{"phase":3,"reason":"circular dep detected","ts":"..."}],
 "createdAt":"...","updatedAt":"..."}
```

Artifacts live alongside state in the same directory.

**Bin** — `bin/superagent-sparc`:

| Subcommand | Behaviour |
|---|---|
| `init <feature-slug>` | Scaffold dir; mark phase 1 open |
| `gate` | Run gate checks for current phase; write pass/fail to state |
| `advance` | Gate must pass; bump phase. Refuses if gate not passed |
| `report` | Full traceability matrix output: AC → test → code |
| `status` | Current phase + gate |

**Slash:** `/sparc init | gate | advance | report | status`.

**Drop from ruflo:** the 1647-line `sparc-executor.ts` template generators (`generateRequirements`, `formatAcceptanceCriteria`). LLM generates artifact bodies in-context — that's its job. Also drop `.roomodes` per-project mode JSON; SPARC phases are intrinsic.

**Routing.** Classifier rule: keywords `spec | PRD | methodology | gate | sparc | spike | RFC` → SPARC orchestrator skill prefix.

### 8.2 Testgen — coverage gap detection + scaffolding

No bundled coverage parser. Calls the project's own tool; parses standardized output.

**Coverage adapter** (`bin/superagent-testgen`):

| Stack | Command | Output file |
|---|---|---|
| JS/TS (jest) | `npx jest --coverage --coverageReporters=json-summary` | `coverage/coverage-summary.json` |
| JS/TS (vitest) | `npx vitest run --coverage --coverage.reporter=json-summary` | `coverage/coverage-summary.json` |
| Python | `pytest --cov --cov-report=json` | `coverage.json` |
| Rust | `cargo tarpaulin --out Json` | `tarpaulin-report.json` |
| Go | `go test ./... -coverprofile=coverage.out` | `coverage.out` (manual parse) |
| Override | `~/.superagent/testgen/cov-cmd.txt` | user-supplied path |

**Gap detection.** `gap = targetCoverage - currentCoverage` per file. Sort by `gap × LOC` (impact). Top-N report.

**Per-project threshold.** `~/.superagent/testgen/min-coverage.txt` (default 70). Project-level override prevents a hard global gate from blocking legacy code.

**Test scaffolding.** For each gapped file, `superagent-testgen suggest <file>` outputs a markdown skeleton:

```markdown
## Suggested tests for src/auth.ts (62% → target 80%)
Uncovered lines: 42-68, 91-103, 124
- [ ] should_authenticate_valid_user (covers happy path L42-50)
- [ ] should_reject_invalid_credentials (covers error path L52-68)
- [ ] should_handle_expired_token (covers edge case L91-103)
```

Suggestions are pinned to actual exported symbols (read via `claude-mem:smart-explore` AST query — already installed) and uncovered line ranges.

**Testgen never writes test bodies itself.** The skeleton names tests; implementation flows through the `tester` agent and `superpowers:test-driven-development`.

**State.** `~/.superagent/testgen/last-report.json` cached for `ship`/`review` to consult without rerun.

**Routing.** Keywords `test | coverage | tdd | untested | spec` → testgen first, then TDD chain.

**Slash:** `/testgen scan | suggest | status`.

### 8.3 Diff-risk — renamed from `jujutsu`

Rename rationale: Jujutsu VCS exists; using "jujutsu" for a git-diff scorer creates collisions in user expectations. The legacy `/jujutsu` slash alias is retained with a deprecation note in `--help`.

**Diff source.** `git diff $base...HEAD` or `git diff --cached`. `git diff --numstat` for per-file additions/deletions.

**Classifier** — regex map verbatim from ruflo's `diff-classifier.ts:62-72`:

```python
CLASSIFICATION_PATTERNS = {
  "feature":  [r"^feat", r"add.*feature", r"implement", r"new.*functionality"],
  "bugfix":   [r"^fix", r"bug", r"patch", r"resolve.*issue", r"hotfix"],
  "refactor": [r"^refactor", r"restructure", r"reorganize", r"cleanup", r"rename"],
  "docs":     [r"^docs?", r"documentation", r"readme", r"\.md$"],
  "test":     [r"^test", r"spec", r"\.test\.[jt]sx?$", r"__tests__"],
  "config":   [r"^config", r"\.config\.", r"package\.json", r"\.env"],
  "style":    [r"^style", r"format", r"lint", r"prettier", r"eslint"],
}
```

Match commit-message prefix and file paths. Highest-confidence primary; the rest go into `secondary`.

**Impact score** — sum of `IMPACT_KEYWORDS[k]` over keywords found in path or branch name:

```python
IMPACT_KEYWORDS = {
  "security":3,"auth":3,"payment":3,"database":2,"api":2,"core":2,
  "util":1,"helper":1,"test":0,"mock":0,"fixture":0,
}
```

`≥5` → critical, `≥3` → high, `≥1` → medium, else low.

**Risk factors** (boolean):

1. Files with high churn history (`git log --oneline <file> | wc -l > 20`).
2. Security-sensitive paths (`auth/`, `crypto/`, `permissions/`, `.env`).
3. Large diffs (>500 lines).
4. Cross-module changes (≥3 top-level dirs touched).
5. Database migration files.

**Reviewer recommendation.** Read `.github/CODEOWNERS`, match changed paths, return owner globs. Pure file parsing; no GitHub API call.

**Output report:**

```
# Diff Analysis: feature/auth-revamp
Primary: feature  (conf 0.84)   Impact: high   Risk: medium-high
Files: 12  +320 -42
Risk factors:
  - Cross-module change (services/, api/, db/)
  - 2 security-sensitive paths (api/auth/, api/permissions/)
Suggested reviewers (CODEOWNERS): @sec-team @api-leads
Testing strategy: integration tests covering auth flow + permission boundaries.
```

**State.** `~/.superagent/diff/last.json` cached for `ship`/`review` chain.

**Slash:** `/diff-risk` (legacy alias `/jujutsu`).

**Integration:**

- `review` skill calls `diff-risk` first; findings included in review output.
- `ship` skill calls `diff-risk` before push; `high|critical` impact triggers force-confirm.

### 8.4 Wave 3 testing

- SPARC: 5 fixtures (one per phase) with passing and failing gate inputs. Assert state transitions.
- Testgen: 4 sample coverage files (jest, pytest, tarpaulin, go) committed under `test/fixtures/`. Assert gap detection.
- Diff-risk: corpus of 20 sample diffs (mix of feature/bugfix/refactor), assert primary classification and impact score.
- Bench extended to 35 prompts across all three waves. Gate ≥85%.

---

## 9. Cross-cutting concerns

### 9.1 Classifier extension order

`bin/superagent-classify` reads in order:

1. `skills/superagent/brain/rules.yaml` (existing static keyword rules)
2. `~/.superagent/brain/patterns.jsonl` (Wave 1 learned routes)
3. Specialist agent triggers (Wave 2 keyword → agent dispatch)
4. Wave 3 keyword rules (`spec|sparc` → SPARC, `coverage|tdd` → testgen, `diff|risk` → diff-risk)

Pattern match overrides static rules **only when** `successRate ≥ 0.6 AND useCount ≥ 5`.

### 9.2 State directory hygiene

| Path | Rotation | Prune |
|---|---|---|
| `cost/calls.jsonl` | daily → `calls.<YYYYMMDD>.jsonl` | 90 days |
| `obs/spans.jsonl` | daily | 30 days |
| `obs/metrics.jsonl` | daily | 30 days |
| `brain/routes.jsonl` | weekly | 365 days |
| `brain/patterns.jsonl` | never (dedup-compacted) | manual `superagent-patterns prune` |
| `aidefence/learned.jsonl` | monthly | 365 days |
| `cost/alerts.jsonl` | weekly | 90 days |
| `sparc/<slug>/` | manual (per-feature) | user-driven |

Rotation runs on `Stop` hook (cheap, runs at session end). Prune runs once daily (first hook of the day). Lock via existing `~/.superagent/*.lock` pattern.

### 9.3 Configurability — `defaults.toml`

Single source of truth: `~/.superagent/defaults.toml`. All magic numbers env-tunable, file-overridable, code-defaulted.

```toml
[learning]
decay_rate_per_hour = 0.005
boost_per_access = 0.03
min_confidence = 0.1
protected_floor = 0.3
promote_min_uses = 3

[cost]
pricing_version = "2026-Q2"
alert_thresholds = [0.5, 0.75, 0.9, 1.0]
hard_stop_mode = "prompt"

[autopilot]
cache_ttl_s = 270
max_iterations = 50
timeout_minutes = 240
prediction_threshold = 0.7

[aidefence]
ema_alpha = 0.1
daily_decay = 0.99
performance_budget_ms = 25
default_enabled = false

[obs]
histogram_buckets_s = [0.1, 0.5, 1, 5, 10, 30, 60]
anomaly_sigma = 2

[testgen]
default_min_coverage = 70
default_target_coverage = 85

[diff_risk]
critical_impact_threshold = 5
high_impact_threshold = 3
large_diff_lines = 500
```

Env override pattern: `SUPERAGENT_LEARNING_DECAY_RATE_PER_HOUR=0.01`. Bins parse `defaults.toml` once, then check env.

### 9.4 Migration plan

Forward-only. No downgrade scripts.

| From | To | Migrations |
|---|---|---|
| v2.3 → v2.4 (Wave 1) | (a) Backup `~/.superagent/cost/calls.jsonl` to `calls.v1.jsonl.bak`. (b) New writes use v2 schema; v1 records auto-detected by absence of `input_tokens`. **v1 cost computation:** treat `tokens` as `output_tokens` (conservative — Anthropic SDK historically reported this field as completion tokens), set the other three dimensions to 0. Records keep their original totals; future analytics splits new vs old via `pricing_version` presence. (c) Create `~/.superagent/cost/budget.json` with conservative defaults. (d) Append 5 hook entries to `~/.claude/settings.json`; idempotent. (e) Create empty `~/.superagent/brain/patterns.jsonl`. **Pre-existing `routes.jsonl` records ARE read by the promote loop on first run** — pattern store backfills naturally from history (subject to the `useCount ≥ 5` gate, so noise is filtered). |
| v2.4 → v2.5 (Wave 2) | (a) Drop 5 agent files into `~/.claude/agents/`. (b) Create `~/.superagent/{aidefence,autopilot,obs}/` skeletons. (c) AIDefence stays disabled. Print one-liner: `superagent-aidefence enable` to opt in. |
| v2.5 → v2.6 (Wave 3) | (a) Create `~/.superagent/{sparc,testgen,diff}/`. (b) New skills + bins. No state migration. |

**Idempotency contract.** Running install on already-installed wave is a no-op. Verified via marker files: `~/.superagent/.wave-{1,2,3}.installed`.

**Rollback.** Manual: rename `~/.superagent/.wave-N.installed`, revert hook entries. We do not delete user state on rollback.

**Backups.** Each wave install creates `~/.superagent/.backups/<ts>-pre-wave-N/` snapshot of mutated files. Garbage-collected after 30 days.

### 9.5 Adapter recompile

`bin/superagent-compile` (621 lines today) emits adapters for: aider, codex, continue, copilot, cursor, gemini, windsurf.

Each wave triggers a recompile run. New skills/agents/commands propagate per-platform.

**Hooks limitation.** Only Claude Code natively supports the 9-event hook protocol. Other adapters get **shim equivalents**:

- Codex: `AGENTS.md` rule + cli prompt-submit shim.
- Continue: rule + `.continuerc.json` snippet.
- Cursor / Copilot / others: rule files only (no hook surface).

**"Hooks-driven features" (Wave 1 hook lifecycle, Wave 2 aidefence, Wave 2 autopilot prediction) are Claude Code-first.** Other adapters get the skill bodies but degraded automation. Document per-adapter in `adapters/<name>/README.md`.

### 9.6 Bench gates per wave

Existing `bench` skill (20 prompts, ≥85%). Extended:

| Wave | New prompts | Cumulative | Gate |
|---|---|---|---|
| 1 | +5 (hooks/learning/cost) | 25 | ≥85% |
| 2 | +5 (aidefence/agents/obs/autopilot) | 30 | ≥85% |
| 3 | +5 (sparc/testgen/diff-risk) | 35 | ≥85% |

Hard merge gate per wave. Auto-runs in CI.

### 9.7 Documentation

Per wave, update:

- `README.md` — new feature row in capability table.
- `CHANGELOG.md` — version bump + summary.
- This spec — kept up-to-date as the single source.
- Per-skill: `skills/<name>/SKILL.md` body.
- Per-bin: `--help` text.
- `ETHOS.md` — unchanged.

### 9.8 Testing strategy

| Layer | Scope | Tooling |
|---|---|---|
| Unit | Bin logic (decay math, cost formula, regex matchers) | `pytest` for python, `bats` for shell |
| Integration | Hook stdin/stdout contract, classifier pipeline, install.sh idempotency | Test fixtures under `test/fixtures/` |
| Bench | Routing accuracy across waves | Existing `bench` skill |

CI runs all three on every PR. **No merge** if any layer fails.

### 9.9 Versioning + release cadence

| Version | Wave | Estimated |
|---|---|---|
| v2.4.0 | Wave 1 | 1.5–2 weeks |
| v2.5.0 | Wave 2 | 1.5–2 weeks |
| v2.6.0 / v3.0.0 | Wave 3 | 1–1.5 weeks |

Total: 4–5.5 weeks. v3.0.0 is the marketing flag at the end of Wave 3 (combined narrative). SemVer strict; in-wave fixes are patch releases.

---

## 10. Risks

1. **Classifier overload.** 21 → 30+ skills/agents. Bench enforces ≥85% routing accuracy as the new ones land.
2. **State directory bloat.** Five new subdirs × growing JSONL = inode pressure. Mandate the rotation table in §9.2.
3. **Hook chain timing.** `UserPromptSubmit → aidefence + classify` adds latency to every prompt. Target <50ms total. Cache compiled regexes; lazy-load classifier rules.
4. **Pricing drift.** Embed `pricing_version`. Quarterly review.
5. **Magic numbers.** `270s` cache-warm, `0.005/hr` decay, `0.1` EMA alpha — all live in `defaults.toml`, env-tunable, documented.
6. **Naming collisions.** `jujutsu` → `diff-risk` rename to avoid Jujutsu VCS confusion. Legacy alias retained.
7. **Auto-downgrade collisions.** Autopilot + cost-tracker + auto-fallback can ping-pong. Defined precedence: budget > rate-limit > preference.
8. **mempalace pipx-upgrade overwrite.** The status fix lives in the installed pipx site-package; `pipx upgrade mempalace` overwrites. Track + upstream the patch as a follow-up.
9. **Adapter degradation surprise.** Non-Claude-Code users may expect hook automation. Document degradation explicitly per adapter.
10. **Wave 1 hook-rollout regression.** Adding 5 hooks could expose harness bugs. Mitigate: ship hooks one at a time within the wave, each behind a feature flag in `defaults.toml` until validated.

## 11. Open questions

None blocking. Defaults documented; all decisions made via the brainstorming approval rounds.

**Implementation plan strategy:** because each wave is independently shippable and cumulatively non-trivial, the spec terminal is *not* one giant plan. Recommended path: write the **Wave 1 implementation plan first**, ship v2.4, then write Wave 2's plan, then Wave 3's. Each plan inherits this spec as its design source.

## 12. References

- Research doc: `/tmp/superagent-ruflo-research.md` (1231 lines, 10 picks fully extracted).
- ruflo source: `/Users/animeshbasak/Desktop/ai-lab/projects/references/ruflo/`.
- v2 plan: `docs/superpowers/plans/2026-04-24-superagent-v2.md`.
- Existing memory stack: MemPalace (`mempalace --help`), claude-mem MCP tools, graphify.
- Hook protocol: Claude Code 2026-04+ `permissionDecision` schema.

---

## 13. Approval log

- 2026-05-08 — User approved Wave 1 design (hooks, learning loop, cost-tracker schema bump).
- 2026-05-08 — User approved Wave 2 design (aidefence, specialist agents, observability, autopilot).
- 2026-05-08 — User approved Wave 3 design (SPARC, testgen, diff-risk).
- 2026-05-08 — User approved cross-cutting plan (defaults.toml, forward-only migration, hooks-Claude-Code-first, v3.0.0 = end of Wave 3).
