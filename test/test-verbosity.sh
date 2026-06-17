#!/usr/bin/env bash
# test/test-verbosity.sh — smoke tests for superagent-verbosity

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-verbosity"

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

pass=0
fail=0

assert() {
  local desc="$1" result="$2" expected="$3"
  if [[ "$result" == "$expected" ]]; then
    echo "  PASS  $desc"; pass=$((pass + 1))
  else
    echo "  FAIL  $desc"
    echo "        expected: $expected"
    echo "        got:      $result"
    fail=$((fail + 1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS  $desc"; pass=$((pass + 1))
  else
    echo "  FAIL  $desc"
    echo "        expected to contain: $needle"
    echo "        got: $haystack"
    fail=$((fail + 1))
  fi
}

assert_not_empty() {
  local desc="$1" value="$2"
  if [[ -n "$value" ]]; then
    echo "  PASS  $desc"; pass=$((pass + 1))
  else
    echo "  FAIL  $desc (expected non-empty, got empty)"
    fail=$((fail + 1))
  fi
}

assert_empty() {
  local desc="$1" value="$2"
  if [[ -z "$value" ]]; then
    echo "  PASS  $desc"; pass=$((pass + 1))
  else
    echo "  FAIL  $desc"
    echo "        expected empty, got: $value"
    fail=$((fail + 1))
  fi
}

# ── fixtures ──────────────────────────────────────────────────────────────────
# High halt_rate fixture: 8 records, 6 halts/fails → halt_rate = 0.75 → level = round(5*0.25) = 1
HIGH_HALT="$TMPDIR_WORK/high_halt.jsonl"
cat > "$HIGH_HALT" <<'EOF'
{"ts":"2026-01-01T00:00:00+00:00","task":"t1","outcome":"halt"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t2","outcome":"halt"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t3","outcome":"fail"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t4","outcome":"halt"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t5","outcome":"fail"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t6","outcome":"halt"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t7","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t8","outcome":"done"}
EOF

# Low halt_rate fixture: 10 records, 0 halts → halt_rate = 0.0 → level = round(5*1.0) = 5
LOW_HALT="$TMPDIR_WORK/low_halt.jsonl"
cat > "$LOW_HALT" <<'EOF'
{"ts":"2026-01-01T00:00:00+00:00","task":"t1","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t2","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t3","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t4","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t5","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t6","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t7","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t8","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t9","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t10","outcome":"done"}
EOF

# Sparse fixture: only 3 records → volume < 5 → level = 3 (neutral)
SPARSE="$TMPDIR_WORK/sparse.jsonl"
cat > "$SPARSE" <<'EOF'
{"ts":"2026-01-01T00:00:00+00:00","task":"t1","outcome":"halt"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t2","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t3","outcome":"done"}
EOF

# Corrupt fixture: one bad JSON line surrounded by valid lines
CORRUPT="$TMPDIR_WORK/corrupt.jsonl"
cat > "$CORRUPT" <<'EOF'
{"ts":"2026-01-01T00:00:00+00:00","task":"t1","outcome":"done"}
THIS IS NOT JSON {{{ GARBAGE
{"ts":"2026-01-01T00:00:00+00:00","task":"t2","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t3","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t4","outcome":"done"}
{"ts":"2026-01-01T00:00:00+00:00","task":"t5","outcome":"done"}
EOF

MISSING="$TMPDIR_WORK/does_not_exist.jsonl"

echo "Running superagent-verbosity smoke tests..."
echo ""

# ── Test 1: recommend returns valid JSON with level key ───────────────────────
out=$(python3 "$BIN" recommend --routes "$HIGH_HALT" 2>&1)
level=$(echo "$out" | python3 -c "import sys,json; print(json.load(sys.stdin)['level'])")
assert_contains "recommend output has 'level' key" "$out" '"level"'

# ── Test 2: level is in valid range 0–5 ───────────────────────────────────────
valid=$(python3 -c "print('yes' if 0 <= $level <= 5 else 'no')")
assert "recommend level in range 0-5" "$valid" "yes"

# ── Test 3: high halt_rate → low level ────────────────────────────────────────
high_level=$(python3 "$BIN" recommend --routes "$HIGH_HALT" | python3 -c "import sys,json; print(json.load(sys.stdin)['level'])")
low_level=$(python3 "$BIN" recommend --routes "$LOW_HALT" | python3 -c "import sys,json; print(json.load(sys.stdin)['level'])")
cmp=$(python3 -c "print('yes' if $high_level < $low_level else 'no')")
assert "high halt_rate yields lower level than low halt_rate" "$cmp" "yes"

# ── Test 4: empty routes file → neutral level 3 ───────────────────────────────
EMPTY_ROUTES="$TMPDIR_WORK/empty.jsonl"
touch "$EMPTY_ROUTES"
empty_level=$(python3 "$BIN" recommend --routes "$EMPTY_ROUTES" | python3 -c "import sys,json; print(json.load(sys.stdin)['level'])")
assert "empty routes file → level 3 (neutral)" "$empty_level" "3"

# ── Test 5: missing routes file → neutral level 3 ────────────────────────────
missing_level=$(python3 "$BIN" recommend --routes "$MISSING" | python3 -c "import sys,json; print(json.load(sys.stdin)['level'])")
assert "missing routes file → level 3 (neutral)" "$missing_level" "3"

# ── Test 6: sparse history → neutral level 3 ─────────────────────────────────
sparse_level=$(python3 "$BIN" recommend --routes "$SPARSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['level'])")
assert "sparse history → level 3 (neutral)" "$sparse_level" "3"

# ── Test 7: recommend output has signals and rationale keys ───────────────────
rec_out=$(python3 "$BIN" recommend --routes "$HIGH_HALT")
keys=$(echo "$rec_out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(sorted(d.keys())))")
assert "recommend JSON has expected keys" "$keys" "level,rationale,signals"

# ── Test 8: note for level 0 is non-empty ────────────────────────────────────
note0=$(python3 "$BIN" note --level 0)
assert_not_empty "note for level 0 is non-empty" "$note0"

# ── Test 9: note for level 5 is empty ────────────────────────────────────────
note5=$(python3 "$BIN" note --level 5)
assert_empty "note for level 5 is empty" "$note5"

# ── Test 10: stats returns expected JSON keys ─────────────────────────────────
stats_out=$(python3 "$BIN" stats --routes "$HIGH_HALT")
stats_keys=$(echo "$stats_out" | python3 -c "import sys,json; print(','.join(sorted(json.load(sys.stdin).keys())))")
assert "stats JSON has expected keys" "$stats_keys" "halt_rate,recommended_level,total_records"

# ── Test 11: stats total_records matches fixture ──────────────────────────────
stats_total=$(echo "$stats_out" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_records'])")
assert "stats total_records for high_halt fixture" "$stats_total" "8"

# ── Test 12: corrupt JSON line is skipped, not fatal ─────────────────────────
corrupt_rc=0
corrupt_out=$(python3 "$BIN" stats --routes "$CORRUPT" 2>&1) || corrupt_rc=$?
assert "corrupt routes file exits 0" "$corrupt_rc" "0"
# 5 valid records (1 bad skipped), 0 halts → level 5
corrupt_total=$(echo "$corrupt_out" | python3 -c "import sys,json; print(json.load(sys.stdin)['total_records'])")
assert "corrupt file: valid records counted (bad line skipped)" "$corrupt_total" "5"

# ── Test 13: unknown subcommand exits 2 ───────────────────────────────────────
bad_rc=0
python3 "$BIN" badsubcommand 2>/dev/null || bad_rc=$?
assert "unknown subcommand exits 2" "$bad_rc" "2"

# ── Test 14: no subcommand exits 2 ───────────────────────────────────────────
no_sub_rc=0
python3 "$BIN" 2>/dev/null || no_sub_rc=$?
assert "no subcommand exits 2" "$no_sub_rc" "2"

# ── Test 15: note without --level uses routes to compute (non-crash) ─────────
note_auto=$(python3 "$BIN" note --routes "$LOW_HALT" 2>&1)
note_auto_rc=$?
assert "note without --level exits 0" "$note_auto_rc" "0"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] || exit 1
