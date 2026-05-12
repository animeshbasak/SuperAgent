#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/skills/autopilot/SKILL.md" ]] || { echo "FAIL: SKILL.md missing"; exit 1; }
[[ -f "$ROOT/commands/autopilot.md" ]] || { echo "FAIL: /autopilot slash missing"; exit 1; }
grep -qiE 'default off|opt[- ]in' "$ROOT/skills/autopilot/SKILL.md" \
  || { echo "FAIL: opt-in default not documented"; exit 1; }
grep -q 'ScheduleWakeup' "$ROOT/skills/autopilot/SKILL.md" \
  || { echo "FAIL: ScheduleWakeup mechanism not documented"; exit 1; }
grep -q 'budget gate\|auto-downgrade.flag' "$ROOT/skills/autopilot/SKILL.md" \
  || { echo "FAIL: budget gate not documented"; exit 1; }

OUT=$("$ROOT/bin/superagent-classify" "run autopilot on the open todo list and stop when done")
echo "$OUT" | jq -e '.chain | index("autopilot") != null' >/dev/null \
  || { echo "FAIL: classifier doesn't route to autopilot: $OUT"; exit 1; }

echo "test-autopilot-docs: PASS"
