#!/usr/bin/env bash
# test/test-autopilot-budget-gate.sh — iter pauses when auto-downgrade.flag present
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-autopilot"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/autopilot" "$TMPHOME/.superagent/brain"

# Drop the auto-downgrade.flag — autopilot iter must pause
echo "sonnet" > "$TMPHOME/.superagent/auto-downgrade.flag"
OUT=$(HOME="$TMPHOME" "$BIN" iter)
echo "$OUT" | jq -e '.paused == true and .reason == "budget"' >/dev/null \
  || { echo "FAIL: budget gate did not pause: $OUT"; exit 1; }

# Remove flag and enable → iter runs (emits ScheduleWakeup directive)
rm "$TMPHOME/.superagent/auto-downgrade.flag"
HOME="$TMPHOME" "$BIN" enable >/dev/null
OUT2=$(HOME="$TMPHOME" "$BIN" iter)
echo "$OUT2" | jq -e '.paused == false and .directive == "ScheduleWakeup" and .delaySeconds == 270' >/dev/null \
  || { echo "FAIL: iter did not emit wakeup directive: $OUT2"; exit 1; }

# Disabled state pauses with reason:disabled
HOME="$TMPHOME" "$BIN" disable >/dev/null
OUT3=$(HOME="$TMPHOME" "$BIN" iter)
echo "$OUT3" | jq -e '.paused == true and .reason == "disabled"' >/dev/null \
  || { echo "FAIL: disabled state did not pause: $OUT3"; exit 1; }

echo "test-autopilot-budget-gate: PASS"
