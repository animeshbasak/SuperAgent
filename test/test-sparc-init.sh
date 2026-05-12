#!/usr/bin/env bash
# test/test-sparc-init.sh — init scaffolds dir + state.json; idempotent
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-sparc"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT

HOME="$TMPHOME" "$BIN" init feat-darkmode >/dev/null

DIR="$TMPHOME/.superagent/sparc/feat-darkmode"
[[ -d "$DIR" ]] || { echo "FAIL: $DIR missing"; exit 1; }
[[ -f "$DIR/state.json" ]] || { echo "FAIL: state.json missing"; exit 1; }

STATE=$(cat "$DIR/state.json")
echo "$STATE" | jq -e '.slug == "feat-darkmode" and .phase == 1 and .gate_status == "open"' >/dev/null \
  || { echo "FAIL: state shape: $STATE"; exit 1; }

# Idempotency: existing artifacts preserved
echo "preserve me" > "$DIR/spec.md"
HOME="$TMPHOME" "$BIN" init feat-darkmode >/dev/null
[[ "$(cat "$DIR/spec.md")" == "preserve me" ]] \
  || { echo "FAIL: init clobbered existing artifact"; exit 1; }

echo "test-sparc-init: PASS"
