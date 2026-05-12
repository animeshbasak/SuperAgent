#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/skills/observability/SKILL.md" ]] || { echo "FAIL: SKILL.md missing"; exit 1; }
[[ -f "$ROOT/commands/observe.md" ]] || { echo "FAIL: /observe slash missing"; exit 1; }
grep -qE 'p50|p95|p99' "$ROOT/skills/observability/SKILL.md" \
  || { echo "FAIL: percentiles not documented"; exit 1; }
grep -q 'agent_token_usage' "$ROOT/skills/observability/SKILL.md" \
  || { echo "FAIL: canonical metric names missing"; exit 1; }

echo "test-obs-docs: PASS"
