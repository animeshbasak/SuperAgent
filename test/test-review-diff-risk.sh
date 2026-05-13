#!/usr/bin/env bash
# test/test-review-diff-risk.sh — review SKILL.md mentions diff-risk pre-check + testgen
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/skills/review/SKILL.md"

grep -q 'superagent-diff-risk' "$SKILL" \
  || { echo "FAIL: review skill missing diff-risk integration"; exit 1; }
grep -qE 'critical|high' "$SKILL" \
  || { echo "FAIL: review skill missing impact level mention"; exit 1; }
grep -q 'superagent-testgen' "$SKILL" \
  || { echo "FAIL: review skill missing testgen consultation"; exit 1; }
grep -qE 'BELOW THRESHOLD|coverage' "$SKILL" \
  || { echo "FAIL: review skill missing coverage gate mention"; exit 1; }

echo "test-review-diff-risk: PASS"
