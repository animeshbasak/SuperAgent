<div align="center">

<img src="docs/media/hero-superagent.svg" alt="SuperAgent — the routing brain that lives between your AI and your code" width="900" />

# One AI config. Every coding tool you use.

**Write your AI instructions once. SuperAgent compiles them to Cursor, Codex, Copilot, Continue.dev, Windsurf, Aider, Gemini, and Claude Code in their native formats. Change one file, every tool updates.**

[![Stars](https://img.shields.io/github/stars/animeshbasak/SuperAgent?style=social)](https://github.com/animeshbasak/SuperAgent)
[![Version](https://img.shields.io/badge/v3.0.0-shipped-blueviolet)](https://github.com/animeshbasak/SuperAgent/releases/tag/v3.0.0)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-62%2F62%20green-brightgreen)](#receipts)
[![Bench](https://img.shields.io/badge/routing-45%2F45-brightgreen)](#receipts)

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install.sh
```

</div>

---

## The problem this fixes

You bought your AI coding tool. You like it. Then you started paying four hidden taxes:

1. **You wrote the same rules four times.** `CLAUDE.md`, `.cursorrules`, `.continue/rules/*.md`, `.github/copilot-instructions.md`. Four files, drifting apart, all saying almost the same thing.
2. **Your AI re-reads the codebase every conversation.** Tokens get burned re-discovering files it already saw an hour ago.
3. **At 4 PM, you hit the rate limit.** Your free local model sits idle on your laptop while you stare at "please wait 5 hours."
4. **Your AI runs `git push --force` because you said "fix it and push."** Or `rm -rf` on a directory it misread. Or commits to `main` because nobody told it `main` was sacred.

SuperAgent removes all four taxes. One config. One safety gate. One cost tracker. One free local fallback.

---

## What it actually does for you

Each capability below is a real, replaceable file. Nothing is magic.

### 🎯 One config, every tool

You write skills in `skills/`. Run `bin/superagent-compile` and SuperAgent rewrites them as:
- Cursor `.mdc` rules
- Codex `AGENTS.md`
- Copilot `copilot-instructions.md`
- Continue.dev rule files
- Windsurf rule files
- Gemini skill files
- Aider `CONVENTIONS.md`
- Claude Code skill files

Change one source. All eight downstream files update.

### 🛡 Your AI won't run scary commands without asking

Before `rm -rf`, `git push --force`, `DROP TABLE`, an `.env` edit, or a `--dangerously-skip-permissions` flag — the safety gate pauses and asks. On Claude Code this is a real `PreToolUse` hook. On every other platform, the agent self-polices via the same rule set.

### 💸 You can see your real Anthropic spend, right now

```bash
$ superagent-cost today
model     tokens          $
opus      250,000     $7.50
sonnet    120,000     $1.80
haiku     400,000     $0.50
TOTAL     770,000     $9.80
```

At 90 % of your daily budget, a flag drops. The next message routes to a cheaper model — or to a free local model on your laptop (Ollama, qwen-coder, DeepSeek, llama.cpp via the free-claude-code proxy on port 18082). **No more 4 PM rate-limit surprises.**

### 🧠 The classifier picks the right approach for each task

You type `"fix the dark mode bug"`. SuperAgent picks `debugging → TDD → verification`.
You type `"design the API for comments"`. It picks the `architect` specialist agent.
You type `"scrape this Cloudflare-protected page"`. It picks the `scraping` skill (which uses Scrapling under the hood).

45 routing tests. All green. The classifier learns from your sessions — when a chain succeeds three times for similar tasks, it gets promoted into the pattern store and short-circuits future runs.

### 🛡 Prompt injection caught at the door (opt-in)

Turn on AIDefence and every prompt is scanned against 58 patterns: instruction override, role switching, jailbreak, encoding attacks, PII leaks. Critical threats → blocked. High → confirms before proceeding. PII → logged, never sent upstream.

Tested on a 100-prompt corpus: **86 % of attack prompts caught, 2 % false-positive rate on benign code.**

### 🧑‍💼 Five specialist personas for parallel work

`architect` (designs APIs), `coder` (implements features), `reviewer` (pre-merge gate), `security-architect` (threat models), `tester` (writes test suites). The classifier dispatches them automatically when the task is complex enough. Each specialist carries its own scoped safety hook.

### 🤖 An autopilot that keeps working when you step away (opt-in)

Discovers your pending tasks (markdown checkboxes, `tasks.md`, halted routes from your history) and works through them while you're afk. Each iteration checks your budget first — if you're at 90 % of daily spend, it pauses automatically. Cooperates with `ScheduleWakeup` to stay inside Anthropic's prompt-cache window.

### 🎯 Methodology gates for big features (opt-in)

```bash
$ superagent-sparc init feat-billing-revamp
$ superagent-sparc gate         # phase 1: spec must have ≥3 ACs + edge cases
$ superagent-sparc advance      # only if gate passed
$ superagent-sparc report       # traceability matrix: AC → pseudo → arch → test → status
```

5 phases — Spec → Pseudo → Architecture → Refinement → Completion. Each phase has a pass/fail gate. **No 0.0-1.0 quality scores** — gates are boolean so you can't negotiate.

### 🧪 Coverage gap detection that tells you which tests to write

```bash
$ superagent-testgen scan && superagent-testgen gap --top 3
| File             | Coverage | LOC | Gap  | Impact |
| src/billing.ts   | 60.0%    | 200 | 10.0 | 2000.0 |
| src/auth.ts      | 62.5%    | 80  | 7.5  | 600.0  |
```

Then `superagent-testgen suggest src/auth.ts` emits a markdown skeleton with the uncovered line ranges (collapsed into runs like `L42-50`) and the named symbols you should test. **Testgen never writes test bodies** — the `tester` agent does.

### 🚦 Every diff gets a risk score before push

```bash
$ superagent-diff-risk report
# Diff Analysis: feature/auth-revamp
Primary: feature  (conf 0.84)   Impact: critical   Score: 7
Files: 12   diff lines: 1247
Risk factors:
  - security_paths: api/auth/, api/permissions/
  - large_diff: 1247 lines
  - cross_module: api/, db/, services/
Suggested reviewers: @sec-team @api-leads
```

7-category classifier + 5 risk-factor flags + CODEOWNERS-based reviewer suggestion. The `ship` skill force-confirms before push if impact is `high` or `critical`. **No GitHub API call** — pure git + file parsing.

---

## Install

```bash
git clone https://github.com/animeshbasak/SuperAgent
cd SuperAgent
bash install.sh
```

Takes ~30 seconds. ~120 MB on disk. **Idempotent** — run it again to upgrade, nothing duplicates.

### Confirm it worked

```bash
# 1. The router knows what to do
superagent-classify "review my PR for SQL injection"
# → chain includes [review, cso, security-review, agent:reviewer]

# 2. Your real Anthropic spend is visible
superagent-cost today

# 3. The learning loop is alive
superagent-patterns list

# 4. Diff scorer rates the current branch
superagent-diff-risk report
```

If all four return without error, you're done.

---

## Show me a real session

```
$ # You start work on a billing fix
$ superagent-sparc init feat-billing-rounding
~/.superagent/sparc/feat-billing-rounding

$ # Write the spec, run the gate
$ vim ~/.superagent/sparc/feat-billing-rounding/spec.md
$ superagent-sparc gate
gate PASSED (phase 1)
$ superagent-sparc advance
advanced phase 1 -> 2

$ # An hour later, before you push
$ superagent-diff-risk report
Primary: bugfix (conf 1.0)   Impact: medium   Score: 2
Files: 3   diff lines: 87
Risk factors: (none)

$ # All green — let's ship it
$ # (ship skill takes it from here: tests, version bump, push, PR)
```

That session never hit a rate limit. Never lost a token to re-reading the codebase. The classifier picked the chain. The safety gate watched the shell. The cost tracker logged the spend. The diff scorer cleared the push.

---

## Works with every AI coding tool you use

| | Claude Code | Cursor | Codex | Copilot | Continue | Windsurf | Gemini | Aider |
|---|---|---|---|---|---|---|---|---|
| **Same skills routed** | 32 | 7 `.mdc` | 32 `AGENTS.md` | inline | 33 rules | 32 rules | 32 skills | `CONVENTIONS.md` |
| **Safety hooks** | 9 events | self-polices | self-polices | self-polices | self-polices | self-polices | self-polices | self-polices |
| **Learning loop** | ✅ | reads store | reads store | reads store | reads store | reads store | reads store | reads store |
| **Cost tracker** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Specialist agents** | 5 + brain | dispatched | dispatched | dispatched | dispatched | dispatched | dispatched | dispatched |

`bin/superagent-compile` rewrites the same skills into every platform's native format. Hooks fire only on Claude Code; every other platform self-polices via the `superagent-safety` skill.

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

---

## The four releases — in plain English

| Release | What it means for you |
|---|---|
| [**v2.4 Wave 1**](CHANGELOG.md#v240--2026-05-09-wave-1-foundation) | The classifier remembers what worked. The cost tracker stops surprising you. The safety gate stops scary commands. |
| [**v2.5 Wave 2**](CHANGELOG.md#v250--2026-05-12-wave-2-autonomous--safe) | Optional prompt-injection scanner. Five named personas for parallel work. Full session observability. An autopilot for unattended runs. |
| [**v2.6 Wave 3**](CHANGELOG.md#v260--2026-05-13-wave-3-methodology--quality) | 5-phase pipeline for big features. Coverage gap detection. Per-diff risk scoring. |
| [**v3.0 Capstone**](https://github.com/animeshbasak/SuperAgent/releases/tag/v3.0.0) | Three real upstream projects (Scrapling / Octogent / jcode) distilled into native skills you can use today. |

---

## Where things live

```
SuperAgent/
├── bin/            22 command-line tools (installed to ~/.local/bin/)
├── skills/         32 skills (the source of truth)
├── agents/         6 specialist agent personas
├── hooks/          9 Claude Code lifecycle hooks
├── adapters/       7 IDE rule generators (Cursor, Codex, Copilot, Continue, Windsurf, Gemini, Aider)
├── bench/          45-prompt routing accuracy harness
├── test/           62 bash test scripts
└── install.sh      one-command install
```

After install:

```
~/.superagent/
├── brain/         routing decisions + learned patterns
├── cost/          per-tool token logs + budget config + alerts
├── learnings/     distilled corrections per project
├── obs/           span and metric logs
└── …              one subdir per opt-in feature
```

---

## FAQ

**I use Cursor, not Claude Code. Does this still help me?** Yes. `bin/superagent-compile` writes the same 32 skills as Cursor `.mdc` rules. The safety gate works as a self-policing skill instead of a hook — same behavior, slightly different mechanism.

**Will SuperAgent slow down my AI?** No. Hooks add ~1-5 ms per tool call. The classifier runs in under 100 ms on a 5-year-old laptop. Everything is local files; there's no network call on the hot path.

**Does SuperAgent send anything to a server?** No. Everything lives under `~/.superagent/` and `~/.claude/`. SuperAgent does not phone home.

**What if my Anthropic limit hits?** The cost tracker drops a flag at 90 % of daily budget. The auto-fallback skill reads it and proposes Opus → Sonnet → Haiku, or hands off to a local model via the free-claude-code proxy on port 18082. You stay productive.

**Does it change my code without asking?** Only when you ask. Risky shell hits the safety gate first. AIDefence and Autopilot are default off; you opt in. SPARC starts only when you run `sparc init`.

**Where does the learning come from?** Every successful chain logs to `~/.superagent/brain/routes.jsonl`. When the same chain succeeds three times for similar tasks, it gets promoted into `~/.superagent/brain/patterns.jsonl`. The classifier reads patterns first, then falls through to static rules.

**What's the catch?** Honest answer: 32 skills is a lot. The learning curve is real — but you don't need all of them on day one. Start with `superagent-cost today` and the safety gate, add `superagent-diff-risk` when you're about to push something scary, add `sparc` when you're starting a real feature.

---

## Credits

- [Anthropic Claude Code](https://claude.com/claude-code) — the hook-and-skill harness this is built on
- [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills) — 16 step-by-step engineering skills (the `agent-skills:*` namespace)
- [HeyGen Hyperframes](https://github.com/heygen-com/hyperframes) — deterministic video pipeline for the reels
- [Scrapling](https://github.com/D4Vinci/Scrapling), [Octogent](https://github.com/hesamsheikh/octogent), [jcode](https://github.com/1jehuang/jcode) — the three upstream projects whose work shipped into v3.0 capstone
- [Ruflo (claude-flow)](https://github.com/ruflo/claude-flow) — AIDefence pattern store reference + diff-risk classifier regex map

---

## License

MIT. See [LICENSE](LICENSE).
