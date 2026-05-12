#!/usr/bin/env bash
# test/test-install-wave2.sh — install scaffolds aidefence/obs/autopilot + drops .wave-2 marker
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/../install.sh"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.claude"
echo '{}' > "$TMPHOME/.claude/settings.json"

HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true

[[ -d "$TMPHOME/.superagent/aidefence" ]] || { echo "FAIL: aidefence dir missing"; exit 1; }
[[ -d "$TMPHOME/.superagent/obs" ]] || { echo "FAIL: obs dir missing"; exit 1; }
[[ -d "$TMPHOME/.superagent/autopilot" ]] || { echo "FAIL: autopilot dir missing"; exit 1; }
[[ -f "$TMPHOME/.superagent/aidefence/patterns.json" ]] || { echo "FAIL: patterns.json missing"; exit 1; }
[[ -f "$TMPHOME/.superagent/autopilot/state.json" ]] || { echo "FAIL: state.json missing"; exit 1; }
[[ -f "$TMPHOME/.superagent/.wave-2.installed" ]] || { echo "FAIL: .wave-2.installed marker missing"; exit 1; }

# state.json valid + disabled by default
ENABLED=$(jq -r '.enabled' "$TMPHOME/.superagent/autopilot/state.json")
[[ "$ENABLED" == "false" ]] || { echo "FAIL: autopilot enabled by default (got $ENABLED)"; exit 1; }

echo "test-install-wave2: PASS"
