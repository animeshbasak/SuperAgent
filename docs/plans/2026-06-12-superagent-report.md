# Plan: `superagent-report` — org-pilot before/after report

**Date:** 2026-06-12
**Goal:** One command that turns SuperAgent's existing local telemetry into a
one-page report an engineering manager can hand to a budget owner. This is the
pilot kit for org sales: day-30 proof of spend, savings, and reliability.

## Why

The org-sales pitch ("saves tokens and money, verifiably") currently has no
artifact behind it. All the data already exists on disk; nothing aggregates it.
The report must contain **only measured numbers** — no extrapolated savings.
Where data is missing, the section says "no data", never a made-up figure.

## Data sources (all local, all already shipped)

| Source | What it provides |
|---|---|
| `~/.superagent/cost/calls.jsonl` + `pricing.json` | Per-call tokens, model, project, timestamp → spend by model, $ totals |
| `~/.superagent/brain/routes.jsonl` | Route outcomes (done/halt/fail), chains used, optimized flag |
| `~/.superagent/brain/optimizations.jsonl` | How many prompts were rewritten before dispatch |
| `~/.claude/superagent-stats.json` | mempalace/graphify tokens saved, per project + session |
| `~/.superagent/obs/metrics.YYYYMMDD.jsonl` | agent_token_usage histograms (supplementary) |

## CLI design

```
superagent-report [--days N] [--project PATH] [--json] [--out FILE]
```

- Default: last 30 days, all projects, markdown to stdout.
- `--json`: machine-readable, same structure, for dashboards/CI.
- `--out FILE`: write instead of stdout.
- Python3 stdlib only (consistent with superagent-optimize). No API calls.
- Missing/corrupt source files degrade to "no data" per section; exit 0.
- Bad arguments → usage on stderr, exit 1.

## Report sections (markdown one-pager)

1. **Header** — period, project filter, generated-at.
2. **Spend** — total tokens + USD by model (reuses pricing.json rates);
   local-model share of calls (the "free routing" line).
3. **Savings (measured)** — memory tokens saved (superagent-stats.json),
   prompts optimized count + change-rate (optimizations.jsonl).
4. **Reliability** — routes run, done/halt/fail rates, top 3 chains,
   % of routes that ended in a verification gate.
5. **Counterfactual** — actual spend vs "all tokens at Opus rates" delta.
   Labeled clearly as a ceiling comparison, not a claim.

## Tasks

1. `test/test-report.sh` — fixture HOME with synthetic jsonl/stats files;
   assert: valid markdown, valid `--json` shape, correct spend totals,
   correct outcome rates, `--days` filtering, missing-file degradation,
   bad-flag exit 1. **Write first, watch fail.**
2. `bin/superagent-report` — implement to green.
3. Wire docs: README CLI table row + count bump (24 → 25), CHANGELOG entry.
4. Full verification: new test + classify/hook suites + bench gate.
5. Ship: branch `feat/superagent-report`, PR to main.

## Non-goals (this iteration)

- No baseline-capture command (week-0 manual numbers stay manual).
- No HTML/PDF rendering — markdown is the deliverable.
- No claude-mem integration (plugin-internal format, unstable to parse).
