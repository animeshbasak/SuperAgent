#!/usr/bin/env bash
# test/test-classify-patterns.sh — classifier prepends pattern chain when gate met
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CBIN="$SCRIPT_DIR/../bin/superagent-classify"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/brain"

NEW=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/brain/patterns.jsonl" <<JSONL
{"id":"p-good","signal":"deploy kustomize overlay","chain":["pattern-from-store"],"successRate":0.85,"useCount":12,"lastUsed":"$NEW","protected":false}
{"id":"p-weak","signal":"floof bloop","chain":["should-not-fire"],"successRate":0.50,"useCount":3,"lastUsed":"$NEW","protected":false}
JSONL

OUT1=$(HOME="$TMPHOME" "$CBIN" "deploy kustomize overlay to staging")
echo "$OUT1" | jq -e '.chain | index("pattern-from-store") != null' >/dev/null \
  || { echo "FAIL: high-quality pattern not applied: $OUT1"; exit 1; }

OUT2=$(HOME="$TMPHOME" "$CBIN" "floof bloop")
echo "$OUT2" | jq -e '.chain | index("should-not-fire") == null' >/dev/null \
  || { echo "FAIL: weak pattern incorrectly applied: $OUT2"; exit 1; }

echo "test-classify-patterns: PASS"
