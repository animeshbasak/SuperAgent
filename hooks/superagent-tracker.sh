#!/usr/bin/env bash
# superagent-tracker.sh — PostToolUse hook + calibration
# Hook mode: called by Claude Code with JSON payload via stdin
# Calibration mode: called with --calibrate <project_dir>

set -euo pipefail

STATS="$HOME/.claude/superagent-stats.json"
LOG="$HOME/.claude/superagent-tracker.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG" 2>/dev/null || true; }

# Extract 4-dim usage from tool_response.usage; fall back to v1 estimate.
emit_cost_record() {
  local payload="$1"
  local tool_name="$2"
  local project="$3"
  local fallback_estimate="$4"

  local usage in_t out_t cw_t cr_t
  usage=$(echo "$payload" | jq -c '.tool_response.usage // null' 2>/dev/null || echo "null")

  if [[ "$usage" != "null" && -n "$usage" ]]; then
    in_t=$(echo "$usage" | jq -r '.input_tokens // 0')
    out_t=$(echo "$usage" | jq -r '.output_tokens // 0')
    cw_t=$(echo "$usage" | jq -r '.cache_creation_input_tokens // 0')
    cr_t=$(echo "$usage" | jq -r '.cache_read_input_tokens // 0')
  else
    in_t=0
    out_t="${fallback_estimate:-0}"
    cw_t=0
    cr_t=0
  fi

  local task_id
  task_id="${SA_TRACE_ID:-}"
  if [[ -z "$task_id" ]]; then
    task_id=$(printf '%s%s' "$(date +%s%N 2>/dev/null || date +%s)" "$tool_name" \
      | (shasum -a 256 2>/dev/null || sha256sum 2>/dev/null) | cut -c1-8)
  fi

  local cost_file="$HOME/.superagent/cost/calls.jsonl"
  mkdir -p "$(dirname "$cost_file")" 2>/dev/null || true
  {
    printf '%s' "{"
    printf '"ts":"%s",' "$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)"
    printf '"project":"%s",' "${project:-unknown}"
    printf '"tool":"%s",' "$tool_name"
    printf '"model":"%s",' "${CLAUDE_MODEL:-unknown}"
    printf '"input_tokens":%s,' "${in_t:-0}"
    printf '"output_tokens":%s,' "${out_t:-0}"
    printf '"cache_write_tokens":%s,' "${cw_t:-0}"
    printf '"cache_read_tokens":%s,' "${cr_t:-0}"
    printf '"task_id":"%s",' "$task_id"
    printf '"http_status":200,'
    printf '"pricing_version":"2026-Q2"'
    printf '}\n'
  } >> "$cost_file" 2>/dev/null || true
}

# Wave 2: emit span + token-usage metric via bin/superagent-obs (best effort).
emit_obs_records() {
  local payload="$1"
  local tool_name="$2"

  local obs_bin
  obs_bin="$(command -v superagent-obs 2>/dev/null || true)"
  if [[ -z "$obs_bin" ]]; then
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -x "$script_dir/../bin/superagent-obs" ]]; then
      obs_bin="$script_dir/../bin/superagent-obs"
    fi
  fi
  [[ -z "$obs_bin" ]] && return 0

  local trace_id="${SA_TRACE_ID:-}"
  if [[ -z "$trace_id" ]]; then
    trace_id="t-$(printf '%s%s' "$(date +%s%N 2>/dev/null || date +%s)" "$tool_name" \
      | (shasum -a 256 2>/dev/null || sha256sum 2>/dev/null) | cut -c1-8)"
  fi
  local span_id
  span_id="s-$(printf '%s%s%s' "$(date +%s%N 2>/dev/null || date +%s)" "$tool_name" "$$" \
    | (shasum -a 256 2>/dev/null || sha256sum 2>/dev/null) | cut -c1-8)"

  local end_ms start_ms
  end_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
  start_ms=$((end_ms - 1))

  if [[ -n "${SA_PARENT_SPAN:-}" ]]; then
    "$obs_bin" span \
      --trace "$trace_id" --span "$span_id" --parent "$SA_PARENT_SPAN" \
      --op "tool.$tool_name" --start "$start_ms" --end "$end_ms" --status OK \
      --attrs "{\"tool\":\"$tool_name\"}" 2>/dev/null || true
  else
    "$obs_bin" span \
      --trace "$trace_id" --span "$span_id" \
      --op "tool.$tool_name" --start "$start_ms" --end "$end_ms" --status OK \
      --attrs "{\"tool\":\"$tool_name\"}" 2>/dev/null || true
  fi

  local total_tok
  total_tok=$(jq -r '
    (.tool_response.usage.input_tokens // 0) +
    (.tool_response.usage.output_tokens // 0) +
    (.tool_response.usage.cache_creation_input_tokens // 0) +
    (.tool_response.usage.cache_read_input_tokens // 0)' \
    <<<"$payload" 2>/dev/null || echo 0)
  [[ -z "$total_tok" ]] && total_tok=0

  "$obs_bin" metric \
    --name agent_token_usage --kind histogram \
    --value "$total_tok" \
    --labels "{\"tool\":\"$tool_name\",\"model\":\"${CLAUDE_MODEL:-unknown}\"}" 2>/dev/null || true
}

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

# Non-Bash tools: emit v2 cost record (uses real usage if Claude provided it,
# else falls back to response-size estimate as output_tokens).
if [[ "$TOOL_NAME" != "Bash" ]]; then
  RESP_BYTES=$(echo "$PAYLOAD" | jq -r '(.tool_response | tostring) | length' 2>/dev/null || echo 0)
  SYN_TOKENS=$(( ${RESP_BYTES:-0} / 4 ))
  emit_cost_record "$PAYLOAD" "$TOOL_NAME" "${PWD:-unknown}" "$SYN_TOKENS"
  emit_obs_records "$PAYLOAD" "$TOOL_NAME"
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

# Per-call cost log (Wave 1 v2 schema)
emit_cost_record "$PAYLOAD" "$TOOL_NAME" "${PROJECT:-unknown}" "${RESPONSE_TOKENS:-0}"
emit_obs_records "$PAYLOAD" "$TOOL_NAME"

exit 0
