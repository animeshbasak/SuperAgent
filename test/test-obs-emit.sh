#!/usr/bin/env bash
# test/test-obs-emit.sh — bin/superagent-obs emits canonical span + metric records
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-obs"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/obs"

HOME="$TMPHOME" "$BIN" span --op test-op --trace t-aaaa --span s-bbbb --start 0 --end 100 --status OK --attrs '{"chain_len":3}'
HOME="$TMPHOME" "$BIN" metric --name agent_task_duration_seconds --kind histogram --value 1.23 --labels '{"task_type":"build"}'

LAST_S=$(tail -n1 "$TMPHOME/.superagent/obs/spans.jsonl")
echo "$LAST_S" | jq -e '.op == "test-op" and .traceId == "t-aaaa" and .parentSpanId == null and .attrs.chain_len == 3' >/dev/null \
  || { echo "FAIL: span record: $LAST_S"; exit 1; }

LAST_M=$(tail -n1 "$TMPHOME/.superagent/obs/metrics.jsonl")
echo "$LAST_M" | jq -e '.name == "agent_task_duration_seconds" and .kind == "histogram" and .value == 1.23 and .labels.task_type == "build"' >/dev/null \
  || { echo "FAIL: metric record: $LAST_M"; exit 1; }

# Span with parent
HOME="$TMPHOME" "$BIN" span --op child --trace t-aaaa --span s-cccc --parent s-bbbb --start 10 --end 90 --status OK
CHILD=$(tail -n1 "$TMPHOME/.superagent/obs/spans.jsonl")
echo "$CHILD" | jq -e '.parentSpanId == "s-bbbb"' >/dev/null \
  || { echo "FAIL: child span parentSpanId: $CHILD"; exit 1; }

echo "test-obs-emit: PASS"
