#!/usr/bin/env bash
# test/test-patterns-decay.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATBIN="$SCRIPT_DIR/../bin/superagent-patterns"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/brain"

OLD=$(python3 -c "import datetime; print((datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=24)).isoformat())")
NEW=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

cat > "$TMPHOME/.superagent/brain/patterns.jsonl" <<JSONL
{"id":"p-aaaa","kind":"task-routing","signal":"x y","chain":["a","b"],"successRate":0.80,"useCount":10,"lastUsed":"$OLD","protected":false}
{"id":"p-bbbb","kind":"task-routing","signal":"y z","chain":["c"],"successRate":0.05,"useCount":3,"lastUsed":"$NEW","protected":false}
{"id":"p-cccc","kind":"task-routing","signal":"q r","chain":["d"],"successRate":0.05,"useCount":3,"lastUsed":"$NEW","protected":true}
JSONL

HOME="$TMPHOME" "$PATBIN" decay >/dev/null

PA=$(grep '"p-aaaa"' "$TMPHOME/.superagent/brain/patterns.jsonl" | jq -r '.successRate')
PASS=$(python3 -c "print(0.69 < $PA < 0.73)")
[[ "$PASS" == "True" ]] || { echo "FAIL: p-aaaa successRate=$PA out of range (0.69, 0.73)"; exit 1; }

grep -q '"p-bbbb"' "$TMPHOME/.superagent/brain/patterns.jsonl" \
  && { echo "FAIL: p-bbbb should have been pruned"; exit 1; } || true

PC=$(grep '"p-cccc"' "$TMPHOME/.superagent/brain/patterns.jsonl" | jq -r '.successRate')
PASS_C=$(python3 -c "print($PC >= 0.30 - 0.001)")
[[ "$PASS_C" == "True" ]] || { echo "FAIL: p-cccc not floored at 0.3 (got $PC)"; exit 1; }

echo "test-patterns-decay: PASS"
