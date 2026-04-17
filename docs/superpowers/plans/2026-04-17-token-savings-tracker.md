# Token Savings Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real token savings tracking to superagent — persistent per-project stats, live statusline badge, and `/token-stats` command using measured compression ratios from `graphify benchmark`.

**Architecture:** A `PostToolUse` hook script reads stdin JSON from Claude Code, detects graphify/mempalace in Bash commands, computes savings using ratios measured via `graphify benchmark`, and atomically updates `~/.claude/superagent-stats.json` keyed by `$PWD`. A statusline script reads the JSON for a live badge. A skill provides the detailed report command.

**Tech Stack:** bash, jq, graphify CLI (benchmark subcommand), Claude Code hooks (PostToolUse + statusLine)

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `hooks/superagent-tracker.sh` | PostToolUse hook: detect tools, compute savings, atomic write |
| Create | `hooks/superagent-statusline.sh` | Statusline badge: read stats JSON, format output |
| Create | `skills/token-stats/SKILL.md` | `/token-stats` skill: print lifetime + session table |
| Modify | `install.sh` | Copy scripts to `~/.claude/`, wire hook + statusLine in settings.json, run calibration |

---

## Task 1: Create `hooks/superagent-tracker.sh` — Core Tracker

**Files:**
- Create: `hooks/superagent-tracker.sh`

- [ ] **Step 1: Write the tracker script**

```bash
#!/usr/bin/env bash
# superagent-tracker.sh — PostToolUse hook + calibration
# Hook mode: called by Claude Code with JSON payload via stdin
# Calibration mode: called with --calibrate <project_dir>

set -euo pipefail

STATS="$HOME/.claude/superagent-stats.json"
LOG="$HOME/.claude/superagent-tracker.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG" 2>/dev/null || true; }

init_stats() {
  if [[ ! -f "$STATS" ]]; then
    echo '{"version":1,"projects":{}}' > "$STATS"
  fi
}

# ── Calibration mode ──────────────────────────────────────────────────────────
if [[ "${1:-}" == "--calibrate" ]]; then
  PROJECT="${2:-$PWD}"
  GRAPH_JSON="$PROJECT/graphify-out/graph.json"

  if [[ ! -f "$GRAPH_JSON" ]]; then
    log "calibrate: no graph.json at $GRAPH_JSON — run graphify update first"
    exit 0
  fi

  GRAPHIFY_BIN=$(command -v graphify 2>/dev/null || echo "$HOME/.local/bin/graphify")
  if [[ ! -x "$GRAPHIFY_BIN" ]]; then
    log "calibrate: graphify not found"
    exit 0
  fi

  BENCHMARK=$("$GRAPHIFY_BIN" benchmark "$GRAPH_JSON" 2>/dev/null)
  RATIO=$(echo "$BENCHMARK" | grep -o 'Reduction:[^x]*x' | grep -o '[0-9.]*' | tail -1)
  CORPUS=$(echo "$BENCHMARK" | grep 'Corpus:' | grep -o '~[0-9,]*' | tr -d '~,' | head -1)

  if [[ -z "$RATIO" ]]; then
    log "calibrate: could not parse reduction ratio from benchmark output"
    exit 0
  fi

  TODAY=$(date '+%Y-%m-%d')
  init_stats

  TMP=$(mktemp)
  jq --arg project "$PROJECT" \
     --argjson ratio "$RATIO" \
     --argjson corpus "${CORPUS:-0}" \
     --arg date "$TODAY" \
     '.projects[$project] //= {
       "compression_ratio": 0,
       "calibrated_at": null,
       "corpus_tokens": 0,
       "lifetime": {"graphify_queries":0,"graphify_tokens_saved":0,"mempalace_hits":0,"mempalace_tokens_saved":0,"total_saved":0},
       "sessions": [],
       "seen_tool_use_ids": []
     } |
     .projects[$project].compression_ratio = $ratio |
     .projects[$project].corpus_tokens = $corpus |
     .projects[$project].calibrated_at = $date' \
     "$STATS" > "$TMP" 2>>"$LOG" && mv "$TMP" "$STATS"

  echo "Calibration: ${RATIO}x ratio stored ✓  (corpus: ~${CORPUS:-unknown} tokens)"
  exit 0
fi

# ── Hook mode — reads Claude Code PostToolUse stdin JSON ──────────────────────
PAYLOAD=$(cat)
TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_name // ""' 2>/dev/null)

# Only care about Bash tool calls
[[ "$TOOL_NAME" != "Bash" ]] && exit 0

COMMAND=$(echo "$PAYLOAD"  | jq -r '.tool_input.command // ""'    2>/dev/null)
RESPONSE=$(echo "$PAYLOAD" | jq -r '.tool_response.output // ""'  2>/dev/null)

# Detect which superagent tool was used
TOOL_TYPE=""
echo "$COMMAND" | grep -q "graphify"   && TOOL_TYPE="graphify"
echo "$COMMAND" | grep -q "mempalace"  && TOOL_TYPE="mempalace"
[[ -z "$TOOL_TYPE" ]] && exit 0

init_stats

# Dedup — skip if we already recorded this command today
TODAY=$(date '+%Y-%m-%d')
HASH=$(printf '%s%s' "$TODAY" "$COMMAND" | shasum -a 256 | cut -c1-12)
PROJECT="$PWD"

ALREADY_SEEN=$(jq --arg p "$PROJECT" --arg h "$HASH" \
  '(.projects[$p].seen_tool_use_ids // []) | map(select(. == $h)) | length' \
  "$STATS" 2>/dev/null || echo 0)
[[ "${ALREADY_SEEN:-0}" -gt 0 ]] && exit 0

# Count response tokens: words × 1.3 (labeled as estimate)
WORD_COUNT=$(echo "$RESPONSE" | wc -w | tr -d ' ')
RESPONSE_TOKENS=$(echo "scale=0; $WORD_COUNT * 13 / 10" | bc 2>/dev/null || echo 0)

# Look up this project's compression ratio
RATIO=$(jq --arg p "$PROJECT" '.projects[$p].compression_ratio // 0' "$STATS" 2>/dev/null || echo 0)

# Compute savings
if [[ "$TOOL_TYPE" == "graphify" ]]; then
  # Savings = tokens graphify returned × (ratio - 1) — ratio measured from real index
  SAVED=$(echo "scale=0; $RESPONSE_TOKENS * ($RATIO - 1) / 1" | bc 2>/dev/null || echo 0)
else
  # mempalace: conservative 20x baseline — labeled ~estimate in display
  SAVED=$(echo "scale=0; $RESPONSE_TOKENS * 19 / 1" | bc 2>/dev/null || echo 0)
fi

# Atomic write: upsert project, session, lifetime, dedup ring buffer
TMP=$(mktemp)
jq --arg project  "$PROJECT" \
   --arg tool     "$TOOL_TYPE" \
   --argjson saved "$SAVED" \
   --arg date     "$TODAY" \
   --arg hash     "$HASH" \
   '
   # Ensure project entry exists
   .projects[$project] //= {
     "compression_ratio": 0,
     "calibrated_at": null,
     "corpus_tokens": 0,
     "lifetime": {"graphify_queries":0,"graphify_tokens_saved":0,"mempalace_hits":0,"mempalace_tokens_saved":0,"total_saved":0},
     "sessions": [],
     "seen_tool_use_ids": []
   } |

   # Update lifetime counters
   (if $tool == "graphify" then
     .projects[$project].lifetime.graphify_queries += 1 |
     .projects[$project].lifetime.graphify_tokens_saved += $saved
   else
     .projects[$project].lifetime.mempalace_hits += 1 |
     .projects[$project].lifetime.mempalace_tokens_saved += $saved
   end) |
   .projects[$project].lifetime.total_saved += $saved |

   # Upsert today session (prepend if new date, otherwise update first entry)
   (if (.projects[$project].sessions | length) == 0 or .projects[$project].sessions[0].date != $date then
     .projects[$project].sessions = [{
       "date": $date,
       "graphify_queries": (if $tool == "graphify" then 1 else 0 end),
       "mempalace_hits":   (if $tool == "mempalace" then 1 else 0 end),
       "saved": $saved
     }] + .projects[$project].sessions
   else
     .projects[$project].sessions[0].saved += $saved |
     (if $tool == "graphify" then .projects[$project].sessions[0].graphify_queries += 1
      else .projects[$project].sessions[0].mempalace_hits += 1 end)
   end) |

   # Trim sessions to last 30
   .projects[$project].sessions = .projects[$project].sessions[:30] |

   # Dedup ring buffer — keep last 100 hashes
   .projects[$project].seen_tool_use_ids =
     ([$hash] + (.projects[$project].seen_tool_use_ids // []))[:100]
   ' \
   "$STATS" > "$TMP" 2>>"$LOG" && mv "$TMP" "$STATS" \
   || log "jq update failed for $TOOL_TYPE in $PROJECT"

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x /path/to/superagent/hooks/superagent-tracker.sh
```

Expected: `ls -la hooks/superagent-tracker.sh` shows `-rwxr-xr-x`

- [ ] **Step 3: Test calibration mode with a real graph.json**

First build a graph (use any project with code files):
```bash
cd /tmp && mkdir test-cal && cd test-cal
echo 'def hello(): return "world"' > hello.py
graphify update . 2>&1
```

Then test calibration:
```bash
bash /path/to/superagent/hooks/superagent-tracker.sh --calibrate /tmp/test-cal
cat ~/.claude/superagent-stats.json | jq '.projects["/tmp/test-cal"]'
```

Expected output:
```
Calibration: <N>x ratio stored ✓  (corpus: ~<M> tokens)
```
Expected JSON: project entry with `compression_ratio`, `calibrated_at` = today, `corpus_tokens`.

- [ ] **Step 4: Test hook mode — graphify detection**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"graphify query \"how does auth work\""},"tool_response":{"output":"Auth uses JWT tokens stored in Redis. The AuthMiddleware validates tokens on every request."}}' \
  | bash /path/to/superagent/hooks/superagent-tracker.sh

cat ~/.claude/superagent-stats.json | jq ".projects[\"$PWD\"].lifetime"
```

Expected: `graphify_queries` = 1, `graphify_tokens_saved` > 0, `total_saved` > 0.

- [ ] **Step 5: Test dedup — same command twice doesn't double-count**

```bash
PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"graphify query \"dedup test\""},"tool_response":{"output":"test output"}}'
echo "$PAYLOAD" | bash /path/to/superagent/hooks/superagent-tracker.sh
echo "$PAYLOAD" | bash /path/to/superagent/hooks/superagent-tracker.sh

cat ~/.claude/superagent-stats.json | jq ".projects[\"$PWD\"].lifetime.graphify_queries"
```

Expected: `1` (not `2`)

- [ ] **Step 6: Test non-Bash tool is ignored**

```bash
echo '{"tool_name":"Read","tool_input":{"file_path":"/etc/hosts"},"tool_response":{"content":"127.0.0.1 localhost"}}' \
  | bash /path/to/superagent/hooks/superagent-tracker.sh

# Verify no graphify/mempalace counter incremented — only way to confirm is stats unchanged
cat ~/.claude/superagent-stats.json | jq ".projects[\"$PWD\"].lifetime.graphify_queries"
```

Expected: same count as before (no increment)

- [ ] **Step 7: Commit**

```bash
git add hooks/superagent-tracker.sh
git commit -m "feat: add superagent-tracker.sh — PostToolUse hook with calibration"
```

---

## Task 2: Create `hooks/superagent-statusline.sh` — Live Badge

**Files:**
- Create: `hooks/superagent-statusline.sh`

- [ ] **Step 1: Write the statusline script**

```bash
#!/usr/bin/env bash
# superagent-statusline.sh — Claude Code statusLine badge
# Output: [SA: ~231k saved | 48x]  or a fallback message

STATS="$HOME/.claude/superagent-stats.json"

# Dependency check
command -v jq >/dev/null 2>&1 || { echo "[SA: install jq]"; exit 0; }

# Stats file must exist
[[ -f "$STATS" ]] || { echo "[SA: not calibrated]"; exit 0; }

PROJECT="$PWD"
PROJECT_DATA=$(jq --arg p "$PROJECT" '.projects[$p] // empty' "$STATS" 2>/dev/null)

# Project not tracked yet
[[ -z "$PROJECT_DATA" ]] && { echo "[SA: run graphify update]"; exit 0; }

RATIO=$(echo "$PROJECT_DATA" | jq '.compression_ratio // 0')
TOTAL=$(echo "$PROJECT_DATA" | jq '.lifetime.total_saved // 0')
MEM_SAVED=$(echo "$PROJECT_DATA" | jq '.lifetime.mempalace_tokens_saved // 0')

# Not calibrated
[[ "${RATIO%.*}" == "0" ]] && { echo "[SA: run graphify update]"; exit 0; }

# Calibrated but no usage yet
[[ "${TOTAL}" -eq 0 ]] && { echo "[SA: ready | ${RATIO}x]"; exit 0; }

# Format total: M / k / raw
if   [[ "$TOTAL" -ge 1000000 ]]; then
  DISPLAY=$(echo "scale=1; $TOTAL / 1000000" | bc)M
elif [[ "$TOTAL" -ge 1000 ]]; then
  DISPLAY=$(echo "scale=0; $TOTAL / 1000" | bc)k
else
  DISPLAY="$TOTAL"
fi

# Prefix ~ only when mempalace contributed (estimated savings included)
PREFIX=""
[[ "$MEM_SAVED" -gt 0 ]] && PREFIX="~"

echo "[SA: ${PREFIX}${DISPLAY} saved | ${RATIO}x]"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x /path/to/superagent/hooks/superagent-statusline.sh
```

- [ ] **Step 3: Test all fallback paths**

```bash
# Fallback 1 — no stats file
STATS_BACKUP="$HOME/.claude/superagent-stats.json.bak"
mv ~/.claude/superagent-stats.json "$STATS_BACKUP" 2>/dev/null || true
bash hooks/superagent-statusline.sh
# Expected: [SA: not calibrated]

# Restore
mv "$STATS_BACKUP" ~/.claude/superagent-stats.json

# Fallback 2 — project not in stats (run from a different dir)
cd /tmp && bash /path/to/superagent/hooks/superagent-statusline.sh
# Expected: [SA: run graphify update]
cd -

# Normal output — run from project dir that has been calibrated and used
bash hooks/superagent-statusline.sh
# Expected: [SA: ready | <N>x]  or  [SA: ~Xk saved | Nx]
```

- [ ] **Step 4: Commit**

```bash
git add hooks/superagent-statusline.sh
git commit -m "feat: add superagent-statusline.sh — statusLine badge with fallbacks"
```

---

## Task 3: Create `skills/token-stats/SKILL.md` — Report Command

**Files:**
- Create: `skills/token-stats/SKILL.md`

- [ ] **Step 1: Write the skill**

```markdown
---
name: token-stats
description: Show superagent token savings stats for the current project — lifetime totals, last 5 sessions, compression ratio. Use when user asks about token savings, how many tokens saved, superagent stats, or runs /token-stats.
argument-hint: "[--test]"
---

# SuperAgent Token Stats

Show token savings for the current project.

## Steps

1. Check if `--test` flag was passed in arguments. If yes, skip to **Test Mode** below.

2. Run this command and display the formatted output:

```bash
bash -c '
STATS="$HOME/.claude/superagent-stats.json"
PROJECT="$PWD"

if [[ ! -f "$STATS" ]]; then
  echo "No stats found. Run: graphify update <your-project-dir>"
  exit 0
fi

PROJECT_DATA=$(jq --arg p "$PROJECT" ".projects[\$p] // empty" "$STATS" 2>/dev/null)

if [[ -z "$PROJECT_DATA" ]]; then
  echo "No stats for: $PROJECT"
  echo "Run: graphify update $PROJECT"
  exit 0
fi

RATIO=$(echo "$PROJECT_DATA" | jq ".compression_ratio // 0")
CAL_DATE=$(echo "$PROJECT_DATA" | jq -r ".calibrated_at // \"never\"")
GQ=$(echo "$PROJECT_DATA"  | jq ".lifetime.graphify_queries // 0")
GS=$(echo "$PROJECT_DATA"  | jq ".lifetime.graphify_tokens_saved // 0")
MH=$(echo "$PROJECT_DATA"  | jq ".lifetime.mempalace_hits // 0")
MS=$(echo "$PROJECT_DATA"  | jq ".lifetime.mempalace_tokens_saved // 0")
TOT=$(echo "$PROJECT_DATA" | jq ".lifetime.total_saved // 0")

fmt() {
  local n=$1
  if   [[ $n -ge 1000000 ]]; then echo "$(echo "scale=1; $n/1000000" | bc)M"
  elif [[ $n -ge 1000 ]];    then echo "$(echo "scale=0; $n/1000"    | bc)k"
  else echo "$n"; fi
}

echo ""
echo "SuperAgent Token Stats — $PROJECT"
echo "──────────────────────────────────────────────"
echo "Compression ratio : ${RATIO}x  (your codebase, measured $CAL_DATE)"
echo "──────────────────────────────────────────────"
echo "Lifetime"
echo "  Graphify queries  : $GQ"
printf "    → %s tokens saved\n" "$(fmt $GS)"
echo "  Mempalace hits    : $MH"
printf "    → ~%s tokens saved (estimate)\n" "$(fmt $MS)"
printf "  Total saved       : ~%s tokens\n" "$(fmt $TOT)"
echo ""
echo "Last 5 sessions"
printf "  %-12s  %-10s  %-10s  %s\n" "Date" "Graphify" "Mempalace" "Saved"
echo "$PROJECT_DATA" | jq -r "
  .sessions[:5][] |
  [.date, (.graphify_queries|tostring), (.mempalace_hits|tostring), (.saved|tostring)] |
  @tsv" | while IFS=$'"'"'\t'"'"' read -r d g m s; do
    printf "  %-12s  %-10s  %-10s  ~%s\n" "$d" "$g" "$m" "$s"
  done
echo "──────────────────────────────────────────────"
echo "Tip: re-run '\''graphify update <dir>'\'' after large codebase changes."
echo ""
'
```

## Test Mode

When `--test` argument is passed, display this hardcoded sample output:

```
SuperAgent Token Stats — /your/project (SAMPLE DATA)
──────────────────────────────────────────────
Compression ratio : 48.3x  (your codebase, measured 2026-04-17)
──────────────────────────────────────────────
Lifetime
  Graphify queries  : 47
    → 198k tokens saved
  Mempalace hits    : 23
    → ~31k tokens saved (estimate)
  Total saved       : ~229k tokens

Last 5 sessions
  Date          Graphify    Mempalace   Saved
  2026-04-17    12          4           ~58k
  2026-04-16    8           2           ~38k
  2026-04-15    15          6           ~71k
  2026-04-14    5           3           ~22k
  2026-04-13    7           8           ~40k
──────────────────────────────────────────────
Tip: re-run 'graphify update <dir>' after large codebase changes.
```
```

- [ ] **Step 2: Test the skill manually**

```bash
# Simulate what Claude does when skill runs:
bash -c '
STATS="$HOME/.claude/superagent-stats.json"
PROJECT="$PWD"
PROJECT_DATA=$(jq --arg p "$PROJECT" ".projects[\$p] // empty" "$STATS" 2>/dev/null)
[[ -z "$PROJECT_DATA" ]] && echo "No data for $PROJECT — calibrate first" && exit 0
echo "$PROJECT_DATA" | jq ".lifetime"
'
```

Expected: shows lifetime counters from Task 1 tests

- [ ] **Step 3: Commit**

```bash
git add skills/token-stats/SKILL.md
git commit -m "feat: add token-stats skill — /token-stats command with lifetime report"
```

---

## Task 4: Update `install.sh` — Wire Everything

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Add Step 10 — copy hook scripts to `~/.claude/`**

Add after the existing Step 9 block (after `popd >/dev/null`):

```bash
# ── Step 10: Install token savings tracker ────────────────────────────────────
info "Installing token savings tracker..."
TRACKER_SRC="$SCRIPT_DIR/hooks/superagent-tracker.sh"
STATUSLINE_SRC="$SCRIPT_DIR/hooks/superagent-statusline.sh"

if [[ -f "$TRACKER_SRC" && -f "$STATUSLINE_SRC" ]]; then
  cp "$TRACKER_SRC"    "$CLAUDE_DIR/superagent-tracker.sh"
  cp "$STATUSLINE_SRC" "$CLAUDE_DIR/superagent-statusline.sh"
  chmod +x "$CLAUDE_DIR/superagent-tracker.sh"
  chmod +x "$CLAUDE_DIR/superagent-statusline.sh"
  ok "Tracker scripts installed to ~/.claude/"
else
  warn "Hook scripts not found in $SCRIPT_DIR/hooks/ — skipping tracker install"
fi
echo ""
```

- [ ] **Step 2: Wire PostToolUse hook and statusLine in settings.json**

Add this node block immediately after the Step 10 copy block:

```bash
# ── Wire hook + statusLine in settings.json ───────────────────────────────────
if [[ -f "$CLAUDE_DIR/superagent-tracker.sh" ]]; then
  node - <<'JSEOF'
const fs = require('fs'), path = require('path');
const file = path.join(process.env.HOME, '.claude', 'settings.json');
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}

// Wire PostToolUse hook
cfg.hooks = cfg.hooks || {};
cfg.hooks.PostToolUse = cfg.hooks.PostToolUse || [];
const trackerCmd = `bash "${path.join(process.env.HOME, '.claude', 'superagent-tracker.sh')}"`;
const alreadyWired = cfg.hooks.PostToolUse.some(h =>
  h.hooks && h.hooks.some(hh => hh.command && hh.command.includes('superagent-tracker'))
);
if (!alreadyWired) {
  cfg.hooks.PostToolUse.push({
    matcher: "Bash",
    hooks: [{ type: "command", command: trackerCmd }]
  });
}

// Wire statusLine
const statusCmd = `bash "${path.join(process.env.HOME, '.claude', 'superagent-statusline.sh')}"`;
if (!cfg.statusLine || !cfg.statusLine.command || !cfg.statusLine.command.includes('superagent-statusline')) {
  cfg.statusLine = { type: "command", command: statusCmd };
}

fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
JSEOF
  ok "PostToolUse hook + statusLine wired in ~/.claude/settings.json"
fi
echo ""
```

- [ ] **Step 3: Wire calibration after graphify update (Step 9)**

In the existing Step 9 block, after the `graphify update` succeeds, add calibration:

Find this line in Step 9:
```bash
    && ok "graphify graph built (graphify-out/graph.json)" \
```

Replace with:
```bash
    && ok "graphify graph built (graphify-out/graph.json)" \
    && { bash "$CLAUDE_DIR/superagent-tracker.sh" --calibrate "$CLAUDE_DIR" 2>/dev/null || true; } \
```

- [ ] **Step 4: Update the Done banner to mention tracker**

In the final echo block, add under the installed tools list:
```bash
echo "    ✓ token-stats        — real token savings tracking (statusline + /token-stats)"
```

- [ ] **Step 5: Test install.sh dry-run**

```bash
# Verify no syntax errors
bash -n install.sh && echo "syntax OK"

# Verify settings.json would be updated correctly (check jq on existing settings)
node -e "
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync(process.env.HOME + '/.claude/settings.json', 'utf8'));
console.log('hooks.PostToolUse:', JSON.stringify(cfg.hooks?.PostToolUse, null, 2));
console.log('statusLine:', JSON.stringify(cfg.statusLine, null, 2));
"
```

Expected: `hooks.PostToolUse` contains entry with `superagent-tracker.sh`, `statusLine.command` contains `superagent-statusline.sh`.

- [ ] **Step 6: Commit**

```bash
git add install.sh
git commit -m "feat: wire token tracker in install.sh — copy scripts, hook, statusLine, calibration"
```

---

## Task 5: End-to-End Verification

- [ ] **Step 1: Run a fresh install simulation**

```bash
# Run the install (idempotent — safe to re-run)
bash install.sh 2>&1 | grep -E "(✓|✗|→|Calibration)"
```

Expected: all `✓`, including `Calibration: Nx ratio stored ✓`

- [ ] **Step 2: Verify settings.json**

```bash
cat ~/.claude/settings.json | jq '{hooks: .hooks.PostToolUse, statusLine: .statusLine}'
```

Expected:
```json
{
  "hooks": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "bash ~/.claude/superagent-tracker.sh" }] }],
  "statusLine": { "type": "command", "command": "bash ~/.claude/superagent-statusline.sh" }
}
```

- [ ] **Step 3: Simulate a graphify query and verify badge**

```bash
# Simulate PostToolUse event as Claude Code would
echo '{"tool_name":"Bash","tool_input":{"command":"graphify query \"what is the main entry point\""},"tool_response":{"output":"The main entry point is install.sh which orchestrates all plugin and tool installations."}}' \
  | bash ~/.claude/superagent-tracker.sh

# Check statusline
bash ~/.claude/superagent-statusline.sh
```

Expected badge: `[SA: <N> saved | <R>x]` with non-zero values

- [ ] **Step 4: Run /token-stats skill and verify report**

Ask Claude: `/token-stats` — confirm it prints the full table with real data from Step 3.

- [ ] **Step 5: Final commit**

```bash
git add -A
git status  # verify only intended files
git commit -m "chore: verify token savings tracker end-to-end"
```
