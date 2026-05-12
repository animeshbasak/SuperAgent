#!/usr/bin/env bash
# test/test-hook-subagent-stop.sh — appends a subagent-flagged route record
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-subagent-stop.py"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/brain"
: > "$TMPHOME/.superagent/brain/routes.jsonl"

PAYLOAD='{"hook_event_name":"SubagentStop","session_id":"s","stop_hook_active":false,"transcript_path":"/tmp/x","tool_input":{"description":"refactor auth module"},"tool_output":{"success":true}}'
HOME="$TMPHOME" python3 "$HOOK" <<<"$PAYLOAD" >/dev/null

LAST=$(tail -n1 "$TMPHOME/.superagent/brain/routes.jsonl")
echo "$LAST" | jq -e '.subagent == true and .outcome == "done"' >/dev/null \
  || { echo "FAIL: subagent-stop record shape: $LAST"; exit 1; }

echo "test-hook-subagent-stop: PASS"
