#!/usr/bin/env bash
# test/test-diff-risk-classify.sh — 20-diff corpus, gate ≥18/20 primary correct
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-diff-risk"
CORPUS="$SCRIPT_DIR/fixtures/diff-risk/corpus.jsonl"

total=0
correct=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  total=$((total+1))
  msg=$(echo "$line" | jq -r '.msg')
  files=$(echo "$line" | jq -r '.files | join(",")')
  want=$(echo "$line" | jq -r '.label')
  OUT=$("$BIN" classify --commit-msg "$msg" --files "$files" --json)
  got=$(echo "$OUT" | jq -r '.primary')
  if [[ "$got" == "$want" ]]; then
    correct=$((correct+1))
  else
    echo "  miss: want=$want got=$got msg=\"$msg\""
  fi
done < "$CORPUS"

echo "score: $correct/$total"
PASS=$(python3 -c "print($correct >= 18)")
[[ "$PASS" == "True" ]] || { echo "FAIL: corpus score $correct/$total below 18"; exit 1; }

echo "test-diff-risk-classify: PASS"
