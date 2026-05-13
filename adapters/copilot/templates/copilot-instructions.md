# SuperAgent — AI Coding Agent Enhancement System

> Verify or die. Memory compounds. Leverage over toil.

## Task Routing

When a task matches these patterns, follow the corresponding skill chain:

| Pattern Keywords | Skill Chain |
|-----------------|-------------|
| bug, fix, broken, error, crash, stack trace, traceback, debug | systematic-debugging → test-driven-development |
| bug, fix, broken, error, crash, stack trace, traceback, debug | systematic-debugging → test-driven-development |

## Skills Summary

### aidefence
> Per-prompt injection + PII scanner. Pure regex over 58 shipped patterns (instruction override, role switching, prompt injection, jailbreak, encoding attacks, context manipulation, PII). Wired into UserPromptSubmit hook when enabled. Default off. Triggers on "scan prompt", "prompt injection", "PII scan", "jailbreak", "enable aidefence", "defend prompts".

# aidefence

Wave 2 adds a per-prompt threat scanner that runs at the harness boundary before the model sees the request. It is **default off** — too many dev workflows legitimately mention words like "ignore" or include test fixtures with fake credentials. Opt in with `superagent-aidefence enable` once the patterns suit your workflow.

## When to use

- User says "turn on aidefence" / "scan this prompt" / "is this prompt safe".
- You suspect a prompt-injection payload in user-provided content (

*(Full instructions available in SuperAgent skills directory)*


### auto-fallback
> Cost-aware routing brain — switch from Anthropic API to a free local model when the user is approaching plan limits, hitting 429 bursts, or asks to "save anthropic" / "switch local" / "rate limit" / "approaching limit". Auto-fires on complexity=trivial when budget is tight. Picks the right Ollama / LM Studio / llama.cpp model for the task complexity, runs a 3-step canary first, and switches via `superagent-switch`. State lives in `~/.superagent/`.

# auto-fallback

The cost-aware routing brain. Decides when to flip Claude Code from Anthropic API to a local model running behind the free-claude-code proxy on `http://localhost:18082`.

## Inputs

1. **Latest classifier output** — `meta.complexity` ∈ {trivial, moderate, complex}
   from `superagent-classify <task>`.
2. **Budget signal** — `superagent-cost today --json`
   - `pct_of_plan` — fraction of plan limit consumed (0..1)
   - `time_to_5h_reset_minutes` — minutes until rolling 5h limit r

*(Full instructions available in SuperAgent skills directory)*


### autopilot
> Unattended pattern-driven loop. Discovers pending tasks (markdown checkboxes + routes-halt + tasks.md), predicts the next action using the Wave 1 patterns store, pauses at 90% budget, and cooperates with ScheduleWakeup for cache-warm iterations. Default off. Triggers on "autopilot", "run unattended", "keep working", "loop on the todo list".

# autopilot

Wave 2 ships an opt-in loop that pairs the Wave 1 pattern store with `ScheduleWakeup` to keep working between user prompts. **Default off** — bounded by maxIterations (≤1000), timeoutMinutes (≤1440), and the auto-downgrade.flag budget gate.

## When to use

- User says "run autopilot", "loop on the open todos", "keep working until done".
- A long markdown checklist exists and the user wants progress while afk.
- A previous session left `outcome:halt` records the user wants resumed.


*(Full instructions available in SuperAgent skills directory)*


### autoplan
> Auto-pipeline a plan through product, design, and eng review sequentially, then synthesize into a single plan artifact. Use when you want the full review stack without invoking skills manually one at a time.

# Autoplan

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

Auto-review pipeline. Sequentially runs the full product (CEO), design, and engineering review skills over a single plan input, auto-deciding intermediate questions using the 6 decision principles, and synthesizing the results into one plan artifact at `docs/plans/<slug>.md`. Taste decisions and user challenges are surfaced at a final approval gate — everything else is decided for y

*(Full instructions available in SuperAgent skills directory)*


### cost-budget
> Per-day Anthropic budget alerts and auto-downgrade. Reads ~/.superagent/cost/budget.json, emits tiered alerts at 50/75/90/100% of daily budget, and drops auto-downgrade.flag for the auto-fallback skill at 0.9. Use when user says "set budget", "alert me at 90%", "downgrade at threshold", "show today's spend".

# cost-budget

Wave 1 introduced per-task USD attribution and budget enforcement. The existing `token-stats` skill remains for stats; this skill is for *enforcement*.

## When to use

- User asks about today's spend, weekly cost, or budget status.
- User wants to set or change a daily/monthly budget.
- User configures auto-downgrade target (e.g. drop to Sonnet at 90%).
- An alert in `~/.superagent/cost/alerts.jsonl` requires user attention.

## Procedure

1. **Show today's spend with full v2 bre

*(Full instructions available in SuperAgent skills directory)*


### cso
> Security audit — OWASP top-10 scan, STRIDE threat model, secrets grep, supply-chain check. Output is a severity-ranked findings report.

# Chief Security Officer

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Before launching to public / external users.
- Quarterly audit.
- When user asks "is this secure?"
- Any handling of auth, PII, payment, or LLM-driven code execution.

## Procedure

### 1. OWASP Top-10 scan
For each of: Broken Access Control, Cryptographic Failures, Injection, Insecure Design, Security Misconfiguration, Vulnerable/Outdated Components, 

*(Full instructions available in SuperAgent skills directory)*


### diff-risk
> Per-diff impact + reviewer suggestion. Classifier (feature/bugfix/refactor/docs/test/config/style) + IMPACT_KEYWORDS score → low/medium/high/critical + 5 risk-factor booleans (high churn, security paths, large diff, cross-module, DB migration) + CODEOWNERS-driven reviewer recommendation. Pure git+file parsing, no GitHub API. Triggers on "diff risk", "impact score", "blast radius", "reviewer suggest", "jujutsu" (legacy alias), "code owners". Renamed from `jujutsu` to avoid collision with Jujutsu VCS.

# diff-risk

Wave 3 ships a per-diff scoring bin that augments `review` and `ship`. Diff-risk reads `git diff` only; no GitHub API call. Output is a markdown report cached for downstream skills.

## When to use

- About to push a branch and want a blast-radius read.
- `review` skill needs context on what kind of change it's reviewing.
- Picking reviewers from CODEOWNERS without opening the GitHub UI.
- A legacy `/jujutsu` invocation — that's the same skill (deprecation alias kept).

## Procedure

*(Full instructions available in SuperAgent skills directory)*


### fanout
> Run 2+ skills in parallel via dispatching-parallel-agents and merge their reports. Use when subtasks are independent (no shared state).

# Fanout

> **Ethos:** Leverage over toil.

## When to use
- Two or more skills or tasks with NO shared state.
- User asked "review this AND also investigate AND also write docs".
- Research questions across independent domains.

## Inputs
- `$ARGUMENTS` — whitespace-separated list of skill names.

## Procedure

1. Parse `$ARGUMENTS` into a skill list. Reject if fewer than 2 entries.
2. Invoke `superpowers:dispatching-parallel-agents` — one agent per skill in the list.
3. Each sub-agent runs its

*(Full instructions available in SuperAgent skills directory)*


### framer-motion
> Build production-grade React animation with framer-motion (`motion` API). Triggers on "framer motion", "animate this component", "animate presence", "page transition", "layout animation", "spring animation", "drag/gesture", "scroll-linked animation", "stagger children", "exit animation", "shared layout". Use for component-level motion in a React/Next.js codebase. Routes alongside `ui-ux-pro-max` for design coherence and `webgl-craft` only when the motion is cinematic / 3D.

# framer-motion

Component-level motion intelligence for React. Covers the seven primitives
that ship most of the value in real apps:

1. **`<motion.*>` primitive** — declarative animate / initial / exit.
2. **`AnimatePresence`** — exit animations for unmounting components.
3. **Variants** — orchestrated animation states with `staggerChildren`.
4. **Layout animations** — `layout` / `layoutId` for shared element transitions.
5. **Gestures** — `whileHover`, `whileTap`, `drag`, `dragConstraints`.
6

*(Full instructions available in SuperAgent skills directory)*


### free-llm
> Route Claude Code through free or local LLMs via the free-claude-code transparent proxy on :18082. Triggers on "switch to free", "use local model", "no Anthropic key", "ollama", "deepseek", "use local llm", "free LLM". Privacy default is local-only (Ollama / LM Studio / llama.cpp); cloud free-tier (NIM / OpenRouter / DeepSeek) is opt-in. Token-savings questions stay with token-stats.

# free-llm

Wire Claude Code's outbound API calls through the `free-claude-code` proxy so the session runs on local or free-tier models instead of paid Anthropic. Default is **local-only** for privacy; cloud free-tier is opt-in.

## When to use

- User says "switch to free", "use local model", "no Anthropic key", "use local llm", "free LLM", "use ollama", "use deepseek".
- User has hit Anthropic rate limits or quota and wants to keep working.
- User wants offline / air-gapped operation.
- User e

*(Full instructions available in SuperAgent skills directory)*


### investigate
> Root-cause investigation. Enforces the Iron Law — no fixes without investigation first. 4 phases: Reproduce → Isolate → Explain → Verify. Upgrade over systematic-debugging when the bug is worth understanding, not just patching.

# Investigate

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Recurring bugs — same symptom, different patches.
- Any issue where "it fixed itself" was ever said.
- Flaky tests, race conditions, state corruption.
- Anywhere the fix would be guesswork without more data.

## The Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

If you don't know WHY the bug happens, your fix is guesswork. Guesswork fixes create 

*(Full instructions available in SuperAgent skills directory)*


### observability
> JSONL spans + metrics for SuperAgent. Read the trace tree of any session, aggregate counter/gauge/histogram metrics with p50/p95/p99, and flag anomalies via rolling mean + 2σ. Triggers on "show the trace", "metrics for today", "what's slow", "anomaly", "p95 latency".

# observability

Wave 2 ships pure-JSONL observability — no OTel libraries, no remote backend. Hooks emit spans on every tool call and metrics on every token-bearing event. Files live under `~/.superagent/obs/` and rotate daily.

## When to use

- User asks "why is X slow" / "show me the trace for last route" / "what was the bottleneck".
- User asks "how many tokens did I burn today" / "are there any anomalies in latency".
- After a session you want to attribute timing across subagents.

## Proc

*(Full instructions available in SuperAgent skills directory)*


### office-hours
> YC-style office hours intake. Six forcing product questions — customer, wedge, why-now, 10x, evidence, kill-switch. Output is a filled answer doc saved to docs/office-hours/.

# Office Hours

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Brand new feature idea, no plan yet.
- Scope feels soft / ambitious / maybe-everything.
- Before autoplan / plan-ceo-review.

## Inputs
- `$ARGUMENTS` — free-text description of the idea.

## Procedure

Answer all six verbatim. Don't skip. If you can't answer → that's the signal.

**1. Customer.** Who specifically is the customer? What is their current workaroun

*(Full instructions available in SuperAgent skills directory)*


### plan-ceo-review
> Pressure-test a plan with the CEO lens. Challenges scope via the four-mode framework (EXPANSION / SELECTIVE EXPANSION / HOLD / REDUCTION), rethinks the problem, asks the six forcing product questions, and recommends which mode to execute. Use before committing engineering resources.

# CEO Plan Review

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

Pressure-test a plan through the CEO lens before a single engineer-hour is spent. Rethink the problem, challenge the scope, rate the opportunity, and recommend which scope variant to actually execute. You are not here to rubber-stamp. You are here to make the plan extraordinary — or to kill it.

See `~/.superagent/ETHOS.md` for shared SuperAgent principles (verify or die, rew

*(Full instructions available in SuperAgent skills directory)*


### plan-design-review
> Designer's pressure-test — rate 10 design dimensions 0–10, identify fixes for anything under 7, propose top-3 highest-leverage changes. Iterative: rate → gap → fix → re-rate.

# Design Plan Review

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Before shipping any frontend change.
- When a design feels "off" but can't name why.
- When ui-ux-pro-max output needs critique before implementation.

## Inputs
- `$ARGUMENTS` — screenshot path, live URL, or plain-text description.

## The 0-10 Rating Method

For each dimension: **Rate 0-10. If not 10, state what a 10 would look like, then do the work.** 

*(Full instructions available in SuperAgent skills directory)*


### plan-eng-review
> Eng-manager pressure-test of a plan. Locks architecture, data flow, edge cases, test coverage, failure modes, migration safety. Use after plan-ceo-review and before execution.

# Eng Plan Review

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- After product/scope is locked (post plan-ceo-review).
- Before any implementation code is written.
- When a plan feels hand-wavy on how it actually works.

## Inputs
- `$ARGUMENTS` — plan text or path to plan markdown.

## Procedure

### 1. Architecture fit
- Does this fit existing patterns in the codebase? Use `graphify query` or `claude-mem:smart-explore` t

*(Full instructions available in SuperAgent skills directory)*


### review
> Pre-merge diff review gate. 6-point checklist covers scope drift, implementation fidelity, tests, migrations, TODOs, docs. Flags SQL safety / trust boundary / side-effect bugs. Rates LGTM / Needs Changes / Block.

# Review

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Before merging a PR.
- After `/ship` rebases and before it pushes.
- When a plan claims done and you want a second opinion.

## Inputs
- `$ARGUMENTS` — optional base branch name (default: `main`).

## Step 0 — diff-risk pre-check (Wave 3)

Before running the 6-point checklist, run `superagent-diff-risk` to ground the review in objective signal:

```bash
superagent-dif

*(Full instructions available in SuperAgent skills directory)*


### ship
> Full ship pipeline — detect platform, rebase on base, run tests, audit coverage + scope drift, pre-landing review, bump version, update CHANGELOG, commit in bisectable chunks, verification gate, push, open PR. Refuses to ship main/master.

# Ship

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Feature branch is complete.
- Tests are green locally.
- You want one command to take it from "done locally" to "PR open + verified".

## Pre-flight refusals
- Refuse if current branch is `main` or `master`.
- Refuse if `git status` shows uncommitted changes that aren't part of this ship.
- Refuse if no test command can be detected.

## The 20 Steps

### 1. Detect platf

*(Full instructions available in SuperAgent skills directory)*


### sparc
> 5-phase gate-enforced pipeline (Specification → Pseudocode → Architecture → Refinement → Completion). Boolean gates per phase; refuses to advance until the current gate passes. Use when complexity warrants methodology, when a feature needs an audit trail (ACs → tests → code), or when the user asks for a PRD/spec/RFC. Triggers on "sparc", "spec", "PRD", "methodology", "gate", "spike", "RFC", "traceability".

# sparc

Wave 3 adds a thin orchestrator that chains existing SuperAgent skills with hard boolean gate checks. SPARC is **opt-in per feature** — `/sparc init <slug>` starts a session; it never auto-fires.

## When to use

- The user describes a feature that needs an audit trail.
- A PR will touch security-sensitive or cross-module code.
- The user says "spec this", "write a PRD", "I want a methodology", "traceability matrix".
- You want a gate that refuses to ship before all ACs have passing tes

*(Full instructions available in SuperAgent skills directory)*


### superagent-learn-loop
> SuperAgent learning loop. Promotes recurring done-routes into pattern records, decays stale ones, and feeds them back to the classifier. Use whenever the user wants to teach SuperAgent which chains worked, prune old patterns, or inspect/protect specific routes. Triggers on "promote pattern", "learn this routing", "decay patterns", "list patterns", "protect pattern".

# superagent-learn-loop

The SuperAgent classifier becomes self-improving in v2.4. Every Stop hook runs `superagent-patterns promote` (extracts repeated done-routes into pattern records) and `superagent-patterns decay` (exponentially decays inactive ones). The classifier reads `~/.superagent/brain/patterns.jsonl` and prepends matched chains when `successRate ≥ 0.6` and `useCount ≥ 5`.

## When to use

- User says "remember this pattern" / "promote this route" / "learn this".
- User wants to insp

*(Full instructions available in SuperAgent skills directory)*


### superagent-safety
> Reversibility-aware action gate. Universal rule any backend can follow. Triggers BEFORE the agent issues a destructive shell command, force-push, history-rewrite, mass DB mutation, sensitive-file edit, or permission-skip flag. On Claude Code, the hooks/superagent-safety.py PreToolUse hook enforces this same logic at the harness level. Use whenever the request leads toward "rm -rf", "git push --force", "git reset --hard", "DROP", "TRUNCATE", "--no-verify", "--dangerously-skip-permissions", "migrate down", "kill -9", or edits to .env / .ssh / credentials / .pem / .key / /etc.

# SuperAgent Safety

> **Doctrine: reversibility over speed.** A pause to confirm costs seconds. An unwanted destructive op costs hours and trust. Always pause-and-ask on irreversible actions, even when the user appears to have asked for them earlier in the session — *authorization is scoped to what was actually requested, not extrapolated from it.*

## When to use

This skill is consulted **before** the agent issues a tool call whose effect is hard to reverse. Triggering signals:

- Bash comman

*(Full instructions available in SuperAgent skills directory)*


### superagent-switch
> Drive the `superagent-switch` CLI to inspect, swap, or restore the active LLM backend. Triggers on "list local models", "switch to <model>", "switch back", "restore anthropic", "canary <model>", "what model am i on", "auto fallback on/off", "/superagent-switch <op>". Use when the user wants direct, surgical control over the model swap — not when they're asking *whether* to switch (that is `auto-fallback`) or *how to set up* the proxy (that is `free-llm`).

# superagent-switch

Surgical operator for the cost-aware proxy / model switcher. Wraps the
`superagent-switch` CLI in a thin, deterministic skill so the agent always
runs the *right* subcommand, parses output the same way, and reports state
back to the user in a consistent shape.

## When to use

- User typed `/superagent-switch <op>` (one of: `list`, `to`, `back`,
  `canary`, `status`, `auto`).
- User said "list local models", "switch to qwen3", "switch back to
  Anthropic", "what backend am I

*(Full instructions available in SuperAgent skills directory)*


### testgen
> Coverage gap detection + test scaffolding. Calls the project's own coverage tool (jest/vitest/pytest/tarpaulin/go-cover), normalizes the JSON output, ranks files by gap × LOC, and emits a markdown skeleton naming the tests to write — never the bodies. Triggers on "coverage", "untested", "test coverage", "testgen", "tdd gap", "scaffold tests", "coverage gap".

# testgen

Wave 3 ships an opt-in coverage adapter that augments TDD. Testgen is the inspector; the `tester` agent (Wave 2) and `agent-skills:test-driven-development` are the implementers. Testgen **never writes test bodies**.

## When to use

- The user asks "where's our coverage weakest" / "scaffold tests for X" / "coverage gap report".
- About to refactor untested code — generate the lock-down test list first.
- `ship` skill consults testgen to refuse a regression in coverage before push.

##

*(Full instructions available in SuperAgent skills directory)*


### video-craft
# Video Craft — HTML Compositions to MP4 via hyperframes

This skill teaches the agent to author hyperframes compositions (HTML + GSAP +
`data-*` timing attributes) and render them deterministically to MP4. The render
pipeline is seek-driven and frame-accurate — preview ≠ render performance, but
preview === render visual output. Treat the composition as the single source of
truth; never try to play media or hide clips in scripts.

---

## When to use

- User asks for a video, MP4, or rendered mo

*(Full instructions available in SuperAgent skills directory)*


### webgl-craft
# WebGL Craft — Technique Library for Premium Creative Web

This skill is a router, not an implementation. It exists to answer one question:
**"What technique should I reach for, and what is its cost?"**

Do not try to implement anything from memory. Find the right reference file first,
read it, then build. Premium creative web rewards precision over breadth; the wrong
technique applied well still loses to the right technique applied simply.

---

## HOW TO USE THIS SKILL

1. Identify which of t

*(Full instructions available in SuperAgent skills directory)*


## Non-Negotiables

- NEVER skip verification on build/fix tasks
- NEVER start implementing without a plan
- ALWAYS verify work before declaring done
