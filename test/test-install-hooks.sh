#!/usr/bin/env bash
# test/test-install-hooks.sh — install.sh wires 5 new events idempotently
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/../install.sh"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.claude"
echo '{}' > "$TMPHOME/.claude/settings.json"

HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true

for event in UserPromptSubmit SubagentStop Notification PermissionRequest PreCompact; do
  count=$(jq --arg e "$event" '.hooks[$e] // [] | length' "$TMPHOME/.claude/settings.json")
  [[ "$count" -ge 1 ]] || { echo "FAIL: $event not wired (count=$count)"; exit 1; }
done

HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true
for event in UserPromptSubmit SubagentStop Notification PermissionRequest PreCompact; do
  total=$(jq --arg e "$event" '[.hooks[$e][]?.hooks[]? | select(.command | contains("superagent"))] | length' "$TMPHOME/.claude/settings.json")
  [[ "$total" -le 1 ]] || { echo "FAIL: $event duplicated (count=$total) on second install"; exit 1; }
done

echo "test-install-hooks: PASS"
