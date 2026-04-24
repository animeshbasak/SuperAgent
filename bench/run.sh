#!/usr/bin/env bash
# bench/run.sh — golden-dataset bench for superagent-classify
# HARD GATE: avg similarity >= 0.90  AND  fail_count <= 2
# A prompt passes if its LCS similarity score >= 0.85

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLASSIFY="$SCRIPT_DIR/../bin/superagent-classify"
SCORE_SH="$SCRIPT_DIR/score.sh"
PROMPTS="$SCRIPT_DIR/prompts.jsonl"

# ── dependency checks ────────────────────────────────────────────────────────
[[ -x "$CLASSIFY" ]] || { echo "ERROR: $CLASSIFY not executable" >&2; exit 2; }
[[ -f "$SCORE_SH" ]] || { echo "ERROR: $SCORE_SH not found" >&2; exit 2; }
[[ -f "$PROMPTS" ]]  || { echo "ERROR: $PROMPTS not found" >&2; exit 2; }

command -v jq >/dev/null 2>&1      || { echo "jq required" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 2; }

# ── thresholds ───────────────────────────────────────────────────────────────
PASS_THRESHOLD="0.85"
AVG_GATE="0.90"
MAX_FAILS=2

# ── accumulate scores ────────────────────────────────────────────────────────
pass_count=0
fail_count=0
score_sum="0"
fail_lines=()

while IFS= read -r line; do
  # skip blank lines and comment lines (start with #)
  [[ -z "$line" ]]       && continue
  [[ "$line" == \#* ]]   && continue

  PROMPT=$(echo "$line" | jq -r '.prompt')
  EXP=$(echo    "$line" | jq -c '.expected_chain')
  ID=$(echo     "$line" | jq -r '.id')

  ACT=$("$CLASSIFY" "$PROMPT" | jq -c '.chain')
  SCORE=$(bash "$SCORE_SH" "$EXP" "$ACT")

  # compare score >= threshold via python3 (bash can't do float comparison)
  if python3 -c "import sys; sys.exit(0 if float('$SCORE') >= float('$PASS_THRESHOLD') else 1)"; then
    pass_count=$((pass_count + 1))
    STATUS="PASS"
  else
    fail_count=$((fail_count + 1))
    STATUS="FAIL"
    fail_lines+=("  #${ID} score=${SCORE}  prompt='${PROMPT}'")
    fail_lines+=("       expected: ${EXP}")
    fail_lines+=("       actual:   ${ACT}")
  fi

  score_sum=$(python3 -c "print($score_sum + $SCORE)")

  echo "  #${ID}  score=${SCORE}  ${STATUS}  ${PROMPT}"

done < "$PROMPTS"

total=$((pass_count + fail_count))
avg=$(python3 -c "print(f'{$score_sum / $total:.3f}')" 2>/dev/null || echo "0.000")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PROMPTS ${total}   PASS ${pass_count}   FAIL ${fail_count}   AVG ${avg}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ ${#fail_lines[@]} -gt 0 ]]; then
  echo ""
  echo "FAILURES:"
  for fl in "${fail_lines[@]}"; do
    echo "$fl"
  done
fi

# ── gate evaluation ──────────────────────────────────────────────────────────
gate_pass=true
gate_msg=""

if ! python3 -c "import sys; sys.exit(0 if float('$avg') >= float('$AVG_GATE') else 1)"; then
  gate_pass=false
  gate_msg="${gate_msg}  avg ${avg} < ${AVG_GATE} (required)\n"
fi

if [[ $fail_count -gt $MAX_FAILS ]]; then
  gate_pass=false
  gate_msg="${gate_msg}  ${fail_count} prompts failed > max ${MAX_FAILS} allowed\n"
fi

echo ""
if $gate_pass; then
  echo "  HARD GATE: PASS  (avg >= ${AVG_GATE}, fails <= ${MAX_FAILS})"
  exit 0
else
  echo "  HARD GATE: FAIL"
  printf "$gate_msg"
  exit 1
fi
