#!/usr/bin/env bash
# test/test-hook-prompt-submit.sh — UserPromptSubmit hook returns valid Claude Code output
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-prompt-submit.py"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/brain"
: > "$TMPHOME/.superagent/brain/routes.jsonl"
: > "$TMPHOME/.superagent/brain/patterns.jsonl"

PAYLOAD='{"session_id":"s-1","transcript_path":"/tmp/x","cwd":"/tmp","permission_mode":"default","hook_event_name":"UserPromptSubmit","prompt":"fix dark mode toggle bug"}'

OUT=$(HOME="$TMPHOME" PATH="$SCRIPT_DIR/../bin:$PATH" python3 "$HOOK" <<<"$PAYLOAD")

echo "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null \
  || { echo "FAIL: invalid hook output: $OUT"; exit 1; }

echo "$OUT" | jq -e '.hookSpecificOutput.additionalContext | type == "string"' >/dev/null \
  || { echo "FAIL: additionalContext missing or not a string"; exit 1; }

echo '{"session_id":"s","prompt":""}' | HOME="$TMPHOME" python3 "$HOOK" >/dev/null

echo "test-hook-prompt-submit: PASS"
