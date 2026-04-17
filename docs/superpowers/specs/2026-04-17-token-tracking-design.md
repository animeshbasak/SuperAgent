# Token Savings Tracker — Design Spec
**Date:** 2026-04-17
**Status:** Approved

## Overview

Track and display real token savings from superagent's tools (graphify, mempalace). Uses actual compression ratios measured from the user's codebase — not fixed marketing benchmarks. Persistent across sessions, displayed in statusline and via `/token-stats` command.

---

## Architecture

```
graphify update
        ↓
~/.claude/superagent-stats.json  ← stores real compression_ratio from YOUR index
        ↑
PostToolUse hook fires on every tool call
        ↓
~/.claude/superagent-tracker.sh
  ├── tool = graphify query/path?
  │     → measure response tokens × compression_ratio → log savings
  ├── tool = mempalace search/wake-up?
  │     → measure response tokens × 19 (conservative 20x baseline) → log savings
  └── other tools → skip (no fake numbers)
        ↓
~/.claude/superagent-stats.json  ← atomic update (tmp + mv)
        ↑                ↑
statusline script      /token-stats skill
[SA: 231k saved]       full breakdown table
```

---

## Components

### 1. `~/.claude/superagent-tracker.sh`
- Called by `PostToolUse` hook with `$TOOL_NAME` and `$TOOL_RESPONSE` env vars
- Graphify calls: reads `compression_ratio` from stats JSON, multiplies response token count by `(ratio - 1)`
- Mempalace calls: response tokens × 19 (20x conservative baseline, labeled as estimate)
- Token counting: `echo "$TOOL_RESPONSE" | wc -w` × 1.3 (words-to-tokens approximation)
- Atomic write: tmp file + mv to prevent corruption
- Silent operation: errors to `~/.claude/superagent-tracker.log` only

### 2. `~/.claude/superagent-statusline.sh`
- Reads stats JSON with `jq`
- Format: `[SA: 231k saved | 48x ratio]`
- Shows YOUR project's real compression ratio
- Fallbacks:
  - No JSON → `[SA: not calibrated]`
  - No `jq` → `[SA: install jq]`

### 3. `skills/token-stats/SKILL.md`
- `/token-stats` command
- Prints lifetime totals + last 5 sessions as table
- Per-tool breakdown: graphify queries, mempalace hits
- Shows: `Compression ratio: 48.3x (your codebase, measured)`
- Includes reminder to re-run `graphify update` after large codebase changes

### 4. Calibration — wired into `install.sh`
- After `graphify update`, extracts compression stats and seeds stats JSON
- Re-runs when user runs `graphify update` again
- Prints: `Calibration: 48.3x ratio stored ✓`

---

## Data Flow

**Initial calibration (once per project):**
```
graphify update
  → outputs: source_tokens, graph_tokens, ratio
  → superagent-tracker.sh --calibrate reads these
  → writes compression_ratio to stats JSON
```

**Per-query tracking:**
```
Tool fires → PostToolUse hook → superagent-tracker.sh
  → count response tokens (wc -w × 1.3)
  → graphify: saved = response_tokens × (ratio - 1)
  → mempalace: saved = response_tokens × 19
  → append to current session entry
  → update lifetime totals
  → mv tmp → stats JSON
```

---

## Stats JSON Structure

```json
{
  "compression_ratio": 48.3,
  "calibrated_at": "2026-04-17",
  "lifetime": {
    "graphify_queries": 0,
    "graphify_tokens_saved": 0,
    "mempalace_hits": 0,
    "mempalace_tokens_saved": 0,
    "total_saved": 0
  },
  "sessions": [
    {
      "date": "2026-04-17",
      "graphify_queries": 0,
      "mempalace_hits": 0,
      "saved": 0
    }
  ]
}
```

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Stats JSON missing | Tracker creates fresh with zero values |
| `jq` not installed | Statusline shows `[SA: install jq]` |
| Graphify not calibrated | Statusline shows `[SA: run graphify update]` |
| Corrupt JSON | Backup to `stats.json.bak`, reinitialize clean |
| Hook script failure | Silent, logged to tracker.log, never blocks Claude |

---

## Testing

- `install.sh` self-test: fires mock `PostToolUse` event, checks stats JSON updated
- `/token-stats --test`: prints sample output with fake data to verify formatting
- Calibration test: after `graphify update`, prints `Calibration: 48.3x ratio stored ✓`

---

## Honesty Constraints

- Token counts labeled as estimates (`wc -w × 1.3`)
- Mempalace savings labeled as "conservative estimate"
- Compression ratio always shown as "your codebase, measured" — never the 71.5x benchmark
- Statusline uses `~` prefix only for mempalace (estimated), plain number for graphify (measured)
