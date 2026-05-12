---
name: cost-budget
description: Per-day Anthropic budget alerts and auto-downgrade. Reads ~/.superagent/cost/budget.json, emits tiered alerts at 50/75/90/100% of daily budget, and drops auto-downgrade.flag for the auto-fallback skill at 0.9. Use when user says "set budget", "alert me at 90%", "downgrade at threshold", "show today's spend".
---

# cost-budget

Wave 1 introduced per-task USD attribution and budget enforcement. The existing `token-stats` skill remains for stats; this skill is for *enforcement*.

## When to use

- User asks about today's spend, weekly cost, or budget status.
- User wants to set or change a daily/monthly budget.
- User configures auto-downgrade target (e.g. drop to Sonnet at 90%).
- An alert in `~/.superagent/cost/alerts.jsonl` requires user attention.

## Procedure

1. **Show today's spend with full v2 breakdown:**
   ```bash
   superagent-cost today
   ```
2. **Run alerts (idempotent, safe to re-run):**
   ```bash
   superagent-cost-alerts
   ```
3. **Set or update budget:**
   Edit `~/.superagent/cost/budget.json`:
   ```json
   {"daily_usd":20,"monthly_usd":400,
    "alert_thresholds":[0.5,0.75,0.9,1.0],
    "auto_downgrade":{"at":0.9,"target":"sonnet"},
    "hard_stop":{"at":1.0,"mode":"prompt"}}
   ```
4. **Inspect recent alerts:**
   ```bash
   tail -n 5 ~/.superagent/cost/alerts.jsonl | jq .
   ```

## Pricing

Default 4-dim pricing table is hardcoded for 2026-Q2 (Haiku/Sonnet/Opus × input/output/cache_write/cache_read). Override at `~/.superagent/cost/pricing.json` for non-standard tiers or custom contracts.

## Auto-downgrade flow

When `daily_usd` consumption ≥ `auto_downgrade.at` (default 0.9), `superagent-cost-alerts` writes `~/.superagent/auto-downgrade.flag` containing the target model. The `auto-fallback` skill reads this flag at routing time and proposes the in-tier shift (Opus→Sonnet, Sonnet→Haiku). The flag clears automatically when usage drops below the threshold.

## Hard stop

At 100% with `hard_stop.mode: prompt` (default), the next route prints a confirmation prompt rather than silently halting. Set `mode: halt` only for unattended workloads.
