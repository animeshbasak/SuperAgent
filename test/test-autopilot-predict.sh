#!/usr/bin/env bash
# test/test-autopilot-predict.sh — predict reads patterns.jsonl with 0.7 confidence threshold
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-autopilot"

TMPHOME=$(mktemp -d)
TMPCWD=$(mktemp -d)
trap 'rm -rf "$TMPHOME" "$TMPCWD"' EXIT
mkdir -p "$TMPHOME/.superagent/autopilot" "$TMPHOME/.superagent/brain"

# Seed a high-confidence pattern matching "deploy kustomize"
NEW=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/brain/patterns.jsonl" <<JSONL
{"id":"p-deploy","signal":"deploy kustomize overlay","chain":["investigate","ship"],"successRate":0.85,"useCount":12,"lastUsed":"$NEW","protected":false}
{"id":"p-weak","signal":"flaky test","chain":["debug"],"successRate":0.50,"useCount":3,"lastUsed":"$NEW","protected":false}
JSONL

# Seed pending tasks
cat > "$TMPCWD/tasks.md" <<EOF
deploy kustomize overlay to staging cluster
fix flaky test in billing
EOF

OUT=$(cd "$TMPCWD" && HOME="$TMPHOME" "$BIN" predict --json)
echo "$OUT" | jq -e '.action == "execute-pattern" and .confidence >= 0.85' >/dev/null \
  || { echo "FAIL: high-conf pattern not picked: $OUT"; exit 1; }

# Remove patterns above gate → fallback path
echo '{"id":"p-weak","signal":"flaky test","chain":["debug"],"successRate":0.50,"useCount":3,"lastUsed":"'$NEW'","protected":false}' \
  > "$TMPHOME/.superagent/brain/patterns.jsonl"
OUT2=$(cd "$TMPCWD" && HOME="$TMPHOME" "$BIN" predict --json)
echo "$OUT2" | jq -e '.action == "fallback" and .target != null' >/dev/null \
  || { echo "FAIL: fallback path: $OUT2"; exit 1; }

echo "test-autopilot-predict: PASS"
