# Token Savings Tracker — Design Spec
**Date:** 2026-04-17
**Status:** Revised

## Overview

Track and display real token savings from superagent's tools (graphify, mempalace). Uses actual compression ratios measured from the user's codebase — not fixed marketing benchmarks. Persistent across sessions and projects, displayed in statusline and via `/token-stats` command.

---

## Architecture

```
graphify update
        ↓ parses graphify-out/graph.json for source/graph token counts
~/.claude/superagent-stats.json  ← per-project compression ratios + lifetime stats
        ↑
PostToolUse hook fires on every Bash tool call
        ↓
~/.claude/superagent-tracker.sh
  → reads stdin JSON: {tool_name, tool_input, tool_response}
  → if tool_name != "Bash" → exit 0 (skip)
  → parse tool_input.command:
      contains "graphify"?  → measure response tokens × (ratio - 1) → log
      contains "mempalace"? → measure response tokens × 19 → log (labeled ~estimate)
      else?                 → exit 0 (no fake numbers)
        ↓
~/.claude/superagent-stats.json  ← atomic update (tmp + mv), keyed by project path
        ↑                ↑
statusline script      /token-stats skill
[SA: 231k saved]       full breakdown table
```

---

## Components

### 1. `~/.claude/superagent-tracker.sh`

**Input:** JSON via stdin (Claude Code hook protocol)
```json
{
  "tool_name": "Bash",
  "tool_input": { "command": "graphify query \"how does auth work?\"" },
  "tool_response": { "output": "..." }
}
```

**Logic:**
1. Read stdin → parse with `jq`
2. If `tool_name != "Bash"` → exit 0
3. Extract `command = .tool_input.command`
4. Detect tool:
   - `echo "$command" | grep -q "graphify"` → graphify call
   - `echo "$command" | grep -q "mempalace"` → mempalace call
   - else → exit 0
5. Count response tokens: `echo "$response" | wc -w` × 1.3 (labeled as estimate)
6. Look up project's `compression_ratio` from stats JSON using `$PWD` as key
7. Calculate savings:
   - graphify: `response_tokens × (ratio - 1)`
   - mempalace: `response_tokens × 19` (labeled `~estimate`, no grounding beyond conservative baseline)
8. Generate `tool_use_id` from `date+command hash` → skip if already logged (dedup)
9. Atomic write: write to tmp → `mv` to stats JSON

**Silent operation:** all errors → `~/.claude/superagent-tracker.log`, never stdout

---

### 2. `~/.claude/superagent-statusline.sh`

- Reads stats JSON, looks up current project by `$PWD`
- Format: `[SA: 231k saved | 48x]` (graphify ratio measured, no `~`)
- Mempalace savings shown as: `[SA: 231k saved (~est)]` when mempalace-only session
- Fallbacks (in priority order):
  - `jq` missing → `[SA: install jq]`
  - No stats JSON → `[SA: not calibrated]`
  - Project not in stats → `[SA: run graphify update]`
  - Zero savings → `[SA: ready]`

---

### 3. `skills/token-stats/SKILL.md`

`/token-stats` command prints:

```
SuperAgent Token Stats — /path/to/project
─────────────────────────────────────────
Compression ratio : 48.3x  (your codebase, measured 2026-04-17)
─────────────────────────────────────────
Lifetime
  Graphify queries  : 47      → 198k tokens saved
  Mempalace hits    : 23      → ~31k tokens saved (estimate)
  Total saved       : ~229k tokens

Last 5 sessions
  Date        Graphify  Mempalace  Saved
  2026-04-17  12        4          ~58k
  2026-04-16  8         2          ~38k
  ...
─────────────────────────────────────────
Tip: Re-run `graphify update` after large codebase changes to recalibrate.
```

- `--test` flag: prints above with synthetic data to verify formatting without real stats

---

### 4. Calibration

**Trigger:** user runs `graphify update` (not a new flag — parse existing output)

**Method:** read `graphify-out/graph.json` after indexing:
- `source_tokens`: sum of all source file token estimates in the graph
- `graph_tokens`: total tokens in the serialized graph JSON
- `compression_ratio`: `source_tokens / graph_tokens`

**Wired into `install.sh`:** after `graphify update` completes, run:
```bash
superagent-tracker.sh --calibrate "$PWD"
```

**On recalibration:** updates ratio for `$PWD` key, preserves all existing stats.

---

## Stats JSON Structure

```json
{
  "version": 1,
  "projects": {
    "/Users/you/projects/myapp": {
      "compression_ratio": 48.3,
      "calibrated_at": "2026-04-17",
      "lifetime": {
        "graphify_queries": 47,
        "graphify_tokens_saved": 198000,
        "mempalace_hits": 23,
        "mempalace_tokens_saved": 31000,
        "total_saved": 229000
      },
      "sessions": [
        {
          "date": "2026-04-17",
          "graphify_queries": 12,
          "mempalace_hits": 4,
          "saved": 58000
        }
      ],
      "seen_tool_use_ids": ["abc123", "def456"]
    }
  }
}
```

**Session trimming:** keep last 30 sessions per project. On write, if `sessions.length > 30`, drop oldest.

**Deduplication:** `seen_tool_use_ids` = last 100 hashes (ring buffer). Hash = `sha256(date + command)[0:12]`.

---

## Data Flow

**Calibration (once per project, re-runs on `graphify update`):**
```
graphify update completes
  → superagent-tracker.sh --calibrate $PWD
  → reads graphify-out/graph.json
  → computes source_tokens / graph_tokens = ratio
  → upserts projects[$PWD].compression_ratio
  → prints: "Calibration: 48.3x ratio stored ✓"
```

**Per-query tracking:**
```
Bash tool fires → PostToolUse hook → superagent-tracker.sh (stdin = JSON)
  → parse tool_name, command, response
  → detect graphify or mempalace in command
  → dedup check via hash
  → count response tokens (wc -w × 1.3)
  → compute savings
  → upsert session entry for today
  → update lifetime totals
  → atomic mv to stats JSON
```

---

## Error Handling

| Condition | Behavior |
|-----------|----------|
| Stats JSON missing | Tracker creates fresh `{"version":1,"projects":{}}` |
| `jq` not installed | Statusline: `[SA: install jq]`; tracker: log error, exit 0 |
| Graphify not calibrated for this project | Statusline: `[SA: run graphify update]` |
| `graphify-out/graph.json` missing at calibration | Log warning, skip calibration silently |
| Corrupt JSON | Backup to `stats.json.bak`, reinitialize clean |
| Hook script failure | Silent, logged to `~/.claude/superagent-tracker.log`, never blocks Claude |
| Duplicate tool_use_id | Skip silently (dedup ring buffer) |
| `$PWD` key missing in stats | Tracker creates project entry with ratio=0, logs "not calibrated" |

---

## Testing

- `install.sh` self-test: pipes mock JSON to `superagent-tracker.sh`, checks stats JSON updated
- `/token-stats --test`: prints sample output with synthetic data
- Calibration test: after `graphify update`, prints `Calibration: 48.3x ratio stored ✓`
- Dedup test: pipe same mock JSON twice, verify count increments once only

---

## Honesty Constraints

- Token counts labeled as estimates (`wc -w × 1.3`)
- Mempalace savings always prefixed `~` (no grounding beyond conservative 20x baseline)
- Graphify savings shown without `~` — derived from real index, not a benchmark
- Compression ratio always shown as "your codebase, measured [date]"
- `/token-stats` output never mentions "71.5x" or "96.6%" benchmark numbers
