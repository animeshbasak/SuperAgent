#!/usr/bin/env bash
# test/test-cost-alerts.sh — alerts emit at threshold crossings; flag drops at 0.9
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALERTS_BIN="$SCRIPT_DIR/../bin/superagent-cost-alerts"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/cost"

cat > "$TMPHOME/.superagent/cost/budget.json" <<'JSON'
{"daily_usd":20,"monthly_usd":400,"alert_thresholds":[0.5,0.75,0.9,1.0],
 "auto_downgrade":{"at":0.9,"target":"sonnet"},"hard_stop":{"at":1.0,"mode":"prompt"}}
JSON

TS=$(date -u -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/cost/calls.jsonl" <<JSONL
{"ts":"$TS","project":"/x","tool":"Bash","model":"sonnet","input_tokens":0,"output_tokens":1280000,"cache_write_tokens":0,"cache_read_tokens":0,"task_id":"t","http_status":200,"pricing_version":"2026-Q2"}
JSONL

HOME="$TMPHOME" PATH="$SCRIPT_DIR/../bin:$PATH" "$ALERTS_BIN" >/dev/null

LATEST=$(tail -n1 "$TMPHOME/.superagent/cost/alerts.jsonl")
echo "$LATEST" | jq -e '.level == "critical" and .pct >= 0.9' >/dev/null \
  || { echo "FAIL: critical alert not emitted: $LATEST"; exit 1; }

[[ -f "$TMPHOME/.superagent/auto-downgrade.flag" ]] || { echo "FAIL: auto-downgrade.flag missing"; exit 1; }
grep -q "sonnet" "$TMPHOME/.superagent/auto-downgrade.flag" || { echo "FAIL: flag missing target"; exit 1; }

HOME="$TMPHOME" PATH="$SCRIPT_DIR/../bin:$PATH" "$ALERTS_BIN" >/dev/null
COUNT=$(grep -c '"level":"critical"' "$TMPHOME/.superagent/cost/alerts.jsonl" || echo 0)
[[ "$COUNT" -eq 1 ]] || { echo "FAIL: critical alert duplicated (count=$COUNT)"; exit 1; }

echo "test-cost-alerts: PASS"
