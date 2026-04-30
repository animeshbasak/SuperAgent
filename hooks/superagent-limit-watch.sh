#!/usr/bin/env bash
# superagent-limit-watch.sh — UserPromptSubmit hook
#
# Reads the Claude Code prompt-submit JSON from stdin, polls `superagent-cost today --json`,
# and writes a warning marker to ~/.superagent/limit-warn.json when:
#   - spend > 80% of plan limit
#   - time to 5h reset < 30min
#   - 429 burst >= 3 in 60s
#
# When auto-fallback flag is "on" AND no in-flight tool calls, it invokes
# `superagent-switch auto-suggest` to surface a switch prompt. Idempotent + flock-safe.
#
# Hook type: UserPromptSubmit (NOT PreToolUse — see Engineer C audit).

set -euo pipefail

STATE_DIR="$HOME/.superagent"
WARN_FILE="$STATE_DIR/limit-warn.json"
LOCK_FILE="$STATE_DIR/limit-watch.lock"
LOG_FILE="$STATE_DIR/limit-watch.log"
AUTO_FLAG="$STATE_DIR/auto-fallback.flag"
INFLIGHT_FILE="$STATE_DIR/inflight-tools"

mkdir -p "$STATE_DIR"
touch "$LOCK_FILE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Atomic write w/ flock + temp rename (portable: flock on Linux, fcntl on Darwin)
atomic_write() {
  local target="$1"
  local tmp
  tmp=$(mktemp "${target}.XXXXXX")
  cat > "$tmp"
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 9
      mv "$tmp" "$target"
    ) 9>"$LOCK_FILE"
  else
    python3 - "$LOCK_FILE" "$tmp" "$target" <<'PY'
import fcntl, os, sys
lock, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
fd = os.open(lock, os.O_RDWR | os.O_CREAT, 0o644)
try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    os.replace(src, dst)
finally:
    fcntl.flock(fd, fcntl.LOCK_UN)
    os.close(fd)
PY
  fi
}

# Drain stdin (Claude Code sends a JSON payload). We don't currently use it,
# but consuming it cleanly avoids broken-pipe noise.
PAYLOAD=""
if [[ ! -t 0 ]]; then
  PAYLOAD=$(cat || true)
fi

# Locate superagent-cost
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COST_BIN=""
for c in \
  "$SCRIPT_DIR/../bin/superagent-cost" \
  "$HOME/.local/bin/superagent-cost" \
  "$(command -v superagent-cost 2>/dev/null || true)"; do
  if [[ -n "$c" && -x "$c" ]]; then
    COST_BIN="$c"
    break
  fi
done

if [[ -z "$COST_BIN" ]]; then
  log "superagent-cost not found — skipping"
  exit 0
fi

# Pull current spend snapshot (JSON)
COST_JSON=$("$COST_BIN" today --json 2>/dev/null || echo '{}')

# Extract numbers w/ jq, default 0
PCT=$(echo "$COST_JSON" | jq -r '.pct_of_plan // 0' 2>/dev/null || echo 0)
RESET_MIN=$(echo "$COST_JSON" | jq -r '.time_to_5h_reset_minutes // 999' 2>/dev/null || echo 999)
BURST=$(echo "$COST_JSON" | jq -r '.recent_429_count_60s // 0' 2>/dev/null || echo 0)

# Decide trigger
TRIGGER=""
if python3 -c "import sys; sys.exit(0 if float('$PCT') > 0.80 else 1)" 2>/dev/null; then
  TRIGGER="budget>80%"
elif python3 -c "import sys; sys.exit(0 if float('$RESET_MIN') < 30 else 1)" 2>/dev/null; then
  TRIGGER="reset<30min"
elif python3 -c "import sys; sys.exit(0 if int('$BURST') >= 3 else 1)" 2>/dev/null; then
  TRIGGER="429-burst"
fi

if [[ -z "$TRIGGER" ]]; then
  # No warning state — clear stale warn file, idempotent
  if [[ -f "$WARN_FILE" ]]; then
    rm -f "$WARN_FILE"
  fi
  exit 0
fi

# Write warning marker (atomic)
WARN_JSON=$(jq -n \
  --arg trigger "$TRIGGER" \
  --argjson pct "$PCT" \
  --argjson reset "$RESET_MIN" \
  --argjson burst "$BURST" \
  --arg ts "$(date -Iseconds)" \
  '{trigger:$trigger, pct_of_plan:$pct, time_to_5h_reset_minutes:$reset, recent_429_count_60s:$burst, ts:$ts}')
atomic_write "$WARN_FILE" <<<"$WARN_JSON"
log "warn trigger=$TRIGGER pct=$PCT reset=$RESET_MIN burst=$BURST"

# Auto-suggest path: only if flag=on AND no in-flight tools
AUTO="off"
if [[ -f "$AUTO_FLAG" ]]; then
  AUTO=$(cat "$AUTO_FLAG" 2>/dev/null || echo "off")
fi

if [[ "$AUTO" == "on" ]]; then
  IN_FLIGHT=0
  if [[ -f "$INFLIGHT_FILE" ]]; then
    IN_FLIGHT=$(wc -l < "$INFLIGHT_FILE" 2>/dev/null | tr -d ' ' || echo 0)
  fi
  if [[ "${IN_FLIGHT:-0}" -eq 0 ]]; then
    SWITCH_BIN="$SCRIPT_DIR/../bin/superagent-switch"
    if [[ -x "$SWITCH_BIN" ]]; then
      "$SWITCH_BIN" auto-suggest >/dev/null 2>&1 || true
      log "auto-suggest invoked"
    fi
  else
    log "auto-mode skipped — $IN_FLIGHT tool(s) in flight"
  fi
fi

exit 0
