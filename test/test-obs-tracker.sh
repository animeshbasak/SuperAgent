#!/usr/bin/env bash
# test/test-obs-tracker.sh — tracker.sh emits span + token-usage metric on tool calls
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKER="$SCRIPT_DIR/../hooks/superagent-tracker.sh"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/cost" "$TMPHOME/.superagent/obs" "$TMPHOME/.claude"

PAYLOAD='{
  "tool_name":"Read",
  "tool_input":{"file_path":"/x"},
  "tool_response":{
    "output":"abc",
    "usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}
  }
}'

HOME="$TMPHOME" PATH="$SCRIPT_DIR/../bin:$PATH" CLAUDE_MODEL="claude-sonnet-4-5" \
  bash "$TRACKER" <<<"$PAYLOAD" || true

[[ -s "$TMPHOME/.superagent/obs/spans.jsonl" ]] \
  || { echo "FAIL: no span emitted"; exit 1; }
[[ -s "$TMPHOME/.superagent/obs/metrics.jsonl" ]] \
  || { echo "FAIL: no metric emitted"; exit 1; }

SPAN=$(tail -n1 "$TMPHOME/.superagent/obs/spans.jsonl")
echo "$SPAN" | jq -e '.op == "tool.Read" and .status == "OK"' >/dev/null \
  || { echo "FAIL: span shape: $SPAN"; exit 1; }

METRIC=$(tail -n1 "$TMPHOME/.superagent/obs/metrics.jsonl")
echo "$METRIC" | jq -e '.name == "agent_token_usage" and .kind == "histogram" and .value == 150' >/dev/null \
  || { echo "FAIL: metric shape: $METRIC"; exit 1; }

echo "test-obs-tracker: PASS"
