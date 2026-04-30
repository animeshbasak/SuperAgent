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
  trap 'rm -f "$TMP"' EXIT
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

# Care about Bash + Read/Edit/Write/Grep/Glob (cost-meter widening, Phase C v2.2)
case "$TOOL_NAME" in
  Bash|Read|Edit|Write|Grep|Glob) ;;
  *) exit 0 ;;
esac

COMMAND=$(echo "$PAYLOAD"  | jq -r '.tool_input.command // ""'    2>/dev/null)
RESPONSE=$(echo "$PAYLOAD" | jq -r '.tool_response.output // ""'  2>/dev/null)

# Detect which superagent tool was used (Bash branch only — preserves existing logic)
TOOL_TYPE=""
if [[ "$TOOL_NAME" == "Bash" ]]; then
  echo "$COMMAND" | grep -q "graphify"   && TOOL_TYPE="graphify"
  echo "$COMMAND" | grep -q "mempalace"  && TOOL_TYPE="mempalace"
fi

# Non-Bash tools: estimate tokens from response size, log to cost ledger,
# then exit before the graphify/mempalace stats accounting (which is Bash-only).
if [[ "$TOOL_NAME" != "Bash" ]]; then
  RESP_BYTES=$(echo "$PAYLOAD" | jq -r '(.tool_response | tostring) | length' 2>/dev/null || echo 0)
  # ~4 chars per token rough estimate
  SYN_TOKENS=$(( ${RESP_BYTES:-0} / 4 ))
  COST_FILE="$HOME/.superagent/cost/calls.jsonl"
  mkdir -p "$(dirname "$COST_FILE")" 2>/dev/null || true
  {
    printf '%s' "{"
    printf '"ts":"%s",' "$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)"
    printf '"project":"%s",' "${PWD:-unknown}"
    printf '"tool":"%s",' "$TOOL_NAME"
    printf '"tokens":%s,' "${SYN_TOKENS:-0}"
    printf '"model":"%s"' "${CLAUDE_MODEL:-unknown}"
    printf '}\n'
  } >> "$COST_FILE" 2>/dev/null || true
  exit 0
fi

[[ -z "$TOOL_TYPE" ]] && exit 0

init_stats

# Recover from corrupt JSON
if ! jq empty "$STATS" 2>/dev/null; then
  log "corrupt stats JSON — backing up and reinitializing"
  cp "$STATS" "${STATS}.bak" 2>/dev/null || true
  echo '{"version":1,"projects":{}}' > "$STATS"
fi

# Dedup — skip if we already recorded this command today
TODAY=$(date '+%Y-%m-%d')
HASH=$(printf '%s%s' "$TODAY" "$COMMAND" | (shasum -a 256 2>/dev/null || sha256sum 2>/dev/null) | cut -c1-12)
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
  if [[ -z "$RATIO" ]] || (( $(echo "$RATIO <= 1" | bc 2>/dev/null || echo 1) )); then
    SAVED=0
  else
    SAVED=$(echo "scale=0; $RESPONSE_TOKENS * ($RATIO - 1) / 1" | bc 2>/dev/null || echo 0)
  fi
else
  # mempalace: conservative 20x baseline, labeled ~estimate in display
  SAVED=$(echo "scale=0; $RESPONSE_TOKENS * 19 / 1" | bc 2>/dev/null || echo 0)
fi

# Atomic write
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
jq --arg project  "$PROJECT" \
   --arg tool     "$TOOL_TYPE" \
   --argjson saved "$SAVED" \
   --arg date     "$TODAY" \
   --arg hash     "$HASH" \
   '
   .projects[$project] //= {
     "compression_ratio": 0,
     "calibrated_at": null,
     "corpus_tokens": 0,
     "lifetime": {"graphify_queries":0,"graphify_tokens_saved":0,"mempalace_hits":0,"mempalace_tokens_saved":0,"total_saved":0},
     "sessions": [],
     "seen_tool_use_ids": []
   } |
   (if $tool == "graphify" then
     .projects[$project].lifetime.graphify_queries += 1 |
     .projects[$project].lifetime.graphify_tokens_saved += $saved
   else
     .projects[$project].lifetime.mempalace_hits += 1 |
     .projects[$project].lifetime.mempalace_tokens_saved += $saved
   end) |
   .projects[$project].lifetime.total_saved += $saved |
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
   .projects[$project].sessions = .projects[$project].sessions[:30] |
   .projects[$project].seen_tool_use_ids =
     ([$hash] + (.projects[$project].seen_tool_use_ids // []))[:100]
   ' \
   "$STATS" > "$TMP" 2>>"$LOG" && mv "$TMP" "$STATS" \
   || log "jq update failed for $TOOL_TYPE in $PROJECT"

# Per-call cost log (Task 5.3)
COST_FILE="$HOME/.superagent/cost/calls.jsonl"
mkdir -p "$(dirname "$COST_FILE")" 2>/dev/null || true
{
  printf '%s' "{"
  printf '"ts":"%s",' "$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)"
  printf '"project":"%s",' "${PROJECT:-unknown}"
  printf '"tool":"%s",' "${TOOL_TYPE:-unknown}"
  printf '"tokens":%s,' "${RESPONSE_TOKENS:-0}"
  printf '"model":"%s"' "${CLAUDE_MODEL:-unknown}"
  printf '}\n'
} >> "$COST_FILE" 2>/dev/null || true

exit 0
