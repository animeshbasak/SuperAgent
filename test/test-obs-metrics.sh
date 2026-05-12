#!/usr/bin/env bash
# test/test-obs-metrics.sh — counter SUM, gauge LAST, histogram p50/p95/p99
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-metrics"
EMIT="$SCRIPT_DIR/../bin/superagent-obs"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/obs"

# Counter: 3 increments
for v in 1 2 3; do
  HOME="$TMPHOME" "$EMIT" metric --name agent_error_rate --kind counter --value "$v" --labels '{}'
done
# Gauge: final value should win
HOME="$TMPHOME" "$EMIT" metric --name agent_active_count --kind gauge --value 5 --labels '{}'
HOME="$TMPHOME" "$EMIT" metric --name agent_active_count --kind gauge --value 8 --labels '{}'
# Histogram: 10 samples
for v in 0.1 0.2 0.3 0.4 0.5 1 2 5 10 30; do
  HOME="$TMPHOME" "$EMIT" metric --name agent_task_duration_seconds --kind histogram --value "$v" --labels '{}'
done

OUT=$(HOME="$TMPHOME" "$BIN" today --json)

echo "$OUT" | jq -e '.metrics.agent_error_rate.sum == 6 and .metrics.agent_error_rate.count == 3' >/dev/null \
  || { echo "FAIL: counter sum: $OUT"; exit 1; }
echo "$OUT" | jq -e '.metrics.agent_active_count.last == 8' >/dev/null \
  || { echo "FAIL: gauge last: $OUT"; exit 1; }
echo "$OUT" | jq -e '.metrics.agent_task_duration_seconds.kind == "histogram" and .metrics.agent_task_duration_seconds.p95 >= 10' >/dev/null \
  || { echo "FAIL: histogram p95: $OUT"; exit 1; }

echo "test-obs-metrics: PASS"
