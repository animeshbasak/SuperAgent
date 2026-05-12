#!/usr/bin/env bash
# test/test-tracker-v2.sh — tracker.sh writes v2 schema record from a Bash payload with usage info
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKER="$SCRIPT_DIR/../hooks/superagent-tracker.sh"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/cost" "$TMPHOME/.claude"

PAYLOAD='{
  "tool_name":"Bash",
  "tool_input":{"command":"graphify path A B"},
  "tool_response":{
    "output":"hello world",
    "usage":{
      "input_tokens":12000,
      "output_tokens":4500,
      "cache_creation_input_tokens":2000,
      "cache_read_input_tokens":8000
    }
  }
}'

HOME="$TMPHOME" CLAUDE_MODEL="claude-sonnet-4-5" bash "$TRACKER" <<<"$PAYLOAD" || true

CALLS="$TMPHOME/.superagent/cost/calls.jsonl"
[[ -s "$CALLS" ]] || { echo "FAIL: calls.jsonl empty"; exit 1; }

LAST=$(tail -n1 "$CALLS")
echo "$LAST" | jq -e '.input_tokens == 12000 and .output_tokens == 4500 and .cache_write_tokens == 2000 and .cache_read_tokens == 8000 and .pricing_version == "2026-Q2"' >/dev/null \
  || { echo "FAIL: v2 fields not present in $LAST"; exit 1; }

echo "test-tracker-v2: PASS"
