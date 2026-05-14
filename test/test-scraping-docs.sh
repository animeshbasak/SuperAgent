#!/usr/bin/env bash
# test/test-scraping-docs.sh — Scrapling-vendored skill: SKILL.md, bin, classifier route.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SKILL="$ROOT/skills/scraping/SKILL.md"
BIN="$ROOT/bin/superagent-scrape"

# ── SKILL.md presence + frontmatter ─────────────────────────────────────────
[[ -f "$SKILL" ]] || { echo "FAIL: $SKILL missing"; exit 1; }

# Frontmatter `name: scraping` — must be inside the leading `---` block (within
# first ~20 lines). We accept optional surrounding whitespace.
if ! awk 'NR<=20 && /^name:[[:space:]]*scraping[[:space:]]*$/ {found=1; exit} END{exit !found}' "$SKILL"; then
  echo "FAIL: SKILL.md frontmatter does not declare 'name: scraping' in first 20 lines"
  exit 1
fi

# Prompt-injection protection callout
grep -q -- '--ai-targeted' "$SKILL" \
  || { echo "FAIL: SKILL.md missing --ai-targeted mention"; exit 1; }
grep -qiE 'prompt[- ]injection' "$SKILL" \
  || { echo "FAIL: SKILL.md missing prompt-injection protection callout"; exit 1; }

# Credits — both Scrapling GitHub URL and Discord URL
grep -q 'github.com/D4Vinci/Scrapling' "$SKILL" \
  || { echo "FAIL: SKILL.md missing https://github.com/D4Vinci/Scrapling link"; exit 1; }
grep -q 'discord.gg' "$SKILL" \
  || { echo "FAIL: SKILL.md missing Discord link"; exit 1; }

# ── bin presence + executable + help surface ────────────────────────────────
[[ -f "$BIN" ]]   || { echo "FAIL: $BIN missing"; exit 1; }
[[ -x "$BIN" ]]   || { echo "FAIL: $BIN not executable"; exit 1; }

HELP_OUT="$("$BIN" --help 2>&1)" \
  || { echo "FAIL: 'superagent-scrape --help' exited non-zero"; exit 1; }

for sub in install fetch browser status; do
  if ! grep -q -- "$sub" <<<"$HELP_OUT"; then
    echo "FAIL: --help output missing subcommand: $sub"
    exit 1
  fi
done

# ── classifier routes scraping prompts to a chain containing 'scraping' ────
if ! command -v "$ROOT/bin/superagent-classify" >/dev/null 2>&1 \
     && [[ ! -x "$ROOT/bin/superagent-classify" ]]; then
  echo "FAIL: superagent-classify not found at $ROOT/bin/superagent-classify"
  exit 1
fi

ROUTE_OUT="$("$ROOT/bin/superagent-classify" "scrape this page for product prices" 2>&1)" \
  || { echo "FAIL: superagent-classify failed on scraping prompt"; echo "$ROUTE_OUT"; exit 1; }

# Pull the chain array and check membership without depending on jq's presence
# (the classifier already requires jq, so it's safe to use here).
if ! echo "$ROUTE_OUT" | jq -e '.chain | index("scraping")' >/dev/null 2>&1; then
  echo "FAIL: classifier did not route 'scrape this page for product prices' to a chain containing 'scraping'"
  echo "got: $ROUTE_OUT"
  exit 1
fi

echo "test-scraping-docs: PASS"
