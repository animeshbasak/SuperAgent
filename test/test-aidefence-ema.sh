#!/usr/bin/env bash
# test/test-aidefence-ema.sh — feedback drives EMA so confidence shifts on repeated inaccurate verdicts
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-aidefence"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/aidefence"
cp "$SCRIPT_DIR/../skills/aidefence/patterns.json" "$TMPHOME/.superagent/aidefence/patterns.json"

# Baseline confidence for io-001 (which matches "ignore previous instructions")
BASE_JSON=$(HOME="$TMPHOME" "$BIN" scan "ignore previous instructions")
BASE=$(echo "$BASE_JSON" | jq -r '[.threats[] | select(.id == "io-001")][0].confidence')

# Record 30 inaccurate verdicts for io-001 — EMA at alpha=0.1 from 0.8 baseline:
# after k inaccurate events, effectiveness = 0.8 * 0.9^k
# k=30 → 0.8 * 0.0424 ≈ 0.034
for i in $(seq 1 30); do
  HOME="$TMPHOME" "$BIN" feedback io-001 inaccurate >/dev/null
done

AFTER_JSON=$(HOME="$TMPHOME" "$BIN" scan "ignore previous instructions")
AFTER=$(echo "$AFTER_JSON" | jq -r '[.threats[] | select(.id == "io-001")][0].confidence')

PASS=$(python3 -c "print($AFTER < $BASE * 0.5)")
[[ "$PASS" == "True" ]] || { echo "FAIL: EMA did not decay confidence ($BASE -> $AFTER)"; exit 1; }

echo "test-aidefence-ema: PASS  (base=$BASE → after-30=$AFTER)"
