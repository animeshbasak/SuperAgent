#!/usr/bin/env bash
# test/test-sparc-advance.sh — advance refuses without passed gate; resets gate after bump
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-sparc"
FIXTURES="$SCRIPT_DIR/fixtures/sparc"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT

HOME="$TMPHOME" "$BIN" init feat-x >/dev/null
DIR="$TMPHOME/.superagent/sparc/feat-x"
cp "$FIXTURES/phase1-pass/spec.md" "$DIR/"

# Without running gate, advance must refuse
HOME="$TMPHOME" "$BIN" advance >/dev/null 2>&1 && { echo "FAIL: advance without gate should fail"; exit 1; } || true

# Run gate (passes for phase 1) then advance succeeds
HOME="$TMPHOME" "$BIN" gate >/dev/null
HOME="$TMPHOME" "$BIN" advance >/dev/null

PHASE=$(jq -r '.phase' "$DIR/state.json")
[[ "$PHASE" == "2" ]] || { echo "FAIL: phase did not bump to 2 (got $PHASE)"; exit 1; }

GATE=$(jq -r '.gate_status' "$DIR/state.json")
[[ "$GATE" == "open" ]] || { echo "FAIL: gate not reset to open after advance (got $GATE)"; exit 1; }

# Advance refuses again because new phase has open gate
HOME="$TMPHOME" "$BIN" advance >/dev/null 2>&1 && { echo "FAIL: advance without re-passing gate should fail"; exit 1; } || true

echo "test-sparc-advance: PASS"
