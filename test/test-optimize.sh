#!/usr/bin/env bash
# test/test-optimize.sh — smoke tests for superagent-optimize output shape + behavior

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPTIMIZE="$SCRIPT_DIR/../bin/superagent-optimize"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT

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
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS  $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL  $desc"
    echo "        expected to contain: $needle"
    echo "        got: $haystack"
    fail=$((fail + 1))
  fi
}

echo "Running superagent-optimize smoke tests..."
echo ""

# ── Test 1: emits valid JSON ──────────────────────────────────────────────────
output=$(HOME="$TMPHOME" "$OPTIMIZE" "could you please add a login button" 2>&1)
is_valid=$(echo "$output" | python3 -c "import sys,json; json.load(sys.stdin); print('yes')" 2>/dev/null || echo "no")
assert "emits valid JSON" "$is_valid" "yes"

# ── Test 2: top-level keys present ────────────────────────────────────────────
keys=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(sorted(d.keys())))")
assert "top-level keys" "$keys" "changed,notes,optimized,original"

# ── Test 3: leading filler stripped, imperative + capitalized ─────────────────
opt=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['optimized'])")
assert "filler stripped + capitalized" "$opt" "Add a login button."

# ── Test 4: changed flag true when rewritten ──────────────────────────────────
changed=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['changed'])")
assert "changed=true on rewrite" "$changed" "True"

# ── Test 5: polite question becomes imperative (no trailing ?) ────────────────
output=$(HOME="$TMPHOME" "$OPTIMIZE" "can you fix the dark mode toggle bug?" 2>&1)
opt=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['optimized'])")
assert "polite question → imperative" "$opt" "Fix the dark mode toggle bug."

# ── Test 6: multi-clause prompt becomes numbered steps ────────────────────────
output=$(HOME="$TMPHOME" "$OPTIMIZE" "could you add a login page to the app and then write integration tests for it" 2>&1)
opt=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['optimized'])")
assert_contains "numbered step 1" "$opt" "1. Add a login page to the app"
assert_contains "numbered step 2" "$opt" "2. Write integration tests for it"

# ── Test 7: short prompt passes through unchanged ─────────────────────────────
output=$(HOME="$TMPHOME" "$OPTIMIZE" "fix bug" 2>&1)
changed=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['changed'])")
assert "short prompt passthrough" "$changed" "False"

# ── Test 8: slash command passes through unchanged ────────────────────────────
output=$(HOME="$TMPHOME" "$OPTIMIZE" "/compact focus on the auth work" 2>&1)
changed=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['changed'])")
assert "slash command passthrough" "$changed" "False"

# ── Test 8b: XML/system payloads pass through unchanged ───────────────────────
output=$(HOME="$TMPHOME" "$OPTIMIZE" "<task-notification><status>completed</status></task-notification>" 2>&1)
changed=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['changed'])")
assert "XML payload passthrough" "$changed" "False"

# ── Test 9: kill switch SUPERAGENT_OPTIMIZE=0 ─────────────────────────────────
output=$(HOME="$TMPHOME" SUPERAGENT_OPTIMIZE=0 "$OPTIMIZE" "could you please add a login button" 2>&1)
opt=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['changed'], d['optimized']==d['original'])")
assert "kill switch disables rewrite" "$opt" "False True"

# ── Test 10: no args → usage error ────────────────────────────────────────────
rc=0
HOME="$TMPHOME" "$OPTIMIZE" >/dev/null 2>&1 || rc=$?
assert "no args exits 1" "$rc" "1"

# ── Test 11: optimization logged to ~/.superagent/brain/optimizations.jsonl ───
log="$TMPHOME/.superagent/brain/optimizations.jsonl"
[[ -f "$log" ]] && log_ok="yes" || log_ok="no"
assert "log file created" "$log_ok" "yes"
last=$(tail -1 "$log" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ts' in d and 'changed' in d)")
assert "log line shape" "$last" "True"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] || exit 1
