<div align="center">

<img src="docs/media/hero-superagent.svg" alt="SuperAgent — the routing brain that lives between your AI and your code" width="900" />

### One brain. Seven IDEs. 32 skills. 45/45 routing accuracy.

**Self-improving classifier. Per-prompt injection defense. 5-phase methodology gates. Per-diff risk scoring. Free local fallback. No rate limits.**

[![Stars](https://img.shields.io/github/stars/animeshbasak/SuperAgent?style=social)](https://github.com/animeshbasak/SuperAgent)
[![Platforms](https://img.shields.io/badge/platforms-8-blue)](#works-with-every-ai-coding-tool-you-use)
[![Bench](https://img.shields.io/badge/bench-45%2F45%20PASS-brightgreen)](#receipts)
[![Skills](https://img.shields.io/badge/skills-32-purple)](#the-29-skill-roster)
[![Version](https://img.shields.io/badge/v3.0.0-References_Integration_Pack-blueviolet)](#whats-new-in-v300--references-integration-pack)
[![Token Savings](https://img.shields.io/badge/token_savings-95%25-brightgreen)](#receipts)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install.sh
```

</div>

---

## 30-second pitch

SuperAgent is the layer between you and your AI coding tool. You write a task once. The brain classifies it against 32 skills, picks a chain, scans the prompt for injection, dispatches specialist work to 5 agent personas, enforces methodology gates when complexity warrants, scores every diff for blast radius before push, watches your budget, learns which chains actually worked, falls through to a free local model when limits hit — and writes the same instructions out to Cursor, Codex, Copilot, Gemini, Continue.dev, Windsurf, Aider, and Claude Code in their native formats.

**One config. Seven IDEs. Zero drift.**

---

## The v3 trilogy — what shipped in 2026

| Version | Wave | What it adds |
|---|---|---|
| [**v2.4.0**](CHANGELOG.md#v240--2026-05-09-wave-1-foundation) | 1 — Foundation | Self-improving classifier (patterns.jsonl learning loop) · full 9-event Claude Code hook lifecycle · 4-dim cost tracker · per-day budget alerts + auto-downgrade |
| [**v2.5.0**](CHANGELOG.md#v250--2026-05-12-wave-2-autonomous--safe) | 2 — Autonomous & Safe | AIDefence (58-pattern prompt injection + PII scanner) · 5 specialist dispatch agents · JSONL spans + metrics observability · `/loop` autopilot with budget gate |
| [**v2.6.0**](CHANGELOG.md#v260--2026-05-13-wave-3-methodology--quality) | 3 — Methodology & Quality | SPARC 5-phase gate-enforced pipeline · Testgen coverage gap detection + scaffolding · Diff-risk classifier + impact + reviewer recommendation |
| [**v3.0.0**](CHANGELOG.md#v300--2026-05-14-references-integration-pack--v3-capstone) | Capstone | References Integration Pack — `scraping` (Scrapling), `agent-pool` (Octogent), `dynamic-skills` (jcode). 32 skills, 22 bins, 45/45 bench. |

Default-off where they add risk (AIDefence, Autopilot, SPARC); on where they're additive (observability, learning loop, cost tracker).

---

## Install (~30 seconds, ~120 MB)

```bash
git clone https://github.com/animeshbasak/SuperAgent
cd SuperAgent
bash install.sh
```

`install.sh` is idempotent. Run it again to pick up updates; nothing duplicates.

### Smoke test in 10 seconds

```bash
# Routing brain answers correctly
superagent-classify "review my PR for SQL injection"
#  → {"chain":["mempalace-wake","review","simplify","cso","security-review","agent:reviewer"], …}

# Cost tracker reads your real Anthropic spend
superagent-cost today

# Learning loop store is alive
superagent-patterns list

# Diff scorer rates the current branch
superagent-diff-risk report
```

If all four return without error, the install worked. The full smoke run is in [`test/`](test/) — 58 scripts, ~5 seconds end-to-end.

---

## How it works

```
            ┌──────────────────────────────────────────────┐
            │  YOU TYPE: "fix the dark mode toggle bug"    │
            └────────────────────┬─────────────────────────┘
                                 │
                                 ▼
       ┌─────────────────────────────────────────────────────────┐
       │  ① CLASSIFY      superagent-classify                    │
       │     rules.yaml  +  patterns.jsonl (learning loop)       │
       │     → chain: [systematic-debugging, TDD, verification]  │
       │     → complexity · categories · history hint            │
       └────────────────────┬────────────────────────────────────┘
                            │
                            ▼
       ┌─────────────────────────────────────────────────────────┐
       │  ② DEFEND        UserPromptSubmit hook                  │
       │     superagent-safety (always) + aidefence (opt-in)     │
       │     → blocks rm -rf, --force, DROP, prompt injection    │
       │     → critical → deny · high → ask · PII → log          │
       └────────────────────┬────────────────────────────────────┘
                            │
                            ▼
       ┌─────────────────────────────────────────────────────────┐
       │  ③ ROUTE         3-tier cost router + 5 specialists     │
       │     T1 < 1ms   $0          (classify, format, lookup)   │
       │     T2 ~500ms  ~$0.0002    (Haiku / qwen-coder:7b)      │
       │     T3 2-5s    $0.003+     (Sonnet / Opus / qwen:next)  │
       │     90% budget → auto-downgrade.flag                    │
       │     complexity == complex → dispatch specialist agent   │
       └────────────────────┬────────────────────────────────────┘
                            │
                            ▼
       ┌─────────────────────────────────────────────────────────┐
       │  ④ EXECUTE       32 skills × 7 IDEs                     │
       │     SPARC gates · testgen · diff-risk · review · ship   │
       │     bench: 45/45 PASS · AVG 1.000 · HARD GATE PASS      │
       │     memory persists across sessions (mempalace)         │
       └────────────────────┬────────────────────────────────────┘
                            │
                            ▼
       ┌─────────────────────────────────────────────────────────┐
       │  ⑤ OBSERVE       JSONL spans + metrics + traces         │
       │     Every Stop: distill corrections + promote patterns  │
       │     superagent-trace <id>  · superagent-metrics today   │
       │     Daily rotation · 30d retention                      │
       └─────────────────────────────────────────────────────────┘
```

Every layer is a real, replaceable file. Every decision is logged to `~/.superagent/brain/routes.jsonl` so you can audit your own routing.

---

## The 29-skill roster

### Core orchestration (5)

| Skill | When it fires |
|---|---|
| `superagent` | Master router — classifies, composes chain, picks backend |
| `superagent-brain` | PROACTIVELY auto-routes every build / fix / explore / design / review / ship task |
| `superagent-safety` | Reversibility doctrine — pauses on risky shell + history-rewrite + sensitive-file edits |
| `superagent-switch` | Manual model swap with canary preflight |
| `auto-fallback` | Cost-aware switch to local LLM + 3-tier router |

### v2.4 — Wave 1 Foundation (2)

| Skill | When it fires |
|---|---|
| `superagent-learn-loop` | Patterns.jsonl learning loop — promote / decay / protect / prune |
| `cost-budget` | Per-day Anthropic budget alerts + auto-downgrade.flag at 90% spend |

### v2.5 — Wave 2 Autonomous & Safe (3)

| Skill | When it fires |
|---|---|
| `aidefence` | 58-pattern prompt-injection + PII scanner (default off; opt-in via `enable`) |
| `observability` | JSONL spans + metrics with p50/p95/p99 + rolling-mean anomaly detection |
| `autopilot` | `/loop` + pattern-driven prediction at 0.7 confidence + budget gate |

### v2.6 — Wave 3 Methodology & Quality (3)

| Skill | When it fires |
|---|---|
| `sparc` | 5-phase gate-enforced pipeline (Spec → Pseudo → Arch → Refine → Complete) |
| `testgen` | Coverage gap detection + markdown scaffolding (never writes test bodies) |
| `diff-risk` | 7-type classifier + IMPACT_KEYWORDS score + 5 risk factors + CODEOWNERS rec |

### Planning (4)

| Skill | When it fires |
|---|---|
| `plan-ceo-review` | Pressure-test plan scope (4-mode framework) |
| `plan-eng-review` | Lock architecture, edge cases, test coverage |
| `plan-design-review` | Rate 10 design dimensions 0-10, fix any below 7 |
| `autoplan` | Pipeline plan through CEO → design → eng review |

### Quality & review (4)

| Skill | When it fires |
|---|---|
| `investigate` | "Why did X break?" — reproduce → isolate → explain → verify |
| `review` | "Is this ready to merge?" — 6-point diff gate (calls diff-risk first) |
| `ship` | "Ship it" — 20-step pipeline with diff-risk pre-push force-confirm gate |
| `cso` | "Audit this" — OWASP Top-10 + STRIDE + secrets scan |

### Creative (3)

| Skill | When it fires |
|---|---|
| `webgl-craft` | Premium WebGL/3D — Awwwards-class technique library |
| `framer-motion` | React component-level motion (animate-presence, layout, springs) |
| `video-craft` | HTML → MP4 via hyperframes (deterministic, frame-accurate) |

### Utility (5)

| Skill | When it fires |
|---|---|
| `simplify` | Review changed code for reuse, quality, efficiency |
| `learn` | Persistent per-project learnings (`~/.superagent/learnings/`) |
| `office-hours` | YC-style product intake (6 forcing questions) |
| `fanout` | Run 2+ skills in parallel and merge their reports |
| `token-stats` | Token savings stats per project (mempalace + graphify) |
| `free-llm` | Set up free-claude-code proxy + provider routing |
| `bench` | Run the classifier bench and print the score |

Plus **6 specialist dispatch agents** under [`agents/`](agents/): `architect`, `coder`, `reviewer`, `security-architect`, `tester`, `superagent-brain`. The classifier picks a specialist when chain length > 4 or complexity = complex.

---

## What's new in v3.0.0 — References Integration Pack

> The v3 capstone. Three upstream projects in `references/` distilled into native SuperAgent skills + bins.

| Source project | Skill + bin | What it does |
|---|---|---|
| [**Scrapling**](https://github.com/D4Vinci/Scrapling) (D4Vinci) | `scraping` + `bin/superagent-scrape` | Anti-bot-aware web scraping (Cloudflare Turnstile bypass) via Scrapling's Python framework. Per-user venv at `~/.superagent/scraping/.venv`. Lazy install. `--ai-targeted` prompt-injection protection preserved. |
| [**Octogent**](https://github.com/hesamsheikh/octogent) (Hesam Sheikh) | `agent-pool` + `bin/superagent-pool` | Multi-Claude-Code parallel-session orchestration. `spawn` emits cooperative directives (no daemon, no process forking). State at `~/.superagent/pool/`. Distinguishes from Wave 2 specialist agents (those dispatch *roles* in one session; pool dispatches *parallel sessions* with separate context windows). |
| [**jcode**](https://github.com/1jehuang/jcode) (1jehuang) | `dynamic-skills` + `bin/superagent-reload` | Bash equivalent of jcode's PLAN_MCP_SKILLS Phase 1 — `list`/`sync`/`diff`/`status` for skill dirs. Honestly documents the limit: Claude Code doesn't expose a runtime skill-reload API to hooks, so the bin updates files; the user triggers the rescan via `/reload` or session restart. |

Distilled, not vendored. Each upstream credited in its SKILL.md + this CHANGELOG.

---

## What's new in v2.6.0 — Wave 3: Methodology & Quality

> The brain now enforces methodology, hunts uncovered behavior, and rates every diff before push.

| Pillar | What it does | CLI |
|---|---|---|
| **SPARC** | 5 phases — Specification → Pseudocode → Architecture → Refinement → Completion. Boolean gates per phase (no 0.0-1.0 fake-precision scores). Traceability matrix links every AC to a pseudo line, an arch entry, a test, and a status. | `superagent-sparc {init,gate,advance,report,status}` |
| **Testgen** | Coverage adapter (jest, vitest, pytest, tarpaulin, go-cover). Gap detection ranked by `gap × LOC`. `suggest <file>` emits a markdown skeleton with uncovered ranges and named symbols — never writes test bodies. | `superagent-testgen {scan,gap,suggest,status}` |
| **Diff-risk** | 7-type classifier (verbatim port from ruflo) + IMPACT_KEYWORDS scoring + 5 risk-factor booleans (high-churn, security paths, large diff, cross-module, DB migration) + CODEOWNERS reviewer recommendation. Pure git+file parsing — no GitHub API. | `superagent-diff-risk {classify,impact,reviewers,report}` |

`review` skill now runs `diff-risk` before the 6-point checklist. `ship` skill force-confirms before push when impact is `high` or `critical`.

[Full Wave 3 plan](docs/superpowers/plans/2026-05-13-superagent-v3-wave3-methodology.md) · [v2.4 Wave 1 plan](docs/superpowers/plans/2026-05-08-superagent-v3-wave1-foundation.md) · [v2.5 Wave 2 plan](docs/superpowers/plans/2026-05-13-superagent-v3-wave2-autonomous.md)

---

## Why this exists — the four taxes

You bought your AI coding tool. You like it. Then you noticed the bills.

**Tax #1 — Setup tax.** You wrote a `CLAUDE.md`. Then you bought Cursor. So you wrote `.cursorrules`. Then your team added Continue.dev. So you wrote `.continue/rules/*.md`. Then GitHub Copilot got smart, so you wrote `.github/copilot-instructions.md`. Same instructions, four formats, drifting apart in four files.

**Tax #2 — Token tax.** Every conversation, the model re-reads files it just read. Every "explain this codebase" burns the entire repo.

**Tax #3 — Rate-limit tax.** 4pm, shipping. Model says "wait 5 hours." The free local model on your laptop sits idle.

**Tax #4 — Blast-radius tax.** Your AI runs `git push --force` because you said "fix it and push." It runs `rm -rf` on a directory it misread. It commits to `main` because nobody told it `main` was sacred.

SuperAgent is the layer underneath. Write instructions once. Get them everywhere. Risky shell paused. Budget watched. Local model when you need it. Self-improving classifier that learns from your sessions.

---

## Works with every AI coding tool you use

| | Claude Code | Cursor | Codex | Copilot | Continue.dev | Windsurf | Gemini | Aider |
|---|---|---|---|---|---|---|---|---|
| **Skills auto-routed** | ✅ 29 | ✅ 7 (Cursor `.mdc`) | ✅ 29 (`AGENTS.md`) | ✅ inline | ✅ 30 (rule files) | ✅ 29 (rule files) | ✅ 29 (skill files) | ✅ `CONVENTIONS.md` |
| **Safety hooks** | ✅ 9 events | self-policed via skill | self-policed | self-policed | self-policed | self-policed | self-policed | self-policed |
| **Learning loop** | ✅ patterns.jsonl | reads same store | reads same store | reads same store | reads same store | reads same store | reads same store | reads same store |
| **Cost tracker** | ✅ live | ✅ live | ✅ live | ✅ live | ✅ live | ✅ live | ✅ live | ✅ live |
| **Specialist agents** | ✅ 5 + brain | dispatched as chain | dispatched as chain | dispatched as chain | dispatched as chain | dispatched as chain | dispatched as chain | dispatched as chain |

`bin/superagent-compile` rewrites the same 32 skills into each platform's native rule format. Hooks fire only on Claude Code; every other platform self-polices via the `superagent-safety` skill.

---

## Receipts

```bash
$ bash bench/run.sh
PROMPTS 42   PASS 42   FAIL 0   AVG 1.000
HARD GATE: PASS  (avg >= 0.90, fails <= 2)

$ for t in test/test-*.sh; do bash "$t" >/dev/null && echo "PASS: $t"; done | wc -l
58

$ superagent-aidefence list | wc -l
58           # injection + PII patterns ship out of the box
            # 100-prompt corpus: FP 2% / TP 86%

$ superagent-diff-risk report --base origin/main --json | jq .impactReport.impact
"medium"     # or low/medium/high/critical, scored from path tokens + branch name

$ superagent-cost today
model        tokens          $
opus              0      $0.00
sonnet      350,000     $5.25
haiku        80,000     $0.10
local       120,000     $0.00
TOTAL       550,000     $5.35
```

---

## Project layout

```
SuperAgent/
├── bin/                     19 CLI tools — installed to ~/.local/bin/
│   ├── superagent-classify  rule + pattern matcher
│   ├── superagent-cost      4-dim Anthropic price tracker
│   ├── superagent-patterns  learning loop (promote/decay/protect/prune)
│   ├── superagent-aidefence prompt injection + PII scanner
│   ├── superagent-autopilot /loop + pattern-driven prediction
│   ├── superagent-obs       span + metric emitter
│   ├── superagent-trace     parent-child trace tree with p95 bottleneck flag
│   ├── superagent-metrics   counter/gauge/histogram aggregator
│   ├── superagent-sparc     5-phase gate-enforced pipeline
│   ├── superagent-testgen   coverage gap + scaffolding
│   ├── superagent-diff-risk classifier + impact + reviewers
│   └── …
├── skills/                  32 skills (source of truth)
├── agents/                  6 specialist .md agents
├── hooks/                   9 Claude Code hooks
├── commands/                slash command dispatchers
├── bench/                   42-prompt routing accuracy harness
├── test/                    58 bash test scripts (red/green TDD style)
├── adapters/                7 IDE rule generators
├── install.sh               one-command install
└── docs/                    plans + specs + reels
```

Runtime state at `~/.superagent/`:

```
~/.superagent/
├── brain/        routes.jsonl + patterns.jsonl
├── cost/         calls.jsonl + budget.json + alerts.jsonl
├── learnings/    per-project distilled corrections
├── obs/          spans.jsonl + metrics.jsonl (daily rotated)
├── aidefence/    patterns.json + learned.jsonl + enabled flag
├── autopilot/    state.json
├── sparc/        <slug>/{state.json, spec.md, pseudo.md, …}
├── testgen/      last-report.json + min-coverage.txt
├── diff/         last.json (cached for review/ship)
├── safety/       allow.txt for auto-allow patterns
├── .wave-{1,2,3}.installed   idempotency markers
└── auto-downgrade.flag       drops at 90% budget
```

---

## FAQ

**I'm on Cursor, not Claude Code. Does it work?** Yes. `bin/superagent-compile` turns 32 skills into Cursor `.mdc` rules, Codex `AGENTS.md`, Copilot instructions, Continue rules, etc. Hooks fire on Claude Code only; every other platform self-polices via the `superagent-safety` skill.

**What if my Anthropic limit hits at 4pm?** The cost tracker watches your spend and drops `~/.superagent/auto-downgrade.flag` at 90% of daily budget. The `auto-fallback` skill reads this and shifts Opus → Sonnet → Haiku, or hands off to a local model (Ollama / qwen-coder / DeepSeek / llama.cpp) via the free-claude-code proxy on port `:18082`.

**Does SuperAgent change my code without asking?** Only when you ask. Risky operations (rm -rf, --force-push, DROP, .env edits) hit the safety gate first. AIDefence and Autopilot are default-off; you opt in via `enable` subcommands. SPARC is opt-in per feature.

**Is anything stored on your servers?** No. Everything lives under `~/.superagent/` and `~/.claude/`. SuperAgent does not phone home.

**Where do the receipts come from?** Every routing decision logs to `~/.superagent/brain/routes.jsonl`. Every tool call logs to `~/.superagent/cost/calls.jsonl` (v2 schema: 4-dim Anthropic tokens) and `~/.superagent/obs/spans.jsonl` (canonical span shape). You can `tail -f` any of them while you work.

**Where's the test coverage?** 58 bash test scripts under [`test/`](test/). Run `for t in test/test-*.sh; do bash "$t"; done` to see all of them green. The bench harness lives in [`bench/`](bench/).

---

## Reels

| Version | Reel | Run |
|---|---|---|
| v2.4 (Wave 1) | [`docs/video/reel-wave1/`](docs/video/reel-wave1/) | `npx hyperframes render` (Node ≥22) |
| v2.5 (Wave 2) | [`docs/video/reel-wave2/`](docs/video/reel-wave2/) | same |
| v2.6 (Wave 3) | [`docs/video/reel-wave3/`](docs/video/reel-wave3/) | same |

Each reel is a 28-second, 1920×1080, 30 fps hyperframes composition. Source HTML + GSAP timelines are committed; MP4 outputs are derivatives.

---

## License

MIT. See [LICENSE](LICENSE).

---

## Acknowledgements

- [HeyGen Hyperframes](https://github.com/heygen-com/hyperframes) for the deterministic video pipeline.
- [Anthropic Claude Code](https://claude.com/claude-code) for the hook-and-skill harness that made all of this possible.
- [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills) — 16 step-by-step engineering skills that ship as the `agent-skills:*` namespace.
- [Ruflo (claude-flow)](https://github.com/ruflo/claude-flow) — provided the AIDefence pattern store reference and the diff-risk classifier regex map.
