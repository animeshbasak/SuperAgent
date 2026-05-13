#!/usr/bin/env bash
# test/test-diff-risk-docs.sh — skill + slash + jujutsu alias + classifier rule
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/skills/diff-risk/SKILL.md" ]] || { echo "FAIL: SKILL.md missing"; exit 1; }
[[ -f "$ROOT/commands/diff-risk.md" ]] || { echo "FAIL: /diff-risk slash missing"; exit 1; }
[[ -f "$ROOT/commands/jujutsu.md" ]] || { echo "FAIL: /jujutsu alias missing"; exit 1; }
grep -qE "deprecat|legacy alias" "$ROOT/commands/jujutsu.md" \
  || { echo "FAIL: jujutsu deprecation note missing"; exit 1; }
grep -qE "IMPACT_KEYWORDS|impact score" "$ROOT/skills/diff-risk/SKILL.md" \
  || { echo "FAIL: impact scoring not documented"; exit 1; }

OUT=$("$ROOT/bin/superagent-classify" "analyze the risk of this diff before push")
echo "$OUT" | jq -e '.chain | index("diff-risk") != null' >/dev/null \
  || { echo "FAIL: classifier doesn't route to diff-risk: $OUT"; exit 1; }

echo "test-diff-risk-docs: PASS"
