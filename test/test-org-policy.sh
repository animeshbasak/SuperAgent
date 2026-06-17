#!/usr/bin/env bash
# test/test-org-policy.sh — smoke tests for superagent-org-policy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OP="$SCRIPT_DIR/../bin/superagent-org-policy"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"

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
    echo "  FAIL  $desc"; echo "        expected to contain: $needle"
    fail=$((fail + 1))
  fi
}

echo "Running superagent-org-policy smoke tests..."
echo ""

# ── Test 1: no policy by default ──────────────────────────────────────────────
out=$("$OP" show 2>&1)
assert_contains "show says no policy when unset" "$out" "No organisation policy"

# ── Test 2: set writes a persistent file ──────────────────────────────────────
"$OP" set --budget 200 --tiers local,haiku --redact on >/dev/null
[[ -s "$TMPHOME/.superagent/org-policy.json" ]] && wrote=yes || wrote=no
assert "set persists org-policy.json" "$wrote" "yes"

# ── Test 3: stored values round-trip via --json ───────────────────────────────
budget=$("$OP" show --json | python3 -c "import sys,json; print(json.load(sys.stdin)['monthly_budget_usd'])")
assert "budget persisted" "$budget" "200.0"
tiers=$("$OP" show --json | python3 -c "import sys,json; print(','.join(json.load(sys.stdin)['allowed_model_tiers']))")
assert "tiers persisted" "$tiers" "local,haiku"
redact=$("$OP" show --json | python3 -c "import sys,json; print(json.load(sys.stdin)['redact_projects'])")
assert "redact persisted" "$redact" "True"

# ── Test 4: check passes for an allowed tier ──────────────────────────────────
rc=0; "$OP" check --model "ollama/qwen3" >/dev/null 2>&1 || rc=$?
assert "allowed local model passes (exit 0)" "$rc" "0"
rc=0; "$OP" check --model "claude-haiku-4-5" >/dev/null 2>&1 || rc=$?
assert "allowed haiku passes (exit 0)" "$rc" "0"

# ── Test 5: check blocks an off-policy tier (exit 3 + reason) ──────────────────
rc=0; err=$("$OP" check --model "claude-opus-4-8" 2>&1) || rc=$?
assert "off-policy opus blocked (exit 3)" "$rc" "3"
assert_contains "block reason names the tier" "$err" "off-policy"

# ── Test 6: explicit --tier form ──────────────────────────────────────────────
rc=0; "$OP" check --tier sonnet >/dev/null 2>&1 || rc=$?
assert "off-policy sonnet blocked via --tier" "$rc" "3"

# ── Test 7: kill switch lets everything pass ──────────────────────────────────
rc=0; SUPERAGENT_ORG_POLICY=off "$OP" check --model "claude-opus-4-8" >/dev/null 2>&1 || rc=$?
assert "kill switch bypasses check" "$rc" "0"

# ── Test 8: no tier restriction → all models allowed ──────────────────────────
"$OP" set --clear >/dev/null
"$OP" set --budget 50 >/dev/null   # budget only, no tiers
rc=0; "$OP" check --model "claude-opus-4-8" >/dev/null 2>&1 || rc=$?
assert "no tier restriction allows any model" "$rc" "0"

# ── Test 9: bad tier name rejected (exit 2) ───────────────────────────────────
rc=0; "$OP" set --tiers local,nope >/dev/null 2>&1 || rc=$?
assert "unknown tier rejected (exit 2)" "$rc" "2"

# ── Test 10: --clear empties the policy ───────────────────────────────────────
"$OP" set --clear >/dev/null
out=$("$OP" show 2>&1)
assert_contains "clear resets to no policy" "$out" "No organisation policy"

# ── Test 11: unknown subcommand exits 2 ───────────────────────────────────────
rc=0; "$OP" bogus >/dev/null 2>&1 || rc=$?
assert "unknown subcommand exits 2" "$rc" "2"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] || exit 1
