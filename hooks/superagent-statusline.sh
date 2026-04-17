#!/usr/bin/env bash
# superagent-statusline.sh — Claude Code statusLine badge
# Reads ~/.claude/superagent-stats.json for current project, formats badge.
# Must be fast (<10ms) — runs on every statusline refresh.

STATS="$HOME/.claude/superagent-stats.json"

# Dependency check
command -v jq >/dev/null 2>&1 || { echo "[SA: install jq]"; exit 0; }

# Stats file must exist
[[ -f "$STATS" ]] || { echo "[SA: not calibrated]"; exit 0; }

PROJECT="$PWD"
PROJECT_DATA=$(jq --arg p "$PROJECT" '.projects[$p] // empty' "$STATS" 2>/dev/null)

# Project not tracked yet
[[ -z "$PROJECT_DATA" ]] && { echo "[SA: run graphify update]"; exit 0; }

RATIO=$(echo "$PROJECT_DATA" | jq -r '.compression_ratio // 0')
TOTAL=$(echo "$PROJECT_DATA" | jq -r '.lifetime.total_saved // 0')
MEM_SAVED=$(echo "$PROJECT_DATA" | jq -r '.lifetime.mempalace_tokens_saved // 0')

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

# Prefix ~ only when mempalace contributed (estimated savings)
PREFIX=""
[[ "$MEM_SAVED" -gt 0 ]] && PREFIX="~"

echo "[SA: ${PREFIX}${DISPLAY} saved | ${RATIO}x]"
