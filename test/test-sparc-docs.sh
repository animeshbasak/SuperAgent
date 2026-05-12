#!/usr/bin/env bash
# test/test-sparc-docs.sh — SKILL.md + slash + classifier rule wired
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/skills/sparc/SKILL.md" ]] || { echo "FAIL: SKILL.md missing"; exit 1; }
[[ -f "$ROOT/commands/sparc.md" ]] || { echo "FAIL: /sparc slash missing"; exit 1; }
grep -qiE 'boolean gate|no.+score|pass or fail' "$ROOT/skills/sparc/SKILL.md" \
  || { echo "FAIL: boolean-gate discipline not documented"; exit 1; }
grep -q '5-phase\|5 phases' "$ROOT/skills/sparc/SKILL.md" \
  || { echo "FAIL: 5-phase pipeline not documented"; exit 1; }

OUT=$("$ROOT/bin/superagent-classify" "start sparc for the new comments feature")
echo "$OUT" | jq -e '.chain | index("sparc") != null' >/dev/null \
  || { echo "FAIL: classifier doesn't route to sparc: $OUT"; exit 1; }

echo "test-sparc-docs: PASS"
