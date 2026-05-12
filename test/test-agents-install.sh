#!/usr/bin/env bash
# test/test-agents-install.sh — install.sh copies 5 specialists to ~/.claude/agents/
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/../install.sh"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.claude"
echo '{}' > "$TMPHOME/.claude/settings.json"

HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true

for n in architect coder reviewer security-architect tester; do
  [[ -f "$TMPHOME/.claude/agents/$n.md" ]] \
    || { echo "FAIL: $n.md not installed"; exit 1; }
done

# Re-run is idempotent (count stays stable)
COUNT_FIRST=$(ls "$TMPHOME/.claude/agents/" | wc -l | tr -d ' ')
HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true
COUNT_SECOND=$(ls "$TMPHOME/.claude/agents/" | wc -l | tr -d ' ')
[[ "$COUNT_FIRST" == "$COUNT_SECOND" ]] \
  || { echo "FAIL: agents dir grew on re-install ($COUNT_FIRST → $COUNT_SECOND)"; exit 1; }

echo "test-agents-install: PASS"
