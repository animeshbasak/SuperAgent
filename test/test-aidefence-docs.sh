#!/usr/bin/env bash
# test/test-aidefence-docs.sh — SKILL.md + slash command present + opt-in default documented
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/skills/aidefence/SKILL.md" ]] || { echo "FAIL: SKILL.md missing"; exit 1; }
[[ -f "$ROOT/commands/aidefence.md" ]] || { echo "FAIL: command md missing"; exit 1; }
grep -qiE 'default off|opt[- ]in' "$ROOT/skills/aidefence/SKILL.md" \
  || { echo "FAIL: opt-in default not documented"; exit 1; }
grep -qE '\bsuperagent-aidefence\s+(scan|enable|disable|status|list|feedback)\b' "$ROOT/skills/aidefence/SKILL.md" \
  || { echo "FAIL: subcommands not documented"; exit 1; }

echo "test-aidefence-docs: PASS"
