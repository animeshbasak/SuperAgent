---
name: auto-fallback
description: Cost-aware routing brain — switch from Anthropic API to a free local model when the user is approaching plan limits, hitting 429 bursts, or asks to "save anthropic" / "switch local" / "rate limit" / "approaching limit". Auto-fires on complexity=trivial when budget is tight. Picks the right Ollama / LM Studio / llama.cpp model for the task complexity, runs a 3-step canary first, and switches via `superagent-switch`. State lives in `~/.superagent/`.
---

# auto-fallback

The cost-aware routing brain. Decides when to flip Claude Code from Anthropic API to a local model running behind the free-claude-code proxy on `http://localhost:18082`.

## Inputs

1. **Latest classifier output** — `meta.complexity` ∈ {trivial, moderate, complex}
   from `superagent-classify <task>`.
2. **Budget signal** — `superagent-cost today --json`
   - `pct_of_plan` — fraction of plan limit consumed (0..1)
   - `time_to_5h_reset_minutes` — minutes until rolling 5h limit resets
   - `recent_429_count_60s` — number of 429s in the last 60 seconds
3. **Available local models** — `superagent-switch list` (auto-refreshes if stale)
4. **Auto flag** — `~/.superagent/auto-fallback.flag` ("on" or "off")

## Decision Tree

```
complexity == "trivial"
  → suggest qwen2.5-coder:7b (Ollama)

complexity == "moderate"
  → suggest qwen3-coder:next

complexity == "complex" AND pct_of_plan > 0.80
  → KEEP Anthropic, warn user
    "complexity=complex; local models will degrade quality. burning Anthropic budget instead."
    Offer manual switch.

time_to_5h_reset_minutes < 30  AND complexity != "complex"
  → suggest local for moderate/trivial

recent_429_count_60s >= 3
  → switch immediately, prompt user to confirm
    (NOT auto unless `auto on`)
```

## Procedure

1. Read latest classifier output — pull `meta.complexity`.
2. Run `superagent-cost today --json` — parse budget signals.
3. Apply the decision tree above to pick a candidate model (or NONE).
4. If a local model is suggested:
   a. Show menu of available models from `superagent-switch list`.
   b. User picks one (or accepts the suggested default).
   c. Run `superagent-switch canary <model> --depth=3`.
   d. **On canary pass** → `superagent-switch to <model>`; tell user to restart Claude Code.
   e. **On canary fail** → freeze. Prompt:
      - "try a different model"
      - "wait — keep Anthropic, retry in N minutes"
      - "accept Anthropic limits — proceed at reduced rate"
      Do NOT auto-revert.
5. If `auto-fallback.flag == on` AND no in-flight tool calls, the limit-watch hook
   may invoke this skill non-interactively; in that mode it must still confirm
   before flipping (pre-canary). Default behavior: require confirmation.

## Costs locked in

| complexity  | budget | action                                        |
|-------------|--------|-----------------------------------------------|
| trivial     | any    | local (`qwen2.5-coder:7b`)                    |
| moderate    | <80%   | Anthropic (Sonnet/Haiku)                      |
| moderate    | >80%   | local (`qwen3-coder:next`)                    |
| complex     | <80%   | Anthropic (Opus/Sonnet)                       |
| complex     | >80%   | KEEP Anthropic + warn — let user override     |
| any         | 429×3  | switch immediately + confirm                  |

## Recovery

- If switching breaks Claude Code → `superagent-switch back` restores Anthropic.
- Backed-up `ANTHROPIC_API_KEY` lives at `~/.superagent/anthropic-key.bak`.

## Notes

- All state under `~/.superagent/`, never `~/.claude/`.
- Free-claude-code proxy port is **18082** (not 8082).
- Auto-switch defaults OFF; opt-in for unattended use only.
- Canary is mandatory before any switch — never skip.
