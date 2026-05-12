#!/usr/bin/env bash
# test/test-autopilot-state.sh — bounded config, history cap 50, task discovery
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-autopilot"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/autopilot" "$TMPHOME/.superagent/brain"

OUT=$(HOME="$TMPHOME" "$BIN" status)
echo "$OUT" | grep -q 'enabled: false' || { echo "FAIL: default not disabled"; exit 1; }

HOME="$TMPHOME" "$BIN" enable >/dev/null

HOME="$TMPHOME" "$BIN" config --max-iterations 9999 >/dev/null
MAX=$(HOME="$TMPHOME" "$BIN" status --json | jq '.maxIterations')
[[ "$MAX" == "1000" ]] || { echo "FAIL: maxIterations not clamped to 1000 (got $MAX)"; exit 1; }

HOME="$TMPHOME" "$BIN" config --timeout-minutes 999999 >/dev/null
TMO=$(HOME="$TMPHOME" "$BIN" status --json | jq '.timeoutMinutes')
[[ "$TMO" == "1440" ]] || { echo "FAIL: timeoutMinutes not clamped to 1440 (got $TMO)"; exit 1; }

# Spam 60 _record-iter, expect history capped at 50
for i in $(seq 1 60); do
  HOME="$TMPHOME" "$BIN" _record-iter --completed 1 --total 10 >/dev/null
done
LEN=$(HOME="$TMPHOME" "$BIN" status --json | jq '.history | length')
[[ "$LEN" -le 50 ]] || { echo "FAIL: history length $LEN > 50"; exit 1; }

# Task discovery: markdown checkbox in cwd
TMPCWD=$(mktemp -d)
trap 'rm -rf "$TMPHOME" "$TMPCWD"' EXIT
echo "- [ ] do the thing" > "$TMPCWD/notes.md"
PENDING=$(cd "$TMPCWD" && HOME="$TMPHOME" "$BIN" tasks --json | jq '.count')
[[ "$PENDING" -ge 1 ]] || { echo "FAIL: no pending tasks found (got $PENDING)"; exit 1; }

echo "test-autopilot-state: PASS"
