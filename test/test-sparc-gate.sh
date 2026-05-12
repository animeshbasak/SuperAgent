#!/usr/bin/env bash
# test/test-sparc-gate.sh — per-phase boolean gate
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-sparc"
FIXTURES="$SCRIPT_DIR/fixtures/sparc"

run_gate() {
  local slug="$1"      # name to use under ~/.superagent/sparc
  local fixture="$2"   # fixture dir to seed
  local phase="$3"     # phase to test
  local expect="$4"    # passed|failed

  local TMPHOME
  TMPHOME=$(mktemp -d)
  trap "rm -rf '$TMPHOME'" RETURN

  HOME="$TMPHOME" "$BIN" init "$slug" >/dev/null
  DIR="$TMPHOME/.superagent/sparc/$slug"
  cp "$fixture"/*.md "$DIR/"
  # Force the desired phase
  jq --argjson p "$phase" '.phase = $p' "$DIR/state.json" > "$DIR/state.json.tmp" && mv "$DIR/state.json.tmp" "$DIR/state.json"

  HOME="$TMPHOME" "$BIN" gate >/dev/null 2>&1 || true
  GOT=$(jq -r '.gate_status' "$DIR/state.json")

  if [[ "$GOT" != "$expect" ]]; then
    echo "FAIL: $slug phase $phase: expected gate_status=$expect, got $GOT"
    rm -rf "$TMPHOME"
    exit 1
  fi
}

run_gate test-p1-pass "$FIXTURES/phase1-pass" 1 passed
run_gate test-p1-fail "$FIXTURES/phase1-fail" 1 failed
run_gate test-p3-pass "$FIXTURES/phase3-pass" 3 passed
run_gate test-p3-fail "$FIXTURES/phase3-fail" 3 failed

echo "test-sparc-gate: PASS"
