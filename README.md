<div align="center">

# SuperAgent

### Stop paying for tokens your AI burned re-reading your codebase.

**One install. 8 AI coding tools. 95% fewer tokens. Never skips tests.**

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install-universal.sh
```

[![Stars](https://img.shields.io/github/stars/animeshbasak/SuperAgent?style=social)](https://github.com/animeshbasak/SuperAgent)
[![Platforms](https://img.shields.io/badge/platforms-8-blue)](#works-with-every-ai-coding-tool-you-use)
[![Token Savings](https://img.shields.io/badge/token_savings-95%25-brightgreen)](#the-receipt-share-your-savings)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

</div>

---

## The 60-second test

**Without SuperAgent:**
```
You:    "how does auth work in this repo?"
Agent:  reads 71 files → 187,000 tokens → $2.80 → 4 minutes
```

**With SuperAgent:**
```
You:    "how does auth work in this repo?"
Agent:  graphify query "auth" → 2,600 tokens → $0.04 → 3 seconds
```

**71.5x cheaper. Every query. Forever.**

Multiply that by every "where is X defined", every "why did we do Y", every "walk me through Z". You just got your weekends back.

---

## Works with every AI coding tool you use

| | | | |
|---|---|---|---|
| **Claude Code** | **Codex CLI** | **Cursor** | **Windsurf** |
| **GitHub Copilot** | **Gemini / Antigravity** | **Continue.dev** | **Aider** |

One installer. Auto-detects every platform on your machine. Installs the right adapter for each.

```bash
bash install-universal.sh --list      # see what's detected
bash install-universal.sh             # install everywhere
```

---

## Why it exists

Every AI coding session starts cold. You re-explain the same codebase. The agent reads 40 files to answer one question. Forgets what you decided last Tuesday. Dives into code before you've agreed on a plan. Says "done" when it isn't. You ask for "premium UI" and you get Bootstrap with a gradient.

You're losing hours. You're losing tokens. **On every platform.**

SuperAgent fixes this with four levers:

| Lever | What it does | The number |
|---|---|---|
| **graphify** | Codebase → queryable knowledge graph | **71.5x** fewer tokens per query |
| **mempalace** | Cross-session memory, local-first | **96.6%** retrieval accuracy, no API keys |
| **Routing brain** | "Fix bug" auto-routes to debug → TDD → verify | **20/20** on routing benchmark |
| **15 battle-tested skills** | TDD, planning, review, security, UI design | **Enforced**, not optional |

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

Last 5 sessions
  2026-04-22    12 queries     ~58k saved
  2026-04-21     8 queries     ~38k saved
  2026-04-20    15 queries     ~71k saved
──────────────────────────────────────────────
```

**Want a badge for your own README?**

```bash
/token-stats --badge
```

Outputs pastable markdown:
```markdown
[![SuperAgent saved 229k tokens](https://img.shields.io/badge/SuperAgent-229k_tokens_saved-brightgreen)](https://github.com/animeshbasak/SuperAgent)
```

Drop it in your README. Flex your receipts. Start a dev savings race.

---

## What you get

### Core tools

| Tool | Purpose |
|---|---|
| `superagent-classify` | Any task → the right skill chain, as JSON |
| `superagent-compile` | Skills → platform-native instructions (8 formats) |
| `superagent-chain` | Run a YAML skill chain |
| `superagent-cost` | Token cost by model, with coach notes |
| `graphify` | Build and query your codebase knowledge graph |
| `mempalace` | Local-first cross-session memory |

### 15 skills, auto-routed

| Skill | When it fires |
|---|---|
| `superagent` | Master router — classifies task, composes chain |
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
| `learn` | Per-project learnings that stick across sessions |
| `bench` | 20-prompt classifier benchmark (HARD GATE ≥ 0.90) |
| `fanout` | Parallel skill execution |
| `token-stats` | Your savings receipt (+ shareable badge) |

No skill memorization. Type your task. It routes.

---

## Proof

```bash
bash bench/run.sh
# PROMPTS 20   PASS 20   FAIL 0   AVG 1.000
# HARD GATE: PASS  (avg >= 0.90, fails <= 2)

bash test/test-classify.sh
# Tests: 18   PASS: 18   FAIL: 0
```

Claude Code surface is MD5-pinned on every release. Multi-platform support is additive only — your existing setup never changes.

---

## FAQ

**Is it free?** Yes. Open source. Local-first. No API key.

**Will I have to change my workflow?** No. Just install. Routing is automatic.

**Does it work with my existing Claude setup?** Additive only. Zero modification to existing files — verified by MD5 on every release.

**I'm on Cursor, not Claude Code. Does it work?** Yes. The compiler turns 15 skills into Cursor `.mdc` rules, Codex `AGENTS.md`, Copilot instructions, Continue rules, etc. — whatever your platform expects.

**Does it leak my code to third parties?** No. `graphify` and `mempalace` run locally. Nothing leaves your machine.

**Cursor has a 12k char rule limit. How?** Compiler auto-compacts. Your Cursor rules stay at ~4.7k chars. Measured on every build.

**Can I add my own skills?** Yes. Drop a `SKILL.md` into `skills/<name>/`. Run `superagent-compile --platform all`. Every platform picks it up.

**What if I break something?** `install.sh` is MD5-pinned. `test/test-classify.sh` is a hard gate. `bench/run.sh` enforces ≥0.90 routing accuracy. Regressions can't land.

---

## Platform formats

The compiler (`bin/superagent-compile`) is the source of truth. Each platform gets the format it expects:

| Platform | Format | Location | Size |
|---|---|---|---|
| Claude Code | `CLAUDE.md` + plugins + skills | `~/.claude/` | Full plugin system |
| Codex CLI | `AGENTS.md` | `~/.codex/AGENTS.md` | ~66k chars |
| Cursor | `.mdc` rules | `.cursor/rules/*.mdc` | 4.7k / 12k limit |
| Windsurf | `AGENTS.md` + rules | `.windsurf/rules/` | Full + modular |
| GitHub Copilot | `copilot-instructions.md` | `.github/` | ~10k chars |
| Gemini / Antigravity | `GEMINI.md` + `SKILL.md` | `~/.gemini/` + `.agent/rules/` | Per-skill files |
| Continue.dev | Numbered rules | `.continue/rules/` | 16 files |
| Aider | `CONVENTIONS.md` | project root + `.aider.conf.yml` | Auto-loaded |

Recompile any time:
```bash
python3 bin/superagent-compile --platform all
```

---

## Routing table

| You say | It routes to |
|---|---|
| "build X" / "add feature Y" | brainstorming → writing-plans → TDD → executing-plans → verification |
| "fix bug" / "broken" / "error" | systematic-debugging → TDD → verification |
| "understand codebase" | graphify query → smart-explore |
| "ship" / "PR" / "merge" | review → ship |
| "design" / "UI" / "component" | brainstorming → ui-ux-pro-max |
| "3D" / "WebGL" / "cinematic" | webgl-craft → writing-plans |
| "security" / "audit" | cso → security-review |
| "why did X happen" | investigate → mem-search |
| "plan" / "roadmap" | brainstorming → writing-plans → plan-ceo-review → plan-eng-review |
| "did we solve this before?" | mem-search |
| 2+ independent tasks | dispatching-parallel-agents |

---

## Project structure

```
SuperAgent/
├── skills/                  15 skills (source of truth)
├── bin/                     CLIs (classify, compile, chain, cost, learn)
├── hooks/                   Bash hooks (tracker, statusline, distill)
├── agents/                  Claude agent files
├── adapters/                Platform adapters (codex, gemini, cursor, windsurf,
│                            copilot, continue, aider)
├── bench/                   20-prompt classifier benchmark
├── test/                    Test suite
├── install.sh               Claude Code installer
└── install-universal.sh     Multi-platform installer
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
- [superpowers](https://github.com/claude-plugins-official/superpowers) — 20+ workflow skills
- [claude-mem](https://github.com/thedotmack/claude-mem) — cross-session observations
- [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — frontend design intelligence

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

<div align="center">

### If this saved you tokens, the least you can do is star it.

**[Star on GitHub](https://github.com/animeshbasak/SuperAgent)** · **[Tweet your `/token-stats` receipt](https://twitter.com/intent/tweet?text=SuperAgent%20just%20saved%20me%20200k%20tokens%20on%20my%20last%20AI%20coding%20session.%20Works%20with%20Claude%2C%20Cursor%2C%20Copilot%2C%20and%205%20more.%20https%3A%2F%2Fgithub.com%2Fanimeshbasak%2FSuperAgent)** · **[Share on HN](https://news.ycombinator.com/submitlink?u=https%3A%2F%2Fgithub.com%2Fanimeshbasak%2FSuperAgent)**

Built by devs who got tired of watching their AI burn tokens on re-reads.

</div>
