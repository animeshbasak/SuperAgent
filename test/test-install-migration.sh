#!/usr/bin/env bash
# test/test-install-migration.sh — backup calls.jsonl + write .wave-1.installed marker
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/../install.sh"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.claude" "$TMPHOME/.superagent/cost"
echo '{}' > "$TMPHOME/.claude/settings.json"

TS=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/cost/calls.jsonl" <<JSONL
{"ts":"$TS","project":"/x","tool":"Bash","tokens":42,"model":"sonnet"}
JSONL

HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true

[[ -f "$TMPHOME/.superagent/cost/calls.v1.jsonl.bak" ]] \
  || { echo "FAIL: calls.v1.jsonl.bak missing"; exit 1; }
[[ -f "$TMPHOME/.superagent/.wave-1.installed" ]] \
  || { echo "FAIL: .wave-1.installed marker missing"; exit 1; }

HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true
COUNT=$(ls "$TMPHOME/.superagent/cost/" | grep -c 'calls\.v1' || echo 0)
[[ "$COUNT" -le 1 ]] || { echo "FAIL: backup duplicated (count=$COUNT)"; exit 1; }

echo "test-install-migration: PASS"
