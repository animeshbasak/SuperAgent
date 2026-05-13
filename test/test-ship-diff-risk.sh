#!/usr/bin/env bash
# test/test-ship-diff-risk.sh — ship SKILL.md mentions diff-risk pre-push gate + testgen
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/skills/ship/SKILL.md"

grep -q 'superagent-diff-risk' "$SKILL" \
  || { echo "FAIL: ship skill missing diff-risk pre-push gate"; exit 1; }
grep -qE '\bhigh\b.*\bcritical\b|\bcritical\b.*\bhigh\b' "$SKILL" \
  || { echo "FAIL: ship skill missing high/critical force-confirm"; exit 1; }
grep -q 'force-confirm' "$SKILL" \
  || { echo "FAIL: ship skill missing force-confirm wording"; exit 1; }
grep -q 'superagent-testgen' "$SKILL" \
  || { echo "FAIL: ship skill missing testgen consultation"; exit 1; }
grep -q 'BELOW THRESHOLD' "$SKILL" \
  || { echo "FAIL: ship skill missing testgen verdict reference"; exit 1; }

echo "test-ship-diff-risk: PASS"
