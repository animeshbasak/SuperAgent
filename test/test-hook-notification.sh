#!/usr/bin/env bash
# test/test-hook-notification.sh — info gets dropped, error gets passed through
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-notification.py"

INFO='{"hook_event_name":"Notification","notification_level":"info","notification_message":"build started"}'
OUT_INFO=$(python3 "$HOOK" <<<"$INFO")
echo "$OUT_INFO" | jq -e '.suppressOutput == true' >/dev/null \
  || { echo "FAIL: info should be suppressed: $OUT_INFO"; exit 1; }

ERR='{"hook_event_name":"Notification","notification_level":"error","notification_message":"build failed"}'
OUT_ERR=$(python3 "$HOOK" <<<"$ERR")
echo "$OUT_ERR" | jq -e '.suppressOutput == false' >/dev/null \
  || { echo "FAIL: error should not be suppressed: $OUT_ERR"; exit 1; }

echo "test-hook-notification: PASS"
