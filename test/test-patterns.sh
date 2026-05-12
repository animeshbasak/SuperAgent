#!/usr/bin/env bash
# test/test-patterns.sh — bin/superagent-patterns scaffolding (list, promote, decay, protect, prune)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATBIN="$SCRIPT_DIR/../bin/superagent-patterns"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/brain"
: > "$TMPHOME/.superagent/brain/patterns.jsonl"

# 1. list on empty store → 0 records
OUT=$(HOME="$TMPHOME" "$PATBIN" list --json)
COUNT=$(echo "$OUT" | jq '.count')
[[ "$COUNT" == "0" ]] || { echo "FAIL: empty list count=$COUNT, want 0"; exit 1; }

# 2. list --help exits 0 and prints usage
HOME="$TMPHOME" "$PATBIN" --help | grep -q "Usage:" || { echo "FAIL: --help missing Usage:"; exit 1; }

# 3. unknown subcommand exits 2
HOME="$TMPHOME" "$PATBIN" wat 2>/dev/null && { echo "FAIL: unknown subcommand should fail"; exit 1; } || true

echo "test-patterns(scaffolding): PASS"
