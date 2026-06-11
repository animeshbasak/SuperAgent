<div align="center">

<img src="docs/media/hero-superagent.svg" alt="SuperAgent — the routing brain that lives between your AI and your code" width="900" />

# One AI config. Every coding tool you use.

**Write your AI instructions once. SuperAgent compiles them to Cursor, Codex, Copilot, Continue.dev, Windsurf, Aider, Gemini, and Claude Code in their native formats. Then it routes every task to the right skill, watches the shell for scary commands, tracks your spend, and falls back to a free local model when you hit the rate limit. And with Memory-OS, every one of those tools shares a single persistent memory — what you teach Claude Code on Monday, Cursor knows on Tuesday.**

[![Stars](https://img.shields.io/github/stars/animeshbasak/SuperAgent?style=social)](https://github.com/animeshbasak/SuperAgent)
[![Version](https://img.shields.io/badge/v3.1.0-shipped-blueviolet)](https://github.com/animeshbasak/SuperAgent/releases/tag/v3.1.0)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-196%20green-brightgreen)](#receipts)
[![Bench](https://img.shields.io/badge/routing-45%2F45-brightgreen)](#receipts)
[![Memory bench](https://img.shields.io/badge/semantic%20rediscovery-0%25%E2%86%92100%25-brightgreen)](docs/agent-memory.md)

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install.sh
```

</div>

---

## The problem this fixes

You bought your AI coding tool. You like it. Then you started paying four hidden taxes:

1. **You wrote the same rules four times.** `CLAUDE.md`, `.cursorrules`, `.continue/rules/*.md`, `.github/copilot-instructions.md`. Four files, drifting apart, all saying almost the same thing.
2. **Your AI re-reads the codebase every conversation.** Tokens get burned re-discovering files and decisions it already saw an hour ago. Worse: ask about last month's work in different words and keyword search finds *nothing* — our bench measures 0% rediscovery on paraphrased queries without semantic recall (100% with it).
3. **At 4 PM, you hit the rate limit.** Your free local model sits idle on your laptop while you stare at "please wait 5 hours."
4. **Your AI runs `git push --force` because you said "fix it and push."** Or `rm -rf` on a directory it misread. Or commits to `main` because nobody told it `main` was sacred.

SuperAgent removes all four. One config. One safety gate. One cost tracker. One free local fallback. One persistent memory. Everything below is a real, replaceable file under `bin/`, `skills/`, or `hooks/` — nothing is magic.

---

## The whole capability surface at a glance

| Layer | Count | What it is |
|---|---|---|
| **CLI tools** (`bin/`) | 24 | Every capability is a standalone command you can run by hand. |
| **Skills** (`skills/`) | 32 | The source-of-truth instruction set, routed automatically by the classifier. |
| **Specialist agents** (`agents/`) | 6 | Named personas (architect, coder, reviewer, security, tester, brain). |
| **Lifecycle hooks** (`hooks/`) | 9 | Real Claude Code hooks across the full session lifecycle. |
| **Routing rules** (`brain/rules.yaml`) | 48 | Regex signals → skill chains, plus a learning loop on top. |
| **Platform adapters** (`adapters/`) | 9 + shared | Native rule output for every major AI coding tool. |
| **Slash commands** (`commands/`) | 9 | `/superagent`, `/sparc`, `/testgen`, `/diff-risk`, … |
| **Memory tools** (MCP) | 5 | Cross-session, cross-tool persistent memory (FTS5 + optional vector). |
| **Routing bench** (`bench/`) | 45 | Accuracy harness, hard gate ≥ 90%. Currently 45/45. |

---

## 1. The routing brain

You type a task in plain English. The classifier (`bin/superagent-classify`, regex + Python over `brain/rules.yaml`) reads the intent, scores complexity (trivial / moderate / complex), and emits a **skill chain** as JSON.

```bash
$ superagent-classify "fix the dark mode bug"
→ debugging → TDD → verification

$ superagent-classify "design the API for comments"
→ brainstorming → api-and-interface-design → agent:architect

$ superagent-classify "scrape this Cloudflare-protected page"
→ scraping   (Scrapling under the hood)
```

- **Prompts get optimized first.** Before anything is classified, `bin/superagent-optimize` (brain step 0) rewrites the raw prompt into a tight directive — politeness and filler stripped, polite questions turned imperative, rambling multi-ask prompts split into numbered steps. Deterministic, no API call, runs inside the `UserPromptSubmit` hook so *every* prompt reaches Claude optimized. Kill switch: `SUPERAGENT_OPTIMIZE=0`.
- **48 routing rules** map task signals to chains. `mempalace-wake` always runs first; `verification-before-completion` always runs last on build tasks.
- **It learns.** Every successful chain logs to `~/.superagent/brain/routes.jsonl`. When the same chain succeeds repeatedly for similar tasks, `superagent-patterns promote` lifts it into `patterns.jsonl`, and the classifier reads patterns *before* static rules — short-circuiting future runs.
- **45 routing tests, all green.** The bench (`bench/run.sh`) is a hard gate: ships only at ≥ 90% with ≤ 2 fails.

---

## 2. The 24 command-line tools

Every capability is a real executable installed to `~/.local/bin/`. Run any of them by hand.

### Routing, learning & orchestration
| Tool | What it does |
|---|---|
| `superagent-classify` | Routes a task string → JSON skill chain + complexity + hint. The brain. |
| `superagent-optimize` | Brain step 0 — rewrites a raw prompt into a tight directive (filler stripped, multi-asks numbered) before classify/dispatch. |
| `superagent-chain <name>` | Prints the ordered steps of a named YAML chain (e.g. `ship-v2`). |
| `superagent-compile` | Rewrites `skills/` into every platform's native instruction format. |
| `superagent-patterns` | Learning-loop store: `list` · `promote` · `decay` · `protect` · `prune`. |
| `superagent-oneshot` | Computes your one-shot rate — % of tasks finished on the first attempt. |
| `superagent-reload` | Mirrors repo skills into `~/.claude/skills/` for hot pickup next session. |
| `superagent-pool` | Orchestrate parallel Claude Code sessions: `spawn` · `list` · `tag` · `kill` · `status`. |

### Cost & model switching
| Tool | What it does |
|---|---|
| `superagent-cost [today\|week\|all]` | Real Anthropic spend, grouped by model, with a coach note. `--json`. |
| `superagent-cost-alerts` | Fires tiered budget alerts; drops `auto-downgrade.flag` near the limit. |
| `superagent-switch` | Swap the active LLM backend: `list` · `to <model>` · `back` · `canary` · `status` · `auto on\|off`. Canary-tests before flipping. |

### Quality, safety & shipping
| Tool | What it does |
|---|---|
| `superagent-diff-risk` | Per-diff impact: `classify` / `impact` → low/medium/high/critical + 5 risk flags + CODEOWNERS reviewer suggestion. Pure git, no GitHub API. |
| `superagent-ship <base>` | Full pipeline: rebase → test → audit → review → version bump → CHANGELOG → bisectable commits → push → PR. Refuses `main`/`master`. |
| `superagent-sparc` | 5-phase gated methodology: `init` · `gate` · `advance` · `report` · `status`. Boolean gates, no negotiable scores. |
| `superagent-testgen` | Coverage gap detection: `scan` · `gap --top N` · `suggest <file>`. Ranks by gap × LOC, emits skeletons — never test bodies. |
| `superagent-aidefence` | Prompt injection + PII scanner over 58 patterns: `scan` · `enable` · `disable` · `status` · `list` · `feedback`. |

### Autonomy, memory & data
| Tool | What it does |
|---|---|
| `superagent-autopilot` | Unattended loop: `enable` · `status` · `tasks` · `predict` · `iter`. Discovers pending work, pauses at 90% budget. |
| `superagent-learn` | Per-project learnings diary: `add` · `list` · `search`. Corrections compound. |
| `superagent-memory-mcp` | The Memory-OS MCP server (see §5). 5 memory tools, FTS5 SQLite, optional vector recall. |
| `superagent-scrape` | Scrapling wrapper for protected pages: `install` · `fetch` · `browser` · `status`. Per-user venv. |

### Observability
| Tool | What it does |
|---|---|
| `superagent-trace <traceId>` | Builds the parent-child span tree, ASCII-prints it, flags the p95 bottleneck. |
| `superagent-metrics [today\|week\|all]` | Aggregates counter/gauge/histogram metrics with p50/p95/p99 + 2σ anomaly flags. |
| `superagent-obs` | Low-level emitter for spans + metrics (used by the hooks). |
| `superagent-obs-rotate` | Daily-rotates `spans.jsonl` / `metrics.jsonl`, prunes anything older than 30 days. |

---

## 3. The 32 skills

Skills are the source of truth. The classifier composes them into chains; `superagent-compile` ships them to every platform. Grouped by what they do:

**Routing & meta** — `superagent` (master entrypoint) · `superagent-learn-loop` (pattern promotion/decay) · `superagent-safety` (reversibility gate) · `superagent-switch` (model control) · `dynamic-skills` (hot-reload) · `fanout` (run skills in parallel)

**Planning & review** — `autoplan` (product→design→eng pipeline) · `plan-ceo-review` (4-mode scope lens) · `plan-design-review` (10-dimension scoring) · `plan-eng-review` (architecture/edge-case lock) · `review` (6-point pre-merge gate) · `sparc` (5-phase methodology) · `office-hours` (6 YC forcing questions) · `investigate` (Iron-Law root-cause)

**Security & observability** — `cso` (OWASP/STRIDE/secrets/supply-chain) · `aidefence` (prompt-injection + PII scan) · `observability` (spans, metrics, anomalies)

**Cost & model management** — `cost-budget` (tiered budget alerts) · `auto-fallback` (limit-aware local switch) · `free-llm` (route through the local proxy) · `token-stats` (savings + shareable badge)

**Dev tooling** — `ship` (full ship pipeline) · `testgen` (coverage gaps) · `diff-risk` (blast-radius scoring) · `agent-pool` (parallel sessions) · `bench` (classifier accuracy) · `learn` (persistent learnings) · `autopilot` (unattended loop) · `scraping` (anti-bot data pulls)

**Creative / front-end** — `framer-motion` (React motion API) · `webgl-craft` (premium 3D / Three.js / shaders) · `video-craft` (HTML→MP4 via hyperframes)

> Plus the bundled `agent-skills:*` namespace — 8 step-by-step engineering skills (spec-driven dev, idea-refine, task breakdown, incremental implementation, API design, deprecation/migration, ADRs, performance) credited to Addy Osmani's [agent-skills](https://github.com/addyosmani/agent-skills).

---

## 4. The 6 specialist agents

The classifier dispatches these named personas automatically when a task is complex enough. Each carries its own scoped safety hook.

| Agent | Role | Triggers on |
|---|---|---|
| `architect` | Designs APIs, module boundaries, DDD | "design API", "system architecture", "bounded context" |
| `coder` | Implements features, refactors, debugs | "implement", "refactor", "fix the X" |
| `reviewer` | Pre-merge diff gate | "review code", "audit PR" |
| `security-architect` | Threat models, STRIDE, attack surface | "threat model", "security review", "STRIDE" |
| `tester` | Writes unit/integration/e2e tests, TDD | "write tests", "coverage", "TDD" |
| `superagent-brain` | The routing brain — proactively picks the chain | any build / fix / explore / design / review / ship task |

---

## 5. Memory that survives the conversation

SuperAgent ships an MCP memory server (`superagent-memory-mcp`) so your AI remembers decisions across sessions instead of re-discovering them every conversation.

```bash
# Your AI writes a decision once…
memory_write("We switched billing rounding to banker's rounding — finance signed off", kind="decision")

# …and recalls it next week, in any tool
memory_recall("how do we round billing amounts?")
# → "banker's rounding — finance signed off (decision, 6 days ago)"
```

**5 MCP tools** — `memory_recall` (BM25/FTS search) · `memory_write` (append-only, sanitized) · `memory_list` (recent by namespace/kind) · `memory_pin` (promote to the workspace layer) · `memory_forget` (soft-delete by id or pattern).

- **Namespaced per git-root** — projects never leak into each other; a `__global__` namespace holds cross-project facts.
- **Sanitized on write** — prompt-injection and PII patterns are stripped before anything is persisted.
- **Decay + consolidation** — `superagent-memory decay` archives entries older than 90 days *and* idle 30+ days; `superagent-memory dedup` merges near-duplicates (cosine ≥0.92, opt-in with vectors); `superagent-memory cron install` schedules decay weekly. Memory stays small and true.
- **Ground Truth Hierarchy** — recalled memory is injected *above* training data, so the model trusts "what we decided" over "what's generally true."
- **Hybrid vector recall** — opt-in semantic search via `SUPERAGENT_MEMORY_VECTOR=on` blends FTS keyword ranking with embedding cosine via reciprocal rank fusion, so synonym queries (`login fix` → a stored `auth bug`) surface hits pure keyword search misses. Local-first embeddings (Ollama → OpenRouter), with an in-memory fallback when no Qdrant sidecar is running.
- **One memory, every tool** — registers into Claude Code, Cursor, and Gemini CLI today; Copilot + Antigravity experimental. [Track the rollout →](docs/plans/2026-06-03-memory-os-integration.md)

Storage lives at `~/.superagent/memory-os/memory.db` (SQLite + FTS5), overridable via `SUPERAGENT_MEMORY_HOME`. 134 pytest tests cover the schema, decay, semantic dedup, migration, hybrid vector recall, telemetry, the bench harness, and security regressions (path-traversal + mass-forget guards).

**Proof, not promises:** `superagent-memory bench` replays a fixture corpus with keyword and paraphrase probes. Paraphrase rediscovery: **0% FTS-only → 100% hybrid** (keyword split unregressed). `superagent-memory stats` shows your own usage — counters never leave the local SQLite file. Setup: [docs/memory-os-quickstart.md](docs/memory-os-quickstart.md).

---

## 6. The 9 lifecycle hooks

On Claude Code these are real harness hooks, firing across the full session lifecycle. On every other platform the same logic self-polices via the matching skill.

| Lifecycle event | Hook | What it does |
|---|---|---|
| `SessionStart` | `superagent-session-start.py` | Inits session state, primes memory, emits the route header. |
| `UserPromptSubmit` | `superagent-prompt-submit.py` | Classifies the prompt, runs AIDefence if enabled, attaches the chain. |
| `PreToolUse` | `superagent-safety.py` | The reversibility gate — blocks `rm -rf`, `git push --force`, `DROP`, `.env` edits, `--dangerously-skip-permissions`. |
| `PostToolUse` | `superagent-tracker.sh` | Emits a span + token metric on every tool call. |
| `PermissionRequest` | `superagent-permission.py` | Advisory overlay on permission prompts. |
| `PreCompact` | `superagent-precompact.py` | Marks the compaction boundary, checkpoints state, warns on risky compaction. |
| `Stop` | `superagent-distill.sh` | Distills learned patterns, updates routes, rotates observability logs. |
| `SubagentStop` | `superagent-subagent-stop.py` | Tracks subagent outcomes and applies the safety gate to dispatches. |
| `Notification` | `superagent-notification.py` | Formats rich notifications (cost alerts, pattern promotions, trace links). |

Helper scripts (`superagent-statusline.sh`, `superagent-limit-watch.sh`, `superagent-state-init.sh`) drive the status line, the cost watchdog, and first-run scaffolding.

---

## 7. Works with every AI coding tool you use

`bin/superagent-compile` rewrites the same skills into each platform's native format. Hooks fire on Claude Code; every other platform self-polices via the `superagent-safety` skill.

| | Claude Code | Cursor | Codex | Copilot | Continue | Windsurf | Gemini | Aider | Antigravity |
|---|---|---|---|---|---|---|---|---|---|
| **Skills routed** | 32 | 7 `.mdc` | 32 `AGENTS.md` | inline | 33 rules | 32 rules | 32 skills | `CONVENTIONS.md` | rules |
| **Safety** | 9 hooks | self-polices | self-polices | self-polices | self-polices | self-polices | self-polices | self-polices | self-polices |
| **Learning loop** | ✅ | reads store | reads store | reads store | reads store | reads store | reads store | reads store | reads store |
| **Cost tracker** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Memory-OS** | ✅ | ✅ | — | exp. | — | — | ✅ | — | exp. |

Each platform has its own adapter under `adapters/` (plus a shared `_shared/memory-os-lib.sh`). The universal installer auto-detects which tools you have.

**Slash commands** (Claude Code): `/superagent` · `/sparc` · `/testgen` · `/diff-risk` (`/jujutsu` legacy alias) · `/aidefence` · `/autopilot` · `/observe` · `/superagent-switch`.

---

## 8. Optional bundles

Heavier capabilities ship as opt-in bundles so the base install stays ~120 MB:

- **`free-claude-code`** — vendors a transparent proxy on port `18082` that routes Claude Code through free/local models (Ollama, qwen-coder, DeepSeek, llama.cpp). The escape hatch when you hit the Anthropic rate limit.
- **`hyperframes`** — the deterministic HTML→MP4 video pipeline behind `video-craft` (Node 22+ and FFmpeg).
- **`local-llms`** — one-command installers for Ollama (`qwen2.5-coder`) and llama.cpp (Qwen3 Q4) so the local fallback has something to fall back to.

Enable them at install time: `bash install-universal.sh --with-video --with-free-llm --with-near-opus`.

---

## Install

```bash
git clone https://github.com/animeshbasak/SuperAgent
cd SuperAgent
bash install.sh
```

Takes ~30 seconds. ~120 MB on disk. **Idempotent** — run it again to upgrade, nothing duplicates. For multi-tool setups, `install-universal.sh` auto-detects Claude Code, Cursor, Copilot, Continue, Gemini, Windsurf, Codex, Aider, and Antigravity (`--list` to preview, `--platform <name>` to target one, `--full` for everything).

### Confirm it worked

```bash
superagent-classify "review my PR for SQL injection"   # router picks [review, cso, security-review, agent:reviewer]
superagent-cost today                                   # your real Anthropic spend
superagent-patterns list                                # the learning loop is alive
superagent-diff-risk report                             # current branch gets a risk score
```

If all four return without error, you're done.

---

## Show me a real session

```
$ superagent-sparc init feat-billing-rounding
~/.superagent/sparc/feat-billing-rounding

$ vim ~/.superagent/sparc/feat-billing-rounding/spec.md
$ superagent-sparc gate
gate PASSED (phase 1)
$ superagent-sparc advance
advanced phase 1 -> 2

$ # an hour later, before you push
$ superagent-diff-risk report
Primary: bugfix (conf 1.0)   Impact: medium   Score: 2
Files: 3   diff lines: 87
Risk factors: (none)

$ # all green — the ship skill takes it from here: tests, version bump, push, PR
```

That session never hit a rate limit. Never lost a token to re-reading the codebase. The classifier picked the chain. The safety gate watched the shell. The cost tracker logged the spend. The diff scorer cleared the push. The memory server remembered the decision.

---

## Receipts

```
$ bash bench/run.sh
PROMPTS 45   PASS 45   FAIL 0   AVG 1.000
HARD GATE: PASS  (avg >= 0.90, fails <= 2)

$ for t in test/test-*.sh; do bash "$t" >/dev/null && echo OK; done | wc -l
62

$ superagent-aidefence list | wc -l
58           # injection + PII patterns

$ superagent-cost today
TOTAL   770,000     $9.80
```

AIDefence tested on a 100-prompt corpus: **86% of attack prompts caught, 2% false-positive rate on benign code.**

---

## Version history

| Release | What it means for you |
|---|---|
| [**v1.0 / v1.1**](CHANGELOG.md) (Apr 2026) | The first router + compile-to-every-tool foundation. |
| [**v2.0 / v2.2**](CHANGELOG.md) (Apr 2026) | Skill expansion, adapters, and the MCP baseline. |
| [**v2.4 Wave 1**](CHANGELOG.md#v240--2026-05-09-wave-1-foundation) | The classifier remembers what worked. Cost tracker stops surprising you. Safety gate stops scary commands. |
| [**v2.5 Wave 2**](CHANGELOG.md#v250--2026-05-12-wave-2-autonomous--safe) | Prompt-injection scanner, five named personas, full session observability, autopilot. |
| [**v2.6 Wave 3**](CHANGELOG.md#v260--2026-05-13-wave-3-methodology--quality) | SPARC 5-phase pipeline, coverage gap detection, per-diff risk scoring. |
| [**v3.0 Capstone**](https://github.com/animeshbasak/SuperAgent/releases/tag/v3.0.0) | Three upstream projects (Scrapling / Octogent / jcode) distilled into native skills. |
| [**v3.1 Memory-OS**](CHANGELOG.md) (Jun 2026) | One persistent memory across every coding tool. Hybrid semantic recall (paraphrase rediscovery 0%→100% on bench), decay + semantic dedup lifecycle, security-hardened MCP boundary, local-first embeddings. [Plan →](docs/plans/2026-06-03-memory-os-integration.md) |

---

## What's next

The honest roadmap — gaps we know about, in priority order:

1. **Session auto-capture** — a Stop-hook that distills each session into memory entries automatically, so memory grows without anyone calling `memory_write`. The single highest-leverage missing piece.
2. **CI matrix** — GitHub Actions running the 134 memory tests + 45-prompt routing bench + fresh-box adapter installs on macOS and Linux per PR. (Today the gates run locally; the receipts should be public.)
3. **Team memory** — an opt-in shared namespace synced through git (encrypted), so a team's decisions compound the way an individual's do.
4. **Vector-on-by-default decision** — once `bench --real` data accumulates across machines, decide whether semantic recall ships enabled (today: opt-in, zero-dep default).
5. **Copilot/Antigravity graduation** — both adapters are experimental pending upstream MCP support; revisit quarterly.
6. **Windows support** — `cron_install` and the shell adapters assume POSIX; the Python server itself is already portable.

---

## Where things live

```
SuperAgent/
├── bin/            23 command-line tools + the memory-os MCP server (installed to ~/.local/bin/)
├── skills/         32 skills (the source of truth)
├── agents/         6 specialist agent personas
├── hooks/          9 Claude Code lifecycle hooks (+ 3 helper scripts)
├── adapters/       9 IDE rule generators + _shared memory-os lib
├── commands/       9 slash-command dispatchers
├── brain/          rules.yaml (48 rules) + the learning loop
├── bench/          45-prompt routing accuracy harness
├── bundles/        optional: free-claude-code · hyperframes · local-llms
├── test/           bash + python smoke/unit suites
└── install.sh      one-command install
```

After install:

```
~/.superagent/
├── brain/          routing decisions + learned patterns
├── cost/           per-tool token logs + budget config + alerts
├── learnings/      distilled corrections per project
├── obs/            span and metric logs
├── memory-os/      memory.db — persistent cross-session memory (FTS5, namespaced per repo)
└── …               one subdir per opt-in feature
```

---

## FAQ

**I use Cursor, not Claude Code. Does this still help me?** Yes. `bin/superagent-compile` writes the same skills as Cursor `.mdc` rules. The safety gate works as a self-policing skill instead of a hook — same behavior, slightly different mechanism. Memory-OS registers into Cursor too.

**Will SuperAgent slow down my AI?** No. Hooks add ~1–5 ms per tool call. The classifier runs in under 100 ms. Everything is local files; there's no network call on the hot path.

**Does SuperAgent send anything to a server?** No. Everything lives under `~/.superagent/` and `~/.claude/`. SuperAgent does not phone home. Memory is a local SQLite file.

**What if my Anthropic limit hits?** The cost tracker drops a flag at 90% of daily budget. The auto-fallback skill reads it and proposes Opus → Sonnet → Haiku, or hands off to a local model via the free-claude-code proxy on port 18082.

**Does it change my code without asking?** Only when you ask. Risky shell hits the safety gate first. AIDefence and Autopilot are default off. SPARC starts only when you run `sparc init`.

**Where does the learning come from?** Every successful chain logs to `~/.superagent/brain/routes.jsonl`. When the same chain succeeds repeatedly for similar tasks, it's promoted into `patterns.jsonl`, which the classifier reads before the static rules.

**What's the catch?** 32 skills is a lot, and the learning curve is real — but you don't need all of them on day one. Start with `superagent-cost today` and the safety gate. Add `superagent-diff-risk` before a scary push. Add `sparc` when you start a real feature.

---

## Credits

- [Anthropic Claude Code](https://claude.com/claude-code) — the hook-and-skill harness this is built on
- [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills) — the 8 step-by-step engineering skills in the `agent-skills:*` namespace
- [HeyGen Hyperframes](https://github.com/heygen-com/hyperframes) — deterministic video pipeline for the reels
- [Scrapling](https://github.com/D4Vinci/Scrapling), [Octogent](https://github.com/hesamsheikh/octogent), [jcode](https://github.com/1jehuang/jcode) — the three upstream projects whose work shipped into the v3.0 capstone
- [Ruflo (claude-flow)](https://github.com/ruflo/claude-flow) — AIDefence pattern store reference + diff-risk classifier regex map

---

## License

MIT. See [LICENSE](LICENSE).
