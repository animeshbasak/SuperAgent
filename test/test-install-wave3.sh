#!/usr/bin/env bash
# test/test-install-wave3.sh — install scaffolds sparc/testgen/diff dirs + marker
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/../install.sh"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.claude"
echo '{}' > "$TMPHOME/.claude/settings.json"

HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true

[[ -d "$TMPHOME/.superagent/sparc" ]] || { echo "FAIL: sparc dir missing"; exit 1; }
[[ -d "$TMPHOME/.superagent/testgen" ]] || { echo "FAIL: testgen dir missing"; exit 1; }
[[ -d "$TMPHOME/.superagent/diff" ]] || { echo "FAIL: diff dir missing"; exit 1; }
[[ -f "$TMPHOME/.superagent/testgen/min-coverage.txt" ]] || { echo "FAIL: min-coverage.txt missing"; exit 1; }
[[ -f "$TMPHOME/.superagent/.wave-3.installed" ]] || { echo "FAIL: .wave-3 marker missing"; exit 1; }

THRESHOLD=$(cat "$TMPHOME/.superagent/testgen/min-coverage.txt")
[[ "$THRESHOLD" == "70" ]] || { echo "FAIL: default threshold not 70 (got $THRESHOLD)"; exit 1; }

echo "test-install-wave3: PASS"
