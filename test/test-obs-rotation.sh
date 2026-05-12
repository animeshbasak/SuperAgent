#!/usr/bin/env bash
# test/test-obs-rotation.sh — rotation creates dated file pair + idempotent
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-obs-rotate"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/obs"

# Seed both files
echo '{"traceId":"t","spanId":"s","op":"x","startMs":0,"endMs":1,"status":"OK","attrs":{}}' > "$TMPHOME/.superagent/obs/spans.jsonl"
echo '{"ts":"2026-01-01T00:00:00+00:00","name":"x","kind":"counter","value":1,"labels":{}}' > "$TMPHOME/.superagent/obs/metrics.jsonl"

HOME="$TMPHOME" "$BIN"

TODAY=$(date +%Y%m%d)
[[ -f "$TMPHOME/.superagent/obs/spans.$TODAY.jsonl" ]] \
  || { echo "FAIL: spans rotation missing"; exit 1; }
[[ -f "$TMPHOME/.superagent/obs/metrics.$TODAY.jsonl" ]] \
  || { echo "FAIL: metrics rotation missing"; exit 1; }
[[ ! -s "$TMPHOME/.superagent/obs/spans.jsonl" ]] \
  || { echo "FAIL: spans.jsonl not truncated"; exit 1; }
[[ -f "$TMPHOME/.superagent/obs/.last-rotate-$TODAY" ]] \
  || { echo "FAIL: today marker missing"; exit 1; }

# Idempotent: re-run should NOT create more dated files
echo '{"traceId":"t","spanId":"s2","op":"x","startMs":0,"endMs":1,"status":"OK","attrs":{}}' > "$TMPHOME/.superagent/obs/spans.jsonl"
HOME="$TMPHOME" "$BIN"
COUNT=$(ls "$TMPHOME/.superagent/obs/" | grep -c "spans\." || echo 0)
# Should be: spans.jsonl + spans.<TODAY>.jsonl = 2 entries
[[ "$COUNT" -eq 2 ]] || { echo "FAIL: rotation duplicated (count=$COUNT)"; ls "$TMPHOME/.superagent/obs/"; exit 1; }

echo "test-obs-rotation: PASS"
