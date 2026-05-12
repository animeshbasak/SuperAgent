#!/usr/bin/env bash
# test/test-distill-patterns.sh — Stop hook calls patterns promote+decay
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTILL="$SCRIPT_DIR/../hooks/superagent-distill.sh"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/brain"
TS=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

cat > "$TMPHOME/.superagent/brain/routes.jsonl" <<JSONL
{"ts":"$TS","task_hash":"abc","task":"hello world test signal","chain":["alpha","beta"],"outcome":"done","backend":"anthropic"}
{"ts":"$TS","task_hash":"abc","task":"hello world test signal","chain":["alpha","beta"],"outcome":"done","backend":"anthropic"}
{"ts":"$TS","task_hash":"abc","task":"hello world test signal","chain":["alpha","beta"],"outcome":"done","backend":"anthropic"}
JSONL
: > "$TMPHOME/.superagent/brain/patterns.jsonl"

echo '{"hook_event_name":"Stop"}' | HOME="$TMPHOME" PATH="$SCRIPT_DIR/../bin:$PATH" bash "$DISTILL" || true

LINES=$(wc -l < "$TMPHOME/.superagent/brain/patterns.jsonl" | tr -d ' ')
[[ "$LINES" == "1" ]] || { echo "FAIL: distill did not promote (got $LINES lines)"; exit 1; }

echo "test-distill-patterns: PASS"
