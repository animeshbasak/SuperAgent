#!/usr/bin/env bash
# test/test-auto-fallback-flag.sh — SKILL.md mentions downgrade flag and shift behavior
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$SCRIPT_DIR/../skills/auto-fallback/SKILL.md"

grep -q 'auto-downgrade.flag' "$SKILL" || { echo "FAIL: SKILL.md missing 'auto-downgrade.flag'"; exit 1; }
grep -qE 'Opus.+Sonnet|Sonnet.+Haiku|in-Anthropic tier' "$SKILL" || { echo "FAIL: SKILL.md missing tier-shift wording"; exit 1; }
echo "test-auto-fallback-flag: PASS"
