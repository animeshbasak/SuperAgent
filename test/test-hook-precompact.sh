#!/usr/bin/env bash
# test/test-hook-precompact.sh — PreCompact dumps a pre-compact snapshot
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-precompact.py"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/brain"
TS=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/brain/routes.jsonl" <<JSONL
{"ts":"$TS","task":"recent task","chain":["a","b"],"outcome":"done"}
JSONL

OUT=$(HOME="$TMPHOME" python3 "$HOOK" <<<'{"hook_event_name":"PreCompact"}')
echo "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "PreCompact"' >/dev/null \
  || { echo "FAIL: invalid output: $OUT"; exit 1; }

ls "$TMPHOME"/.superagent/logs/precompact-*.jsonl >/dev/null 2>&1 \
  || { echo "FAIL: precompact snapshot not written"; exit 1; }

echo "test-hook-precompact: PASS"
