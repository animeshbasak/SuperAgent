#!/usr/bin/env bash
# test/test-v3-docs.sh — v3.0.0 References Integration Pack present + consistent
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/skills/scraping/SKILL.md" ]]       || { echo "FAIL: scraping SKILL.md missing"; exit 1; }
[[ -f "$ROOT/skills/agent-pool/SKILL.md" ]]     || { echo "FAIL: agent-pool SKILL.md missing"; exit 1; }
[[ -f "$ROOT/skills/dynamic-skills/SKILL.md" ]] || { echo "FAIL: dynamic-skills SKILL.md missing"; exit 1; }

[[ -x "$ROOT/bin/superagent-scrape" ]]   || { echo "FAIL: superagent-scrape bin missing or not executable"; exit 1; }
[[ -x "$ROOT/bin/superagent-pool" ]]     || { echo "FAIL: superagent-pool bin missing"; exit 1; }
[[ -x "$ROOT/bin/superagent-reload" ]]   || { echo "FAIL: superagent-reload bin missing"; exit 1; }

grep -q '## v3.0.0' "$ROOT/CHANGELOG.md" \
  || { echo "FAIL: CHANGELOG missing v3.0.0 section"; exit 1; }

VERSION=$(jq -r '.version' "$ROOT/package.json" 2>/dev/null || echo missing)
[[ "$VERSION" == "3.0.0" ]] || { echo "FAIL: package.json version is $VERSION, want 3.0.0"; exit 1; }

grep -qE 'Scrapling|Octogent|jcode|References Integration Pack' "$ROOT/README.md" \
  || { echo "FAIL: README missing v3.0.0 references mentions"; exit 1; }

# Credit checks
grep -q 'D4Vinci/Scrapling' "$ROOT/skills/scraping/SKILL.md" \
  || { echo "FAIL: scraping skill missing upstream credit"; exit 1; }
grep -q 'hesamsheikh/octogent' "$ROOT/skills/agent-pool/SKILL.md" \
  || { echo "FAIL: agent-pool skill missing upstream credit"; exit 1; }
grep -q '1jehuang/jcode' "$ROOT/skills/dynamic-skills/SKILL.md" \
  || { echo "FAIL: dynamic-skills skill missing upstream credit"; exit 1; }

echo "test-v3-docs: PASS"
