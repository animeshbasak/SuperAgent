#!/usr/bin/env bash
# test/test-wave2-docs.sh — Wave 2 doc + version artifacts present and consistent
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/skills/aidefence/SKILL.md" ]]      || { echo "FAIL: aidefence SKILL.md missing"; exit 1; }
[[ -f "$ROOT/skills/observability/SKILL.md" ]]  || { echo "FAIL: observability SKILL.md missing"; exit 1; }
[[ -f "$ROOT/skills/autopilot/SKILL.md" ]]      || { echo "FAIL: autopilot SKILL.md missing"; exit 1; }

grep -q '## v2.5.0' "$ROOT/CHANGELOG.md" \
  || { echo "FAIL: CHANGELOG missing v2.5.0 section"; exit 1; }

VERSION=$(jq -r '.version' "$ROOT/package.json" 2>/dev/null || echo missing)
[[ "$VERSION" == "2.5.0" ]] || { echo "FAIL: package.json version is $VERSION, want 2.5.0"; exit 1; }

grep -qE 'AIDefence|Specialist agents|Autopilot|Observability' "$ROOT/README.md" \
  || { echo "FAIL: README missing Wave 2 capability rows"; exit 1; }

echo "test-wave2-docs: PASS"
