#!/usr/bin/env bash
# test/test-patterns-promote.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATBIN="$SCRIPT_DIR/../bin/superagent-patterns"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/brain"
: > "$TMPHOME/.superagent/brain/patterns.jsonl"

TS=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/brain/routes.jsonl" <<JSONL
{"ts":"$TS","task_hash":"abc","task":"fix bug in dark mode toggle","chain":["systematic-debugging","tdd"],"outcome":"done","backend":"anthropic"}
{"ts":"$TS","task_hash":"abc","task":"fix bug in dark mode toggle","chain":["systematic-debugging","tdd"],"outcome":"done","backend":"anthropic"}
{"ts":"$TS","task_hash":"abc","task":"fix bug in dark mode toggle","chain":["systematic-debugging","tdd"],"outcome":"done","backend":"anthropic"}
{"ts":"$TS","task_hash":"def","task":"this one should be ignored — only 1 occurrence","chain":["random"],"outcome":"done","backend":"anthropic"}
JSONL

HOME="$TMPHOME" "$PATBIN" promote >/dev/null

LINES=$(wc -l < "$TMPHOME/.superagent/brain/patterns.jsonl" | tr -d ' ')
[[ "$LINES" == "1" ]] || { echo "FAIL: expected 1 pattern, got $LINES"; cat "$TMPHOME/.superagent/brain/patterns.jsonl"; exit 1; }

REC=$(cat "$TMPHOME/.superagent/brain/patterns.jsonl")
echo "$REC" | jq -e '.useCount == 3 and .successRate >= 0.59 and (.chain == ["systematic-debugging","tdd"])' >/dev/null \
  || { echo "FAIL: pattern record shape wrong: $REC"; exit 1; }

HOME="$TMPHOME" "$PATBIN" promote >/dev/null
LINES2=$(wc -l < "$TMPHOME/.superagent/brain/patterns.jsonl" | tr -d ' ')
[[ "$LINES2" == "1" ]] || { echo "FAIL: dedup broken on second run, got $LINES2 lines"; exit 1; }

echo "test-patterns-promote: PASS"
