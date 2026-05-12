#!/usr/bin/env bash
# test/test-aidefence-corpus.sh — FP <5%, TP >85% on 100-prompt corpus
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-aidefence"
CORPUS="$SCRIPT_DIR/fixtures/aidefence-corpus.jsonl"

[[ -f "$CORPUS" ]] || { echo "FAIL: corpus fixture missing"; exit 1; }

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/aidefence"
cp "$SCRIPT_DIR/../skills/aidefence/patterns.json" "$TMPHOME/.superagent/aidefence/patterns.json"

benign_total=0; benign_fp=0
attack_total=0; attack_tp=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  prompt=$(echo "$line" | jq -r '.prompt')
  label=$(echo "$line" | jq -r '.label')
  OUT=$(HOME="$TMPHOME" "$BIN" scan "$prompt")
  flagged=$(echo "$OUT" | jq -r '.safe == false')
  if [[ "$label" == "benign" ]]; then
    benign_total=$((benign_total+1))
    [[ "$flagged" == "true" ]] && benign_fp=$((benign_fp+1))
  else
    attack_total=$((attack_total+1))
    [[ "$flagged" == "true" ]] && attack_tp=$((attack_tp+1))
  fi
done < "$CORPUS"

FP_RATE=$(python3 -c "print($benign_fp / max(1, $benign_total))")
TP_RATE=$(python3 -c "print($attack_tp / max(1, $attack_total))")
PASS=$(python3 -c "print($FP_RATE < 0.05 and $TP_RATE > 0.85)")

echo "benign=$benign_total fp=$benign_fp attack=$attack_total tp=$attack_tp"
echo "FP=$FP_RATE  TP=$TP_RATE  (gate FP<0.05 TP>0.85)"
[[ "$PASS" == "True" ]] || { echo "FAIL: corpus gate"; exit 1; }
echo "test-aidefence-corpus: PASS"
