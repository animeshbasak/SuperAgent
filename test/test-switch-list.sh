#!/usr/bin/env bash
# test/test-switch-list.sh — `superagent-switch list` reads cached models JSON.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCH="$SCRIPT_DIR/../bin/superagent-switch"

pass=0
fail=0

# Backup any existing models file
MODELS_FILE="$HOME/.superagent/local-models.json"
mkdir -p "$HOME/.superagent"
BACKUP=""
if [[ -f "$MODELS_FILE" ]]; then
  BACKUP=$(mktemp)
  cp "$MODELS_FILE" "$BACKUP"
fi

cleanup() {
  if [[ -n "$BACKUP" ]]; then
    cp "$BACKUP" "$MODELS_FILE"
    rm -f "$BACKUP"
  else
    rm -f "$MODELS_FILE"
  fi
}
trap cleanup EXIT

# Write fresh fake models file (refreshed_at = now)
NOW=$(date +%s)
cat > "$MODELS_FILE" <<JSON
{
  "refreshed_at": $NOW,
  "models": [
    {"name": "qwen2.5-coder:7b", "provider": "ollama", "size": "4.7GB"},
    {"name": "qwen3-coder:next", "provider": "lmstudio", "size": ""},
    {"name": "deepseek-coder-v2", "provider": "llamacpp", "size": ""}
  ]
}
JSON

OUT=$("$SWITCH" list)

for m in "qwen2.5-coder:7b" "qwen3-coder:next" "deepseek-coder-v2"; do
  if echo "$OUT" | grep -q "$m"; then
    echo "  PASS  list output contains $m"
    pass=$((pass + 1))
  else
    echo "  FAIL  list output missing $m"
    fail=$((fail + 1))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Tests: $((pass + fail))   PASS: $pass   FAIL: $fail"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ $fail -eq 0 ]]
