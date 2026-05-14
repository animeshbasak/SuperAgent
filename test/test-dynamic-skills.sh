#!/usr/bin/env bash
# test/test-dynamic-skills.sh — dynamic-skills SKILL.md + superagent-reload CLI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/skills/dynamic-skills/SKILL.md"
BIN="$ROOT/bin/superagent-reload"

# --- 1. SKILL.md exists with correct frontmatter ---
[[ -f "$SKILL" ]] || { echo "FAIL: SKILL.md missing at $SKILL"; exit 1; }
grep -qE "^name: dynamic-skills$" "$SKILL" \
  || { echo "FAIL: SKILL.md frontmatter missing 'name: dynamic-skills'"; exit 1; }

# --- 2. credits jcode (URL present) ---
grep -q "https://github.com/1jehuang/jcode" "$SKILL" \
  || { echo "FAIL: SKILL.md does not credit jcode URL"; exit 1; }

# --- 3. documents the limit (no runtime reload API from hooks) ---
grep -qiE "does not expose a runtime|no runtime|runtime skill-reload|cannot force" "$SKILL" \
  || { echo "FAIL: SKILL.md does not document the no-runtime-reload limit"; exit 1; }

# --- 4. bin --help works and mentions all subcommands ---
[[ -x "$BIN" ]] || { echo "FAIL: $BIN not executable"; exit 1; }
HELP="$("$BIN" --help 2>&1)" || { echo "FAIL: --help exited non-zero"; exit 1; }
for sub in list sync diff status; do
  echo "$HELP" | grep -q "$sub" || { echo "FAIL: --help does not mention '$sub'"; exit 1; }
done

# --- 5. list --json returns valid JSON with required keys ---
JSON_OUT="$("$BIN" list --json 2>/dev/null)"
echo "$JSON_OUT" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
for key in ('inRepo', 'inClaude', 'outOfSync'):
    assert key in data, f'missing key: {key}'
    assert isinstance(data[key], list), f'{key} is not a list'
" || { echo "FAIL: list --json missing required keys or not valid JSON"; exit 1; }

# --- 6. sync --dry-run does not write ---
# Use a tempdir to verify no writes happen.
TMP_CLAUDE="$(mktemp -d -t superagent-reload-test.XXXXXX)"
trap 'rm -rf "$TMP_CLAUDE"' EXIT
SUPERAGENT_CLAUDE_SKILLS="$TMP_CLAUDE" "$BIN" sync --dry-run > /tmp/sa-reload-test.out 2>&1 \
  || { echo "FAIL: sync --dry-run exited non-zero"; cat /tmp/sa-reload-test.out; exit 1; }

grep -q "would copy" /tmp/sa-reload-test.out \
  || { echo "FAIL: sync --dry-run did not report 'would copy' actions"; cat /tmp/sa-reload-test.out; exit 1; }
grep -q "dry-run: no files were written" /tmp/sa-reload-test.out \
  || { echo "FAIL: sync --dry-run missing dry-run confirmation"; cat /tmp/sa-reload-test.out; exit 1; }

# Confirm tempdir is still empty (no actual writes happened).
if [[ -n "$(ls -A "$TMP_CLAUDE" 2>/dev/null)" ]]; then
  echo "FAIL: sync --dry-run wrote files to $TMP_CLAUDE"
  ls -la "$TMP_CLAUDE"
  exit 1
fi

echo "test-dynamic-skills: PASS"
