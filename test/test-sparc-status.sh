#!/usr/bin/env bash
# test/test-sparc-status.sh — status prints phase, gate, last failure, artifacts
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-sparc"
FIXTURES="$SCRIPT_DIR/fixtures/sparc"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT

HOME="$TMPHOME" "$BIN" init feat-st >/dev/null
DIR="$TMPHOME/.superagent/sparc/feat-st"
cp "$FIXTURES/phase1-fail/spec.md" "$DIR/"
HOME="$TMPHOME" "$BIN" gate >/dev/null 2>&1 || true

# Human-readable status
OUT=$(HOME="$TMPHOME" "$BIN" status)
echo "$OUT" | grep -q "phase: 1" || { echo "FAIL: phase missing: $OUT"; exit 1; }
echo "$OUT" | grep -q "gate_status: failed" || { echo "FAIL: gate_status missing"; exit 1; }
echo "$OUT" | grep -q "last failure" || { echo "FAIL: last failure missing"; exit 1; }

# JSON mode
OUT_JSON=$(HOME="$TMPHOME" "$BIN" status --json)
echo "$OUT_JSON" | jq -e '.phase == 1 and .gate_status == "failed"' >/dev/null \
  || { echo "FAIL: --json shape: $OUT_JSON"; exit 1; }

echo "test-sparc-status: PASS"
