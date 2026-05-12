#!/usr/bin/env bash
# test/test-wave1-docs.sh — Wave 1 doc + version artifacts present and consistent
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/skills/superagent-learn-loop/SKILL.md" ]] \
  || { echo "FAIL: superagent-learn-loop SKILL.md missing"; exit 1; }
[[ -f "$ROOT/skills/cost-budget/SKILL.md" ]] \
  || { echo "FAIL: cost-budget SKILL.md missing"; exit 1; }

grep -q '## v2.4.0' "$ROOT/CHANGELOG.md" \
  || { echo "FAIL: CHANGELOG missing v2.4.0 section"; exit 1; }

VERSION=$(jq -r '.version' "$ROOT/package.json" 2>/dev/null || echo missing)
case "$VERSION" in
  2.4.*|2.5.*|2.6.*|2.7.*|2.8.*|2.9.*|3.*) ;;
  *) echo "FAIL: package.json version is $VERSION, want >=2.4.0"; exit 1 ;;
esac

grep -qE 'patterns\.jsonl|learning loop|budget alerts' "$ROOT/README.md" \
  || { echo "FAIL: README missing Wave 1 capability row"; exit 1; }

echo "test-wave1-docs: PASS"
