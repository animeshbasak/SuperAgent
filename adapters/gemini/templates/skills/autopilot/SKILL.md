---
name: autopilot
description: Unattended pattern-driven loop. Discovers pending tasks (markdown checkboxes + routes-halt + tasks.md), predicts the next action using the Wave 1 patterns store, pauses at 90% budget, and cooperates with ScheduleWakeup for cache-warm iterations. Default off. Triggers on "autopilot", "run unattended", "keep working", "loop on the todo list".
---

# autopilot

Wave 2 ships an opt-in loop that pairs the Wave 1 pattern store with `ScheduleWakeup` to keep working between user prompts. **Default off** — bounded by maxIterations (≤1000), timeoutMinutes (≤1440), and the auto-downgrade.flag budget gate.

## When to use

- User says "run autopilot", "loop on the open todos", "keep working until done".
- A long markdown checklist exists and the user wants progress while afk.
- A previous session left `outcome:halt` records the user wants resumed.

## Procedure

1. **Inspect state:**
   ```bash
   superagent-autopilot status
   superagent-autopilot tasks
   ```
2. **Configure bounds (optional):**
   ```bash
   superagent-autopilot config --max-iterations 100
   superagent-autopilot config --timeout-minutes 60
   ```
   maxIterations clamps to [1, 1000]; timeoutMinutes clamps to [1, 1440].
3. **Enable:**
   ```bash
   superagent-autopilot enable
   ```
4. **Run an iteration:**
   ```bash
   superagent-autopilot iter
   ```
   Emits a JSON envelope with the predict result and a `ScheduleWakeup` directive at `delaySeconds=270` (under Anthropic's 300s prompt-cache TTL — tunable via `SUPERAGENT_CACHE_TTL_S`).
5. **The host skill** (or you, when chained) is responsible for calling the actual `ScheduleWakeup` tool with the emitted delay. autopilot does not run a daemon; it cooperates with the harness.
6. **Disable when done:**
   ```bash
   superagent-autopilot disable
   ```

## Budget gate

Before predict runs, `iter` checks for `~/.superagent/auto-downgrade.flag`. If present, output:

```json
{"paused": true, "reason": "budget"}
```

This resolves the autopilot/auto-fallback ping-pong. Precedence (from v3 spec §9): **budget > rate-limit > preference**. The flag clears automatically when `superagent-cost-alerts` sees usage drop back below the threshold (e.g., 5h reset window).

## Task discovery sources

In order:

1. **Markdown checkboxes** in cwd — `^[ -*]\s*\[ \]` lines from any `.md` file.
2. **routes.jsonl halts** — records with `outcome:halt` from `~/.superagent/brain/routes.jsonl`.
3. **tasks.md in cwd** — line-delimited tasks (comments with `#` ignored).

## Predict logic

For each pending task × each pattern in `patterns.jsonl`:

- `score = signal-token overlap × successRate`
- Best pattern wins. If `successRate > 0.7`: action `execute-pattern`. Otherwise: action `fallback` with the highest-priority pending task as target. Empty pending list: action `idle`.

## Files

- State: `~/.superagent/autopilot/state.json`
- Wakeup directive: emitted to stdout — caller invokes `ScheduleWakeup` tool.

## Ethos

Memory compounds. Pattern-driven prediction is only as good as the patterns store; the Stop hook (Wave 1) feeds it. Keep the budget gate in front of every iteration — that's the difference between a useful autopilot and a runaway one.
