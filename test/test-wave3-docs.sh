#!/usr/bin/env bash
# test/test-wave3-docs.sh — Wave 3 doc + version artifacts present and consistent
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/skills/sparc/SKILL.md" ]]      || { echo "FAIL: sparc SKILL.md missing"; exit 1; }
[[ -f "$ROOT/skills/testgen/SKILL.md" ]]    || { echo "FAIL: testgen SKILL.md missing"; exit 1; }
[[ -f "$ROOT/skills/diff-risk/SKILL.md" ]]  || { echo "FAIL: diff-risk SKILL.md missing"; exit 1; }

grep -q '## v2.6.0' "$ROOT/CHANGELOG.md" \
  || { echo "FAIL: CHANGELOG missing v2.6.0 section"; exit 1; }

VERSION=$(jq -r '.version' "$ROOT/package.json" 2>/dev/null || echo missing)
[[ "$VERSION" == "2.6.0" ]] || { echo "FAIL: package.json version is $VERSION, want 2.6.0"; exit 1; }

grep -qE 'SPARC|Testgen|Diff-risk' "$ROOT/README.md" \
  || { echo "FAIL: README missing Wave 3 capability rows"; exit 1; }

echo "test-wave3-docs: PASS"
