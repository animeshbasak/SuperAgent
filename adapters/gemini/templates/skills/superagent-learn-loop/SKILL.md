---
name: superagent-learn-loop
description: SuperAgent learning loop. Promotes recurring done-routes into pattern records, decays stale ones, and feeds them back to the classifier. Use whenever the user wants to teach SuperAgent which chains worked, prune old patterns, or inspect/protect specific routes. Triggers on "promote pattern", "learn this routing", "decay patterns", "list patterns", "protect pattern".
---

# superagent-learn-loop

The SuperAgent classifier becomes self-improving in v2.4. Every Stop hook runs `superagent-patterns promote` (extracts repeated done-routes into pattern records) and `superagent-patterns decay` (exponentially decays inactive ones). The classifier reads `~/.superagent/brain/patterns.jsonl` and prepends matched chains when `successRate ≥ 0.6` and `useCount ≥ 5`.

## When to use

- User says "remember this pattern" / "promote this route" / "learn this".
- User wants to inspect, protect, or prune the pattern store.
- After a session where you discovered a chain that should survive into future sessions.

## Procedure

1. **List current patterns** to ground the user:
   ```bash
   superagent-patterns list
   ```
2. **Manual promote** if the user wants the latest routes folded in immediately (Stop hook already does this on session end):
   ```bash
   superagent-patterns promote
   ```
3. **Protect a high-value pattern** so decay won't drop it below 0.3:
   ```bash
   superagent-patterns protect p-<id>
   ```
4. **Manual prune** to clean noise below a custom threshold:
   ```bash
   superagent-patterns prune --below 0.3
   ```

## Files

- Store: `~/.superagent/brain/patterns.jsonl` (append-only JSONL).
- Source: `~/.superagent/brain/routes.jsonl` (read by `promote`).
- Defaults: `~/.superagent/defaults.toml` `[learning]` section.

## Ethos

Memory is compounding interest. Each successful chain that survives the gate becomes a faster route next session. Don't bypass the gate — `successRate ≥ 0.6 + useCount ≥ 5` is what keeps one-off coincidences out of the classifier.
