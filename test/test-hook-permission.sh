#!/usr/bin/env bash
# test/test-hook-permission.sh — auto-allow patterns from safety/allow.txt
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-permission.py"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/safety"
cat > "$TMPHOME/.superagent/safety/allow.txt" <<'EOF'
^git push --force-with-lease\b
^npm test\b
EOF

PAYLOAD_OK='{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"git push --force-with-lease origin main"}}'
OUT_OK=$(HOME="$TMPHOME" python3 "$HOOK" <<<"$PAYLOAD_OK")
echo "$OUT_OK" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' >/dev/null \
  || { echo "FAIL: allowed pattern not auto-approved: $OUT_OK"; exit 1; }

PAYLOAD_ASK='{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"rm -rf /important"}}'
OUT_ASK=$(HOME="$TMPHOME" python3 "$HOOK" <<<"$PAYLOAD_ASK")
echo "$OUT_ASK" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null \
  || { echo "FAIL: unmatched should default to ask: $OUT_ASK"; exit 1; }

echo "test-hook-permission: PASS"
