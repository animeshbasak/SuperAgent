#!/usr/bin/env bash
# test/test-patterns-protect-prune.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATBIN="$SCRIPT_DIR/../bin/superagent-patterns"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/brain"
NEW=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/brain/patterns.jsonl" <<JSONL
{"id":"p-1111","signal":"a","chain":["x"],"successRate":0.45,"useCount":4,"lastUsed":"$NEW","protected":false}
{"id":"p-2222","signal":"b","chain":["y"],"successRate":0.20,"useCount":2,"lastUsed":"$NEW","protected":false}
JSONL

HOME="$TMPHOME" "$PATBIN" protect p-1111 >/dev/null
PROT=$(grep '"p-1111"' "$TMPHOME/.superagent/brain/patterns.jsonl" | jq -r '.protected')
[[ "$PROT" == "true" ]] || { echo "FAIL: protect did not flip protected:true (got $PROT)"; exit 1; }

HOME="$TMPHOME" "$PATBIN" prune --below 0.5 >/dev/null
LINES=$(wc -l < "$TMPHOME/.superagent/brain/patterns.jsonl" | tr -d ' ')
[[ "$LINES" == "1" ]] || { echo "FAIL: prune kept $LINES lines, want 1"; cat "$TMPHOME/.superagent/brain/patterns.jsonl"; exit 1; }
grep -q '"p-1111"' "$TMPHOME/.superagent/brain/patterns.jsonl" || { echo "FAIL: protected p-1111 was pruned"; exit 1; }

HOME="$TMPHOME" "$PATBIN" protect p-zzzz 2>/dev/null && { echo "FAIL: bogus protect should exit !=0"; exit 1; } || true

echo "test-patterns-protect-prune: PASS"
