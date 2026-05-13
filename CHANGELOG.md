# Changelog

All notable changes to SuperAgent are documented here.

---

## v2.6.0 — 2026-05-13 (Wave 3: Methodology & Quality)

### Added
- **SPARC pipeline** (§8.1) — 5-phase gate-enforced methodology orchestrator. `bin/superagent-sparc` with `init <slug>` / `gate` / `advance` / `report` / `status` subcommands. Per-feature state under `~/.superagent/sparc/<slug>/` with `spec.md` → `pseudo.md` → `arch.md` → `refine.md` → `complete.md` artifacts. **Boolean gates per phase — no 0.0-1.0 quality scores.** Refuses to advance until the current gate passes.
- **Testgen** (§8.2) — `bin/superagent-testgen` with `scan` / `gap` / `suggest` / `status` subcommands. Coverage adapter for jest + pytest. Gap detection sorts by `gap × LOC`. `suggest <file>` emits a markdown skeleton with uncovered ranges + named symbols. **Testgen never writes test bodies.**
- **Diff-risk** (§8.3) — `bin/superagent-diff-risk` with `classify` / `impact` / `reviewers` / `report` subcommands. 7-type classifier, IMPACT_KEYWORDS score → `low/medium/high/critical`, 5 risk-factor booleans, CODEOWNERS reviewer recommendation. No GitHub API.
- **3 new user-facing skills**: `sparc`, `testgen`, `diff-risk`.
- **3 new slash commands**: `/sparc`, `/testgen`, `/diff-risk` (with legacy `/jujutsu` alias).

### Changed
- `skills/review/SKILL.md` — gains "Step 0 — diff-risk pre-check" that calls `superagent-diff-risk` and `superagent-testgen status` before the 6-point checklist.
- `skills/ship/SKILL.md` — gains "12b. Diff-risk pre-push gate". `high`/`critical` impact triggers force-confirm. Testgen `BELOW THRESHOLD` warns (warn-only by default).
- `skills/superagent/brain/rules.yaml` gains 3 new rules routing sparc/testgen/diff-risk keywords.

### Migration
- `install.sh` scaffolds `~/.superagent/{sparc,testgen,diff}/` and seeds `min-coverage.txt=70`. Drops `~/.superagent/.wave-3.installed` marker. Idempotent.

### Bench
- 42 prompts (5 added for Wave 3). Hard gate ≥85%; current AVG 1.000.

---

## v2.5.0 — 2026-05-12 (Wave 2: Autonomous & Safe)

### Added
- **AIDefence — per-prompt scan** (§7.1). `bin/superagent-aidefence` ships with 58 regex patterns across 6 attack categories (instruction_override, role_switching, prompt_injection, jailbreak, encoding_attack, context_manipulation) plus 8 PII detectors (email, phone, SSN, credit card, Anthropic/AWS/OpenAI/GitHub keys). Wired into `UserPromptSubmit` hook: critical severity → `deny`, high → `ask`, medium/PII → log only. Adaptive EMA effectiveness from `feedback` subcommand. Default off — opt-in via `superagent-aidefence enable`. 100-prompt corpus gate: FP<5%, TP>85%.
- **5 specialist dispatch agents** (§7.2): `architect`, `coder`, `reviewer`, `security-architect`, `tester`. Each carries a scoped `PreToolUse` safety hook so the gate survives subagent dispatch. Classifier routes specialist keywords to `agent:<name>` chain entries.
- **JSONL observability** (§7.3). 4 new bins: `superagent-obs` (canonical span + metric emitter), `superagent-trace` (parent-child tree with p95 bottleneck flag), `superagent-metrics` (counter SUM, gauge LAST, histogram p50/p95/p99 + rolling-mean anomaly), `superagent-obs-rotate` (daily rotation + 30d retention). `superagent-tracker.sh` now emits a span + `agent_token_usage` histogram on every tool call. Stop hook rotates daily via `.last-rotate-<YYYYMMDD>` marker.
- **Autopilot — `/loop` + pattern-driven prediction** (§7.4). `bin/superagent-autopilot` with bounded state (maxIterations ≤ 1000, timeoutMinutes ≤ 1440, history ≤ 50). 3-source task discovery (markdown checkboxes, `routes.jsonl outcome:halt`, `tasks.md`). `predict` uses `patterns.jsonl` from Wave 1 with a 0.7 confidence threshold. `iter` checks `auto-downgrade.flag` first (budget gate), then emits a `ScheduleWakeup` directive at 270s for cache-warm wake-ups (under Anthropic's 300s TTL). Default off.
- **3 new user-facing skills**: `aidefence`, `observability`, `autopilot`. Three slash commands: `/aidefence`, `/observe`, `/autopilot`.

### Changed
- `hooks/superagent-prompt-submit.py` now calls AIDefence when enabled flag present; degrades silently on missing bin or non-zero exit.
- `hooks/superagent-tracker.sh` emits Wave 2 obs records (span + token-usage metric) in addition to the v2 cost record.
- `hooks/superagent-distill.sh` calls `superagent-obs-rotate` on every Stop event (idempotent via daily marker).
- `skills/superagent/brain/rules.yaml` gains 9 new rules: 5 specialist routers (`agent-architect`/`agent-coder`/`agent-reviewer`/`agent-security-architect`/`agent-tester`) + `autopilot` + `observability` + `aidefence`. `agent-coder` regex covers `implement <feature>` / `refactor X` / `debug X` triggers.

### Migration
- `install.sh` scaffolds `~/.superagent/{aidefence,obs,autopilot}/` and seeds default `patterns.json` + autopilot `state.json`. Drops `~/.superagent/.wave-2.installed` marker. Idempotent — re-running install never duplicates state.

### Bench
- 37 prompts (6 added for Wave 2 keywords: threat-model, trace, p95 latency, scan prompt, autopilot, design API). Hard gate ≥85% maintained; current AVG 1.000.

---

## v2.4.0 — 2026-05-09 (Wave 1: Foundation)

### Added
- **Hooks lifecycle expanded** — 5 net-new events: `UserPromptSubmit`, `SubagentStop`, `Notification`, `PermissionRequest`, `PreCompact`. Total wired hooks: 4 → 9.
- **Learning loop** — `~/.superagent/brain/patterns.jsonl` store with promote/decay/protect/prune. Classifier prepends matched chains when `successRate ≥ 0.6 AND useCount ≥ 5`.
- **Cost-tracker schema v2** — 4-dim pricing (input/output/cache_write/cache_read), `pricing_version` field, v1 records auto-detected and treated as `output_tokens` only.
- **Budget alerts + auto-downgrade** — `bin/superagent-cost-alerts`, `~/.superagent/cost/budget.json`, `~/.superagent/auto-downgrade.flag`. Tiered alerts at 50/75/90/100% of daily budget.
- **`superagent-learn-loop` skill** — user-facing skill for the learning loop.
- **`cost-budget` skill** — user-facing skill for budget enforcement.
- **`bin/superagent-patterns`** — pattern store CLI.
- **`bin/superagent-cost-alerts`** — alert emitter + flag manager.
- **`~/.superagent/defaults.toml`** — single source of truth for magic numbers.

### Changed
- `auto-fallback` skill honors `auto-downgrade.flag` for in-Anthropic tier shifts (precedence: budget > rate-limit > preference).
- `superagent-classify` reads `patterns.jsonl` after `rules.yaml`.
- `superagent-tracker.sh` writes 4-dim records.
- `superagent-distill.sh` calls `superagent-patterns promote && decay` at session Stop.

### Migration
- v1 `calls.jsonl` records auto-detected and read transparently (no rewrite).
- Backup of pre-Wave-1 `calls.jsonl` saved to `~/.superagent/cost/calls.v1.jsonl.bak`.
- Idempotency marker at `~/.superagent/.wave-1.installed`.

### Bench
- 31 prompts (5 added for Wave 1 keywords: cost-budget, learn-loop, meta-routes, permission, tier-downgrade). Gate ≥85% routing accuracy; current avg 1.000.

---

## v2.2.0 — 2026-04-30

The multi-domain + cost-aware-routing release. SuperAgent now expands beyond code into video generation, and ships a cost-aware fallback brain that auto-routes to free/local LLMs when Anthropic limits approach. 4-engineer parallel review (skills/install/routing/marketing) drove this release; the locked plan is at `docs/plans/superagent-v2-2-multi-domain.md`.

### Added
- **`video-craft` skill** — HTML → MP4 via [hyperframes](https://github.com/heygen-com/hyperframes). 5 reference docs (architecture, animations, catalog, pipeline) + 4 production recipes (hello-world, product-ad-30s, data-driven-chart, lower-third-overlay). Triggers on "make a video", "render MP4", "lower third", "product ad", "GSAP", etc.
- **`free-llm` skill** — set up [free-claude-code](https://github.com/Alishahryar1/free-claude-code) as a transparent Anthropic-compatible proxy on port `:18082`. Privacy default: local-only (Ollama / llama.cpp); cloud free-tier (NIM, OpenRouter, DeepSeek) is opt-in only.
- **`auto-fallback` skill** — decides when to switch backends based on `meta.complexity` + budget signal. Trivial → suggest local, complex + over-budget → keep Anthropic with warning.
- **`bin/superagent-switch` CLI** — hot-swap LLM backend. Subcommands: `list` / `to <model>` / `back` / `auto on|off` / `status` / `canary <model> --depth=3`. flock + atomic writes throughout.
- **`hooks/superagent-limit-watch.sh`** — `UserPromptSubmit` hook (NOT PreToolUse). Reads `superagent-cost today --json`, fires warning when spend > 80%, 5h-limit < 30 min, or 429 burst >= 3 in 60s.
- **3-step canary preflight** — `Read → Edit → Bash` with fixtures under `test/canary-fixtures/`. Refuses switch if any step fails. Catches local-LLM tool-use breakage before it corrupts files.
- **`meta.complexity` field** in classifier output — `trivial | moderate | complex`. Namespaced under `meta` to preserve top-level JSON shape (existing 18 tests still pass). Compound matches use precedence `complex > moderate > trivial` (worst-case wins).
- **Bundles directory** — `bundles/hyperframes/`, `bundles/free-claude-code/`, `bundles/local-llms/` with idempotent OS-detecting installers (macOS + Linux). Separated from `adapters/` (instruction templates).
- **4 new install flags** in `install-universal.sh`:
  - `--with-video` (~120 MB: Node 22 + FFmpeg + hyperframes)
  - `--with-free-llm` (~5 GB: Ollama + qwen2.5-coder:7b + free-claude-code) — Claude Code only
  - `--with-near-opus` (~17 GB: llama.cpp + Qwen3.6-27B Q4_K_M) — Claude Code only, confirms first
  - `--full` — all of the above (~21 GB total)
- **9 new test files** — `test-canary.sh`, `test-switch-list.sh`, `canary-fixtures/{step1,step2,step3}.json`, plus skill verification harnesses.
- **README v2.2** — new pitches: "Your AI never runs out" (resilience framing for free-LLM), "Make videos with hyperframes" (below-fold halo product), "SuperAgent vs everything else" competitive table (Cursor / Cline / Aider / Copilot), expanded FAQ with privacy + context-preservation answers, `/render-stats --badge` for video-craft, "0 rate-limits hit" flex line.

### Changed
- **`hooks/superagent-tracker.sh`** — widened tool filter from Bash-only to include Read/Edit/Write/Grep/Glob (was missing the majority of session tokens). Adds synthetic token estimate per tool based on response size.
- **`bin/superagent-cost`** — added `local:<model>` price tier of $0 (markers: ollama, llamacpp, lmstudio, qwen, deepseek, minimax). Added `--json` flag for machine-readable output. Fixes the cost-meter deadlock that would have flatlined post-switch.
- **`skills/superagent/brain/rules.yaml`** — added `complexity:` field to every rule. Default = `moderate` when absent.
- **README.md** — full marketing rewrite. Hero stays as v2.1 opener with new subhead unifying all three pitches.

### Locked invariants
- `install.sh` MD5 = `bbb1ebc22cecf60106e33a25b001f130` (UNCHANGED — verified pre-merge)
- `CLAUDE.md` MD5 = `14485d2a80d452445c1f68e0b188254c` (UNCHANGED — verified pre-merge)
- All Claude Code surfaces (`skills/`, `agents/`, `hooks/superagent-tracker.sh` is widened but compatible, `bin/superagent-classify` is widened but top-level shape compatible) — additive only.

### Verification (all green)
- `test/test-classify.sh` 18/18 PASS
- `bench/run.sh` 20/20 PASS, AVG 1.000, HARD GATE PASS
- `test/test-canary.sh` 4/4 PASS
- `test/test-switch-list.sh` 3/3 PASS
- `superagent-compile --platform all` regenerates 7 platform adapters cleanly (now 17 skills, was 14)
- All new bash scripts `bash -n` clean
- Cursor templates at 3,496 chars (well under 12k cap)

### Engineering process notes
- Ran via `/superagent` with 4-engineer parallel review (skills, install, routing, marketing). Found 3 hard blockers (free-claude-code not on PyPI, fictional model IDs, cost-meter deadlock) before any code was written. All blockers fixed before implementation.

---

## v2.0.0 — 2026-04-24

The AI-brain release. SuperAgent is now a single-command router that reads your task, picks the right skill chain, and runs it — plus 10 new role-play skills imported and adapted from gstack.

### Added
- **`/superagent <task>`** — single-entrypoint AI router. Inline decision tree classifies the task, announces a skill chain, executes, logs.
- **Classifier** — `bin/superagent-classify`: regex-driven rules over `skills/superagent/brain/rules.yaml`, emits `{chain, hint}` JSON. Hint comes from prior successful routes (learning loop).
- **20-prompt bench** — `bench/prompts.jsonl` + `bench/run.sh` + `bench/score.sh` (ordered-LCS similarity, 0.85 threshold). HARD GATE: avg ≥ 0.90, fails ≤ 2.
- **CI bench gate** — `.github/workflows/bench.yml` runs on every PR that touches rules/classifier/bench.
- **7 imported role skills** — full-fidelity or compact, all gstack infra stripped:
  - `plan-ceo-review` (4-mode scope framework)
  - `plan-eng-review` (architecture lock-in)
  - `plan-design-review` (0-10 rubric, iterative)
  - `autoplan` (6 decision principles, CEO → design → eng orchestration)
  - `review` (6-point diff gate)
  - `investigate` (Iron Law, 4-phase root cause)
  - `ship` (20-step pipeline, bisectable commits)
- **3 native skills** — `office-hours` (6 forcing questions), `cso` (OWASP/STRIDE security audit), `learn` (per-project learnings jsonl).
- **Skill DAGs** — YAML chains under `skills/superagent/chains/` + `bin/superagent-chain` runner. Ships with `ship-v2` and `feature-build`.
- **`/fanout`** — parallel skill execution primitive via `dispatching-parallel-agents`.
- **Cost intelligence** — `bin/superagent-cost` converts token logs to $ by model (opus/sonnet/haiku), prints coach notes.
- **Stop hook auto-distill** — `hooks/superagent-distill.sh` captures corrections and writes them to `CLAUDE.md.superagent-proposed` (never mutates `CLAUDE.md` directly) + dual-writes to `~/.superagent/learnings/<hash>.jsonl`.
- **Context-rot gauge** — statusline warns at 300k tokens (Thariq threshold), shows plain gauge at 100k+.
- **`~/.superagent/` state root** — `{brain, bench, learnings, chains, cost, logs}` subdirs. Legacy `~/.claude/superagent-stats.json` auto-migrated.
- **ETHOS.md** — five guiding principles referenced by every skill.
- **`--local-only` install flag** — writes a marker at `~/.superagent/local-only` for hooks and tools to honor (privacy mode).
- **`superagent-brain` agent** rewritten as lightweight wake-up (loads mempalace context, hands off to `/superagent`).
- **13-skill install loop** + 4 `bin/` CLIs installed to `~/.local/bin/`.

### Changed
- `/superagent` skill was a stack activator; v2 makes it a task-routing entrypoint. v1 body preserved at `skills/superagent/SKILL.v1.md`.
- Bench scoring: exact-match replaced with ordered-LCS similarity (more robust to safe classifier permutations).

### Deferred to v2.1
- Deep state-path consolidation — v2.0 adds the new root and migration shim but leaves hooks' `~/.claude/superagent-stats.json` in place for backward compatibility.
- Deep full-text gstack adaptations for skills shipped compact in v2.0 (review, investigate, plan-eng-review, plan-design-review).

---

## [1.1.0] — 2026-04-22

### Added
- **webgl-craft skill** — Premium WebGL/3D creative web technique library
  - Five technique domains: Architecture, Shaders & 3D, Motion & Scroll, Interaction Surfaces, Pipeline & Performance
  - Six reference files distilled from Awwwards SOTY/SOTD teardowns (Igloo Inc, Lando Norris, Prometheus Fuels, Shopify Editions Winter '26)
  - Nine production-ready recipes: persistent canvas R3F, gravitational lensing shader (TSL), fluid cursor mask, MSDF text hero, scroll-uniform bridge, two-track frame budget, Barba-style transitions, AI terminal widget, audio-reactive gain
  - Auto-triggers on: Three.js, React Three Fiber, WebGL, shaders, GSAP ScrollTrigger, Lenis, Framer Motion, custom cursors, "cinematic", "Awwwards", "feels flat", and more
  - Installed to `~/.claude/skills/webgl-craft/` with `references/` and `recipes/` subdirs
- **install.sh Step 5b** — webgl-craft installed automatically as part of one-command setup
- **SuperAgent SKILL.md** — webgl-craft added to UI/UX roster table, master decision flow, and installation table
- **CHANGELOG.md** — this file

### Changed
- `install.sh` version banner updated to v1.1
- README rewritten with webgl-craft section, full skill reference table, and improved routing table

---

## [1.0.0] — 2026-04-17

### Added
- **superagent** — master routing skill + superagent-brain PROACTIVE agent
- **superpowers** — 20+ workflow skills (TDD, planning, debugging, reviews, git, security)
- **caveman** — ~75% token reduction communication mode
- **claude-mem** — cross-session memory + AST-level code search via tree-sitter
- **ui-ux-pro-max** — frontend design intelligence (50+ styles, 161 palettes, 57 font pairings, 161 product types)
- **graphify** — codebase → knowledge graph, 71.5x token reduction per query (Python/pipx)
- **mempalace** — local-first AI memory, 96.6% retrieval accuracy, no API key (Python/pipx)
- **token-stats skill** — `/token-stats` command with lifetime report and per-session breakdown
- **superagent-tracker.sh** — PostToolUse hook measuring real token savings per session
- **superagent-statusline.sh** — statusLine badge showing live compression ratio and total saved
- **install.sh** — one-command installer: plugins + Python tools + hooks + calibration + CLAUDE.md
- Calibration step: compression ratio measured from user's actual codebase, stored in `~/.claude/superagent-stats.json`
- Auto-indexing: mempalace indexes `~/.claude` and graphify builds skills knowledge graph on first install
