#!/usr/bin/env bash
# test/test-classify.sh — smoke tests for superagent-classify output shape

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLASSIFY="$SCRIPT_DIR/../bin/superagent-classify"

pass=0
fail=0

assert() {
  local desc="$1"
  local result="$2"
  local expected="$3"
  if [[ "$result" == "$expected" ]]; then
    echo "  PASS  $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL  $desc"
    echo "        expected: $expected"
    echo "        got:      $result"
    fail=$((fail + 1))
  fi
}

assert_contains() {
  local desc="$1"
  local haystack="$2"
  local needle="$3"
  if echo "$haystack" | grep -q "$needle"; then
    echo "  PASS  $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL  $desc"
    echo "        expected to contain: $needle"
    echo "        got: $haystack"
    fail=$((fail + 1))
  fi
}

echo "Running superagent-classify smoke tests..."
echo ""

# ── Test 1: emits valid JSON ──────────────────────────────────────────────────
output=$("$CLASSIFY" "fix the bug" 2>&1)
is_valid=$(echo "$output" | python3 -c "import sys,json; json.load(sys.stdin); print('yes')" 2>/dev/null || echo "no")
assert "emits valid JSON" "$is_valid" "yes"

# ── Test 2: top-level keys present (chain + hint) ─────────────────────────────
has_chain=$(echo "$output" | jq 'has("chain")' 2>/dev/null || echo "false")
assert "output has 'chain' key" "$has_chain" "true"

has_hint=$(echo "$output" | jq 'has("hint")' 2>/dev/null || echo "false")
assert "output has 'hint' key" "$has_hint" "true"

# ── Test 3: hint is null at this task ────────────────────────────────────────
hint_val=$(echo "$output" | jq -r '.hint' 2>/dev/null || echo "NOT_NULL")
assert "hint is null" "$hint_val" "null"

# ── Test 4: chain is a non-empty array ───────────────────────────────────────
chain_type=$(echo "$output" | jq -r '.chain | type' 2>/dev/null || echo "")
assert "chain is an array" "$chain_type" "array"

chain_len=$(echo "$output" | jq '.chain | length' 2>/dev/null || echo "0")
is_nonempty=$(python3 -c "print('yes' if int('$chain_len') > 0 else 'no')")
assert "chain is non-empty" "$is_nonempty" "yes"

# ── Test 5: 'fix the bug' includes systematic-debugging ──────────────────────
chain_json=$(echo "$output" | jq -c '.chain')
contains_dbg=$(echo "$chain_json" | python3 -c "import sys,json; c=json.load(sys.stdin); print('yes' if 'systematic-debugging' in c else 'no')")
assert "'fix the bug' chain contains systematic-debugging" "$contains_dbg" "yes"

# ── Test 6: always_first (mempalace-wake) is first element ───────────────────
first=$(echo "$output" | jq -r '.chain[0]' 2>/dev/null || echo "")
assert "chain[0] is mempalace-wake" "$first" "mempalace-wake"

# ── Test 7: case-insensitive matching — FIX THE BUG ──────────────────────────
output_upper=$("$CLASSIFY" "FIX THE BUG" 2>&1)
contains_dbg_upper=$(echo "$output_upper" | jq -c '.chain' | python3 -c "import sys,json; c=json.load(sys.stdin); print('yes' if 'systematic-debugging' in c else 'no')")
assert "FIX THE BUG (uppercase) also routes to systematic-debugging" "$contains_dbg_upper" "yes"

# ── Test 8: empty input exits non-zero ───────────────────────────────────────
if "$CLASSIFY" "" >/dev/null 2>&1; then
  echo "  FAIL  empty input exits non-zero"
  fail=$((fail + 1))
else
  echo "  PASS  empty input exits non-zero"
  pass=$((pass + 1))
fi

# ── Test 9: verify-before-completion appended for build archetypes ───────────
bug_chain=$("$CLASSIFY" "fix the bug" | jq -r '.chain[-1]')
assert "last item for bug is verification-before-completion" "$bug_chain" "verification-before-completion"

# ── Test 10: non-build archetype (recall) does NOT get vbc ───────────────────
recall_chain=$("$CLASSIFY" "what did we decide last week" | jq -c '.chain')
has_vbc=$(echo "$recall_chain" | python3 -c "import sys,json; c=json.load(sys.stdin); print('yes' if 'verification-before-completion' in c else 'no')")
assert "recall prompt does NOT get verification-before-completion" "$has_vbc" "no"

# ── Test 11: history-bias hint from routes.jsonl ─────────────────────────────
echo ""
echo "  [history-bias tests]"

# Set up temp routes.jsonl at the expected location
ROUTES_DIR="${HOME}/.superagent/brain"
ROUTES_FILE="${ROUTES_DIR}/routes.jsonl"
mkdir -p "$ROUTES_DIR"

# Compute task hash exactly as the classifier does
HIST_TASK="build a REST API with authentication"
if command -v shasum >/dev/null 2>&1; then
  HIST_HASH=$(printf '%s' "$HIST_TASK" | shasum -a 256 | cut -c1-12)
else
  HIST_HASH=$(printf '%s' "$HIST_TASK" | sha256sum | cut -c1-12)
fi

# The prior chain we recorded for this task
PRIOR_CHAIN='["mempalace-wake","writing-plans","test-driven-development","verification-before-completion"]'

# Backup any existing routes.jsonl content
ROUTES_BACKUP=""
if [[ -f "$ROUTES_FILE" ]]; then
  ROUTES_BACKUP=$(cat "$ROUTES_FILE")
fi

# Write a known matching entry (done) and a non-matching entry (failed)
printf '{"task_hash":"%s","chain":["mempalace-wake","old-chain"],"outcome":"failed"}\n' "$HIST_HASH" > "$ROUTES_FILE"
printf '{"task_hash":"%s","chain":%s,"outcome":"done"}\n' "$HIST_HASH" "$PRIOR_CHAIN" >> "$ROUTES_FILE"
printf '{"task_hash":"000000000000","chain":["other-chain"],"outcome":"done"}\n' >> "$ROUTES_FILE"

# Invoke classifier with the matching task
hist_output=$("$CLASSIFY" "$HIST_TASK" 2>&1)

# Assert hint is not null
hist_hint_type=$(echo "$hist_output" | jq -r '.hint | type' 2>/dev/null || echo "null")
assert "hint is array (not null) when history match exists" "$hist_hint_type" "array"

# Assert hint equals the recorded chain
hist_hint=$(echo "$hist_output" | jq -c '.hint' 2>/dev/null || echo "null")
assert "hint equals the recorded prior chain" "$hist_hint" "$PRIOR_CHAIN"

# Assert chain is still correctly computed (no regression)
hist_chain_first=$(echo "$hist_output" | jq -r '.chain[0]' 2>/dev/null || echo "")
assert "chain[0] still mempalace-wake with history present" "$hist_chain_first" "mempalace-wake"

# Assert that a task with no history match still gets null hint
no_match_output=$("$CLASSIFY" "xyzzy_no_match_task_99" 2>&1)
no_match_hint=$(echo "$no_match_output" | jq -r '.hint' 2>/dev/null || echo "NOT_NULL")
assert "hint is null for task with no history match" "$no_match_hint" "null"

# Assert that a task whose only history entry has outcome != "done" gets null hint
failed_task="only_failed_outcome_task_xyz"
if command -v shasum >/dev/null 2>&1; then
  FAILED_HASH=$(printf '%s' "$failed_task" | shasum -a 256 | cut -c1-12)
else
  FAILED_HASH=$(printf '%s' "$failed_task" | sha256sum | cut -c1-12)
fi
printf '{"task_hash":"%s","chain":["some-chain"],"outcome":"failed"}\n' "$FAILED_HASH" >> "$ROUTES_FILE"
failed_output=$("$CLASSIFY" "$failed_task" 2>&1)
failed_hint=$(echo "$failed_output" | jq -r '.hint' 2>/dev/null || echo "NOT_NULL")
assert "hint is null when only history entry has outcome=failed" "$failed_hint" "null"

# Assert that the LATEST matching done entry is used (not the first)
LATEST_CHAIN='["mempalace-wake","brainstorming","writing-plans","verification-before-completion"]'
printf '{"task_hash":"%s","chain":%s,"outcome":"done"}\n' "$HIST_HASH" "$LATEST_CHAIN" >> "$ROUTES_FILE"
latest_output=$("$CLASSIFY" "$HIST_TASK" 2>&1)
latest_hint=$(echo "$latest_output" | jq -c '.hint' 2>/dev/null || echo "null")
assert "hint uses LATEST matching done entry" "$latest_hint" "$LATEST_CHAIN"

# Restore original routes.jsonl (or remove if it didn't exist)
if [[ -n "$ROUTES_BACKUP" ]]; then
  printf '%s\n' "$ROUTES_BACKUP" > "$ROUTES_FILE"
else
  rm -f "$ROUTES_FILE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Tests: $((pass + fail))   PASS: $pass   FAIL: $fail"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ $fail -eq 0 ]]
