#!/usr/bin/env bash
# test/test-cost-v2.sh — schema v2 pricing + v1 backcompat
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COST_BIN="$SCRIPT_DIR/../bin/superagent-cost"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/cost"

# Mixed v1 + v2 records
cat > "$TMPHOME/.superagent/cost/calls.jsonl" <<JSONL
{"ts":"$(date -u -v+0H -Iseconds 2>/dev/null || date -u -Iseconds)","project":"/x","tool":"Bash","tokens":500000,"model":"sonnet"}
{"ts":"$(date -u -v+0H -Iseconds 2>/dev/null || date -u -Iseconds)","project":"/x","tool":"Bash","model":"sonnet","input_tokens":100000,"output_tokens":400000,"cache_write_tokens":0,"cache_read_tokens":0,"task_id":"t-test","http_status":200,"pricing_version":"2026-Q2"}
JSONL

# Default budget so script doesn't 404
cat > "$TMPHOME/.superagent/cost/budget.json" <<'JSON'
{"daily_usd":20,"monthly_usd":400,"alert_thresholds":[0.5,0.75,0.9,1.0],
 "auto_downgrade":{"at":0.9,"target":"sonnet"},"hard_stop":{"at":1.0,"mode":"prompt"}}
JSON

OUT=$(HOME="$TMPHOME" "$COST_BIN" today --json)
echo "$OUT" | jq . >/dev/null || { echo "FAIL: invalid JSON"; exit 1; }

# Both records should be summed; sonnet pricing under v2 = (100000*3 + 400000*15)/1M = 6.30
# v1 record: 500000 tokens treated as output_tokens only = 500000*15/1M = 7.50
# total = 6.30 + 7.50 = 13.80
TOTAL=$(echo "$OUT" | jq '.total_usd')
PASS=$(python3 -c "print(abs($TOTAL - 13.80) < 0.01)")
[[ "$PASS" == "True" ]] || { echo "FAIL: expected total~13.80, got $TOTAL"; exit 1; }

echo "test-cost-v2: PASS"
