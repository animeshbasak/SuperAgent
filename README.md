<div align="center">

<img src="docs/media/hero-superagent.svg" alt="SuperAgent — the routing brain that lives between your AI and your code" width="900" />

### Stop paying for tokens your AI burned re-reading your codebase.

**One brain. Seven IDEs. 21 skills. 26/26 routing accuracy. Free local fallback. No rate limits.**

<a href="https://github.com/animeshbasak/SuperAgent/raw/main/docs/media/superagent-v2.2-reel.mp4">
  <img src="docs/media/superagent-v2.2-reel-poster.png" alt="SuperAgent v2.2 — 30-second feature reel (click to play)" width="820" />
</a>

<sub>30-second feature reel · rendered deterministically with <a href="https://github.com/heygen-com/hyperframes">hyperframes</a> via <code>/video-craft</code> · <a href="https://github.com/animeshbasak/SuperAgent/raw/main/docs/media/superagent-v2.2-reel.mp4">download MP4 (5.3 MB)</a></sub>

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install-universal.sh
```

[![Stars](https://img.shields.io/github/stars/animeshbasak/SuperAgent?style=social)](https://github.com/animeshbasak/SuperAgent)
[![Platforms](https://img.shields.io/badge/platforms-8-blue)](#works-with-every-ai-coding-tool-you-use)
[![Bench](https://img.shields.io/badge/bench-26%2F26%20PASS-brightgreen)](#proof)
[![Skills](https://img.shields.io/badge/skills-21-purple)](#21-skills-auto-routed)
[![Token Savings](https://img.shields.io/badge/token_savings-95%25-brightgreen)](#the-receipt-share-your-savings)
[![Free LLM Fallback](https://img.shields.io/badge/free_LLM-fallback-orange)](#act-2--the-system)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

</div>

---

## A short story about why this exists

### Act 1 — The four taxes nobody talks about

You bought your AI coding tool. You like it. Then you noticed the bills.

**Tax #1 — The setup tax.** You wrote a `CLAUDE.md`. Then you bought Cursor. So you wrote `.cursorrules`. Then your team added Continue.dev. So you wrote `.continue/rules/*.md`. Then GitHub Copilot got smart, so you wrote `.github/copilot-instructions.md`. Same instructions, four formats, drifting apart in four files.

**Tax #2 — The token tax.** Every conversation, the model re-reads files it just read. Every "explain this codebase" burns the entire repo. The pricing pages don't lie: 200K tokens at Sonnet rates is real money, every hour.

**Tax #3 — The rate-limit tax.** It's 4pm. You're shipping. The model says *"please wait 5 hours."* You can't, so you tab over and pay $20 to a different provider. The free local model on your laptop sits idle.

**Tax #4 — The blast-radius tax.** Your AI is fast. *Too* fast. It runs `git push --force` because you said "fix it and push." It runs `rm -rf` on a directory it misread. It commits to `main` because nobody told it `main` was sacred.

The vendors don't fix these because the bills are the product. So we built the layer underneath them.

---

### Act 2 — The system

SuperAgent is the layer between you and the model. You write your task once. The brain reads it, scores it against 21 skills, picks the chain, gates the risky calls, watches your budget, and falls through to a free local model the second your plan starts to bleed.

```
            ┌──────────────────────────────────────────────┐
            │  YOU TYPE: "fix the dark mode toggle bug"    │
            └────────────────────┬─────────────────────────┘
                                 │
                                 ▼
       ┌─────────────────────────────────────────────────────────┐
       │  ① CLASSIFIER     superagent-classify                   │
       │     → chain: [systematic-debugging, TDD, verification]  │
       │     → complexity: moderate                              │
       │     → categories: [debugging, ui]                       │
       └────────────────────┬────────────────────────────────────┘
                            │
                            ▼
       ┌─────────────────────────────────────────────────────────┐
       │  ② SAFETY GATE    PreToolUse hook + skill               │
       │     → blocks rm -rf, --force push, DROP, etc.           │
       │     → asks before edits to .env, .ssh, .pem, /etc/      │
       └────────────────────┬────────────────────────────────────┘
                            │
                            ▼
       ┌─────────────────────────────────────────────────────────┐
       │  ③ TIERED ROUTER  3-tier cost discipline                │
       │     T1 < 1ms   $0          (classify, format, lookup)   │
       │     T2 ~500ms  ~$0.0002    (Haiku / qwen-coder:7b)      │
       │     T3 2-5s    $0.003+     (Sonnet / Opus / qwen:next)  │
       │     budget tight → drop a tier · 429×3 → flip local     │
       └────────────────────┬────────────────────────────────────┘
                            │
                            ▼
       ┌─────────────────────────────────────────────────────────┐
       │  ④ SKILLS RUN     21 skills × 7 IDEs                    │
       │     bench: 26/26 PASS · AVG 1.000 · HARD GATE PASS      │
       │     memory persists across sessions (mempalace)          │
       └─────────────────────────────────────────────────────────┘
```

Each layer is a real, replaceable file. Nothing is magic. Every decision is logged to `~/.superagent/brain/routes.jsonl` so you can audit your own routing later.

---

### Act 3 — The receipts

```bash
$ bash bench/run.sh
PROMPTS 26   PASS 26   FAIL 0   AVG 1.000
HARD GATE: PASS  (avg >= 0.90, fails <= 2)

$ superagent-oneshot
total tasks   : 124
one-shot      : 109
retried       : 15
one-shot rate : 87.9%
  → routing is sharp

$ /token-stats
Lifetime
  Graphify queries  : 47      → 198k tokens saved
  Mempalace hits    : 23      → ~31k tokens saved
  Total saved       : ~229k tokens  ≈ $3.44 at Sonnet rates
  Free-LLM sessions : 12      → 0 rate-limits hit
```

You can paste the badge from `/token-stats --badge` straight into your repo README. Receipts as marketing.

---

## SuperAgent vs everything else

The cleanest way to read the table: SuperAgent is the *router*. Cursor / Cline / Aider are *clients*. Copilot is a *model*. claude-mem is *memory*. superpowers is *skills*. We are not a competitor to any of those — we are the layer that ties them together.

| | **SuperAgent** | Cursor | GitHub Copilot | Cline | Aider | Continue.dev | claude-mem | superpowers |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Routing brain (auto-classify task → skill chain)** | ✅ | — | — | — | — | — | — | — |
| **PreToolUse safety gate (rm -rf, force-push, DROP)** | ✅ | — | — | — | — | — | — | — |
| **3-tier cost-aware router (T1/T2/T3)** | ✅ | — | — | — | — | — | — | — |
| **Free LLM fallback w/ memory preserved** | ✅ | — | — | partial (BYO key) | partial (BYO key) | — | — | — |
| **Multi-platform compile (1 source → 7 IDEs)** | ✅ | locked to Cursor | locked to GitHub | locked to VS Code | locked to Aider CLI | locked to .continue | n/a | n/a |
| **Knowledge graph + cross-session memory** | ✅ graphify+mempalace | partial | — | — | — | — | ✅ memory-only | — |
| **Multi-domain (code + video + design + WebGL)** | ✅ | code only | code only | code only | code only | code only | code only | code only |
| **21 routed skills, ⩾0.90 hard-gate bench** | ✅ 26/26 | — | — | — | — | rules-only | — | unrouted |
| **Per-skill agent-memory** | ✅ | — | — | — | — | — | partial | — |
| **Open-source, local-first, no API key required** | ✅ MIT | proprietary | proprietary | MIT | Apache 2.0 | Apache 2.0 | MIT | MIT |
| **Token savings receipt + shareable badge** | ✅ | — | — | — | — | — | — | — |

We do not replace your IDE. We do not replace your model. We replace the duct-tape between them.

---

## What's new in this release

- **Reversibility-aware safety gate** — Python `PreToolUse` hook (Claude Code) + universal `superagent-safety` skill (other 6 IDEs). Pauses on `rm -rf`, `git push --force`, `--no-verify`, `DROP TABLE`, `--dangerously-skip-permissions`, edits to `.env` / `.ssh` / `.pem` / `/etc/`. Bypass surface: env var, regex allow-list, CLAUDE.md bullets.
- **3-tier router formalized** in `auto-fallback`: T1 local <1ms ($0), T2 Haiku/qwen ~500ms (~$0.0002), T3 Sonnet/Opus 2-5s ($0.003+). No silent fallthrough — every flip is logged.
- **Per-skill agent memory** at `~/.superagent/agent-memory/<skill>/`. Distinct from the global `mempalace` index. Templates for `ship`, `review`, `investigate`.
- **`.mcp.json` baseline**: `playwright`, `context7`, `deepwiki` pinned with `MCP_GROUP` env tags.
- **13-category multi-label classifier tags**: every task gets `meta.categories: [debugging, ui, …]` for telemetry without changing routing.
- **`superagent-oneshot`** CLI — measures routing health from `routes.jsonl`.
- **Bench grew 24 → 26** (added two safety prompts) and still passes 100%.

Source provenance for every port: `docs/superpowers/plans/2026-05-04-references-integration.md`.

---

## Install in 30 seconds

```bash
git clone https://github.com/animeshbasak/SuperAgent
cd SuperAgent
bash install-universal.sh
```

That's it. Restart your agent. Type `superagent`.

**Platform-specific:**
```bash
bash install-universal.sh --platform codex
bash install-universal.sh --platform cursor
bash install-universal.sh --platform gemini
bash install.sh                                # Claude Code (original)
```

**Requirements:** Python 3 · bash/zsh · macOS or Linux · your AI coding tool of choice

---

## What you get

### Core CLIs

| Tool | Purpose |
|---|---|
| `superagent-classify` | Any task → `{chain, complexity, categories}` JSON |
| `superagent-compile`  | Skills → platform-native instructions (8 formats) |
| `superagent-switch`   | Hot-swap LLM backend (list/to/back/canary/status/auto) |
| `superagent-chain`    | Run a YAML skill chain |
| `superagent-cost`     | Token cost by model, with coach notes |
| `superagent-oneshot`  | One-shot routing rate from `routes.jsonl` |
| `superagent-learn`    | Per-project learnings that persist across sessions |
| `graphify`            | Build and query your codebase knowledge graph |
| `mempalace`           | Local-first cross-session memory |

### 21 skills, auto-routed

| Skill | When it fires |
|---|---|
| `superagent` | Master router — classifies, composes chain, picks backend |
| `superagent-safety` | **NEW** Reversibility doctrine — pauses on risky shell + history-rewrite + sensitive-file edits |
| `auto-fallback` | Cost-aware switch to local LLM + 3-tier router |
| `superagent-switch` | Manual model swap with canary preflight |
| `free-llm` | Set up free-claude-code proxy + provider routing |
| `investigate` | "Why did X break?" — reproduce → isolate → explain → verify |
| `review` | "Is this ready to merge?" — 6-point diff gate |
| `ship` | "Ship it" — 20-step pipeline (test → review → commit → push → PR) |
| `cso` | "Audit this" — OWASP Top-10 + STRIDE + secrets scan |
| `plan-ceo-review` | Pressure-test plan scope (4-mode framework) |
| `plan-eng-review` | Lock architecture, edge cases, test coverage |
| `plan-design-review` | Rate 10 design dimensions 0–10, fix any <7 |
| `autoplan` | Pipeline plan through CEO → design → eng review |
| `office-hours` | YC-style product intake (6 forcing questions) |
| `webgl-craft` | Premium WebGL/3D — Awwwards-class technique library |
| `framer-motion` | React component-level motion (animate-presence, layout, springs) |
| `video-craft` | HTML → MP4 via hyperframes (deterministic, frame-accurate) |
| `learn` | Per-project learnings that stick across sessions |
| `bench` | 26-prompt classifier benchmark (HARD GATE ≥ 0.90) |
| `fanout` | Parallel skill execution |
| `token-stats` | Your savings receipt (+ shareable badge + one-shot rate) |

No skill memorization. Type your task. It routes.

---

## Make videos with hyperframes

Author HTML compositions. Render frame-accurate MP4s. Same router, same savings.

```bash
/video-craft "30-second product ad for X"
```

```
[SA] Routing → video-craft skill
[SA] Loading recipe: product-ad-30s
[SA] Composition authored: my-ad.html
[SA] Preview at http://localhost:3000/preview ... press enter to render
[SA] Rendering 30s @ 30fps... done in 4 min 12 sec
[SA] Output: my-ad.mp4 (28 MB, 30 fps, 1920x1080)
[SA] Footer: "Rendered by SuperAgent · 4.2 min · $0.83"
```

5 technique domains, 4 production recipes (hello-world, product-ad-30s, data-driven-chart, lower-third-overlay). Distilled from the open-source [hyperframes](https://github.com/heygen-com/hyperframes) framework.

**The reel at the top of this README** was authored and rendered through this pipeline. Source composition: [`docs/video/reel/index.html`](docs/video/reel/index.html). Output: [`docs/media/superagent-v2.2-reel.mp4`](docs/media/superagent-v2.2-reel.mp4) — 1920×1080, 30 fps, 30 s, 5.3 MB.

---

## Proof

```bash
bash bench/run.sh
# PROMPTS 26   PASS 26   FAIL 0   AVG 1.000
# HARD GATE: PASS  (avg >= 0.90, fails <= 2)

bash test/test-classify.sh
# Tests: 18   PASS: 18   FAIL: 0

bash test/test-canary.sh
# Tests: 4    PASS: 4    FAIL: 0
```

Claude Code surface is MD5-pinned on every release. Multi-platform support is additive only — your existing setup never changes.

---

## The receipt: share your savings

After any session:

```bash
/token-stats
```

```
SuperAgent Token Stats — /your/project
──────────────────────────────────────────────
Compression ratio : 48.3x  (your codebase, measured 2026-04-22)
──────────────────────────────────────────────
Lifetime
  Graphify queries  : 47      → 198k tokens saved
  Mempalace hits    : 23      → ~31k tokens saved
  Total saved       : ~229k tokens  ≈ $3.44 at Sonnet rates
  Free-LLM sessions : 12      → 0 rate-limits hit
  One-shot rate     : 87.9%   → routing is sharp
──────────────────────────────────────────────
```

```bash
/token-stats --badge
```

```markdown
[![SuperAgent saved 229k tokens](https://img.shields.io/badge/SuperAgent-229k_tokens_saved-brightgreen)](https://github.com/animeshbasak/SuperAgent)
[![SuperAgent: 0 rate-limits](https://img.shields.io/badge/SuperAgent-0_rate--limits_hit-orange)](https://github.com/animeshbasak/SuperAgent)
```

For video-craft, every render auto-stamps a footer: `Rendered by SuperAgent · 4.2 min · $0.83`. Add `/render-stats --badge` to your repo README for shareable render economics.

---

## FAQ

**Is it free?** Yes. Open source. Local-first. No API key. Default mode never sends code to third parties.

**Will my code leak to free LLM providers?** No — by default. Free-LLM mode is **local-only**: Ollama or llama.cpp on your machine. Cloud free-tier providers (NIM, OpenRouter, DeepSeek) are explicit opt-in via `--cloud` flag.

**How does the safety gate know what's risky?** Python regex classifier in `hooks/superagent-safety.py` (Claude Code) + the `superagent-safety` skill (every other IDE). 30+ patterns covering destructive shell, history rewrites, sensitive paths, mass DB mutations, permission-skip flags. Bypass: `SUPERAGENT_SAFETY=off`, `~/.superagent/safety/allow.txt` regex allow-list, or `## SuperAgent Safety Allow` bullets in `~/.claude/CLAUDE.md`.

**How does context preservation work across model switches?** mempalace, claude-mem, and graphify all inject text into prompts — they're provider-agnostic. When you switch the underlying LLM, the same memory text lands in the same prompts. Different brain, same memory. Your AI walks into the new model already knowing your project.

**Is local LLM quality really good enough?** For trivial tasks (lint, format, rename, simple regex): yes — qwen2.5-coder:7b runs on a laptop. For moderate tasks (single feature): qwen3-coder:next gets close to Sonnet. For complex agentic work: nothing local matches Opus 4.7. SuperAgent's `complexity` classifier won't suggest local for tasks it would fail.

**Will I have to change my workflow?** No. Just install. Routing is automatic.

**Does it work with my existing Claude setup?** Additive only. Zero modification to existing files — verified by MD5 on every release.

**I'm on Cursor, not Claude Code. Does it work?** Yes. The compiler turns 21 skills into Cursor `.mdc` rules, Codex `AGENTS.md`, Copilot instructions, Continue rules, etc. — whatever your platform expects. Hooks fire on Claude Code only; on every other platform the agent self-polices via the `superagent-safety` skill.

**What happens if my local model crashes mid-task?** Canary preflight (3-step Read → Edit → Bash test) refuses to switch if the model fails. Once switched, the auto-fallback policy on canary failure is "freeze + prompt" — you decide whether to retry, pick a different model, or restore Anthropic.

**Cursor has a 12k char rule limit. How?** Compiler auto-compacts. Your Cursor rules stay at ~4.7k chars. Measured on every build.

**Can I add my own skills?** Yes. Drop a `SKILL.md` into `skills/<name>/`. Run `superagent-compile --platform all`. Every platform picks it up.

**What if I break something?** `install.sh` is MD5-pinned. `test/test-classify.sh` is a hard gate. `bench/run.sh` enforces ≥0.90 routing accuracy. Regressions can't land.

---

## Platform formats

The compiler (`bin/superagent-compile`) is the source of truth. Each platform gets the format it expects:

| Platform | Format | Location | Size |
|---|---|---|---|
| Claude Code | `CLAUDE.md` + plugins + skills + hooks | `~/.claude/` | Full plugin system |
| Codex CLI | `AGENTS.md` | `~/.codex/AGENTS.md` | ~113k chars |
| Cursor | `.mdc` rules | `.cursor/rules/*.mdc` | 4.7k / 12k limit |
| Windsurf | `AGENTS.md` + rules | `.windsurf/rules/` | Full + modular |
| GitHub Copilot | `copilot-instructions.md` | `.github/` | ~15k chars |
| Gemini / Antigravity | `GEMINI.md` + `SKILL.md` | `~/.gemini/` + `.agent/rules/` | Per-skill files |
| Continue.dev | Numbered rules | `.continue/rules/` | 22 files |
| Aider | `CONVENTIONS.md` | project root + `.aider.conf.yml` | Auto-loaded |

Recompile any time:
```bash
python3 bin/superagent-compile --platform all
```

---

## Project structure

```
SuperAgent/
├── skills/                  21 skills (source of truth)
├── agents/                  Claude agent files (with frontmatter hooks)
├── bin/                     CLIs (classify, compile, switch, chain, cost,
│                            learn, oneshot, ship)
├── hooks/                   Python + bash hooks
│   ├── superagent-safety.py        PreToolUse reversibility gate
│   ├── superagent-session-start.py SessionStart context loader
│   ├── superagent-tracker.sh       PostToolUse token tracker
│   ├── superagent-distill.sh       Stop hook → CLAUDE.md proposals
│   └── superagent-state-init.sh    ~/.superagent/ scaffold
├── adapters/                Platform adapters (codex, gemini, cursor,
│                            windsurf, copilot, continue, aider)
├── bundles/                 Optional installers (hyperframes, free-claude-code)
├── bench/                   26-prompt classifier benchmark
├── test/                    Test suite (canary fixtures, switch tests)
├── docs/agent-memory.md     Per-skill memory convention
├── .mcp.json                MCP baseline (playwright, context7, deepwiki)
├── install.sh               Claude Code installer
└── install-universal.sh     Multi-platform installer + bundle flags
```

---

## Index your project (optional but recommended)

```bash
cd ~/my-project
graphify update ./src                         # build knowledge graph
mempalace init . --yes && mempalace mine .    # index for memory
```

Then in your agent:
```
graphify query "how does authentication work?"
mempalace search "auth decisions from last week"
```

---

## Links

- [graphify](https://github.com/animeshbasak/graphifyy) — knowledge graph engine
- [mempalace](https://github.com/animeshbasak/mempalace) — local AI memory
- [hyperframes](https://github.com/heygen-com/hyperframes) — HTML-to-MP4 framework
- [free-claude-code](https://github.com/Alishahryar1/free-claude-code) — Anthropic-compatible proxy for free LLMs
- [superpowers](https://github.com/claude-plugins-official/superpowers) — 20+ workflow skills
- [claude-mem](https://github.com/thedotmack/claude-mem) — cross-session observations
- [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — frontend design intelligence

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md). Latest: **v2.3.0 — Safety Gate + 3-Tier Router + Agent Memory**.

---

<div align="center">

### If this saved you tokens, the least you can do is star it.

**[Star on GitHub](https://github.com/animeshbasak/SuperAgent)** · **[Tweet your `/token-stats` receipt](https://twitter.com/intent/tweet?text=SuperAgent%20just%20saved%20me%20200k%20tokens%20%2B%20zero%20rate-limits%20on%20my%20last%20AI%20coding%20session.%20Works%20with%20Claude%2C%20Cursor%2C%20Copilot%2C%20and%205%20more.%20https%3A%2F%2Fgithub.com%2Fanimeshbasak%2FSuperAgent)** · **[Share on HN](https://news.ycombinator.com/submitlink?u=https%3A%2F%2Fgithub.com%2Fanimeshbasak%2FSuperAgent)**

Built by devs who got tired of watching their AI burn tokens on re-reads — and run out of them at 4pm.

</div>
