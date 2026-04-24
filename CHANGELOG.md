# Changelog

All notable changes to SuperAgent are documented here.

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
