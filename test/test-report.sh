#!/usr/bin/env bash
# test/test-report.sh — smoke tests for superagent-report (org-pilot report)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT="$SCRIPT_DIR/../bin/superagent-report"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT

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
    fail=$((fail + 1))
  fi
}

# ── fixtures ──────────────────────────────────────────────────────────────────
mkdir -p "$TMPHOME/.superagent/cost" "$TMPHOME/.superagent/brain" "$TMPHOME/.claude"

NOW_ISO=$(python3 -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).isoformat())")
OLD_ISO="2025-01-01T00:00:00+00:00"

cat > "$TMPHOME/.superagent/cost/calls.jsonl" <<EOF
{"ts":"$NOW_ISO","project":"p1","tool":"bash","tokens":1000000,"model":"claude-opus-4-8"}
{"ts":"$NOW_ISO","project":"p1","tool":"bash","model":"ollama/qwen3","input_tokens":500000,"output_tokens":0,"cache_write_tokens":0,"cache_read_tokens":0}
{"ts":"$OLD_ISO","project":"p1","tool":"bash","tokens":9000000,"model":"claude-opus-4-8"}
EOF

cat > "$TMPHOME/.superagent/brain/routes.jsonl" <<EOF
{"ts":"$NOW_ISO","task_hash":"a","task":"t1","chain":["review","ship"],"outcome":"done","backend":"anthropic","optimized":true}
{"ts":"$NOW_ISO","task_hash":"b","task":"t2","chain":["investigate","verification-before-completion"],"outcome":"done","backend":"anthropic","optimized":false}
{"ts":"$NOW_ISO","task_hash":"c","task":"t3","chain":["ship"],"outcome":"fail","backend":"local","optimized":true}
EOF

cat > "$TMPHOME/.superagent/brain/optimizations.jsonl" <<EOF
{"ts":"$NOW_ISO","prompt_hash":"x","changed":true,"notes":["stripped leading filler"]}
{"ts":"$NOW_ISO","prompt_hash":"y","changed":false,"notes":["passthrough (slash command, markup, or too short)"]}
EOF

cat > "$TMPHOME/.claude/superagent-stats.json" <<EOF
{"version":1,"projects":{"p1":{"lifetime":{"mempalace_hits":10,"mempalace_tokens_saved":5000,"graphify_queries":4,"graphify_tokens_saved":2000,"total_saved":7000},"sessions":[]}}}
EOF

echo "Running superagent-report smoke tests..."
echo ""

# ── Test 1: markdown report renders with section headers ─────────────────────
out=$(HOME="$TMPHOME" "$REPORT" 2>&1)
assert_contains "header present" "$out" "SuperAgent Pilot Report"
assert_contains "spend section" "$out" "## Spend"
assert_contains "savings section" "$out" "## Savings (measured)"
assert_contains "reliability section" "$out" "## Reliability"

# ── Test 2: --json emits valid JSON with expected keys ────────────────────────
out=$(HOME="$TMPHOME" "$REPORT" --json 2>&1)
keys=$(echo "$out" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(sorted(d.keys())))")
assert "json top-level keys" "$keys" "generated_at,period_days,reliability,savings,spend"

# ── Test 3: spend totals correct (old record excluded by default 30d) ─────────
tokens=$(echo "$out" | python3 -c "import sys,json; print(json.load(sys.stdin)['spend']['total_tokens'])")
assert "30d token total excludes old record" "$tokens" "1500000"

# ── Test 4: usd math matches pricing (1M opus v1 @ \$15/M input rate) ──────────
usd=$(echo "$out" | python3 -c "import sys,json; print(round(json.load(sys.stdin)['spend']['total_usd'],2))")
assert "usd total (opus 1M v1 input-rate, local free)" "$usd" "15.0"

# ── Test 5: local share counted ───────────────────────────────────────────────
local_calls=$(echo "$out" | python3 -c "import sys,json; print(json.load(sys.stdin)['spend']['local_calls'])")
assert "local call counted" "$local_calls" "1"

# ── Test 6: reliability outcome rates ─────────────────────────────────────────
done_n=$(echo "$out" | python3 -c "import sys,json; r=json.load(sys.stdin)['reliability']; print(r['routes_total'], r['routes_done'], r['verified_routes'])")
assert "route counts + verification gate count" "$done_n" "3 2 1"

# ── Test 7: optimization stats ────────────────────────────────────────────────
opt=$(echo "$out" | python3 -c "import sys,json; s=json.load(sys.stdin)['savings']; print(s['prompts_optimized'], s['prompts_seen'])")
assert "optimization counts" "$opt" "1 2"

# ── Test 8: memory savings surfaced ───────────────────────────────────────────
mem=$(echo "$out" | python3 -c "import sys,json; print(json.load(sys.stdin)['savings']['memory_tokens_saved'])")
assert "memory tokens saved" "$mem" "7000"

# ── Test 9: --days widens the window ──────────────────────────────────────────
tokens=$(HOME="$TMPHOME" "$REPORT" --json --days 10000 | python3 -c "import sys,json; print(json.load(sys.stdin)['spend']['total_tokens'])")
assert "--days 10000 includes old record" "$tokens" "10500000"

# ── Test 10: missing files degrade gracefully ─────────────────────────────────
EMPTYHOME=$(mktemp -d)
out=$(HOME="$EMPTYHOME" "$REPORT" 2>&1); rc=$?
rm -rf "$EMPTYHOME"
assert "empty home exit 0" "$rc" "0"
assert_contains "empty home says no data" "$out" "no data"

# ── Test 11: --out writes file ────────────────────────────────────────────────
HOME="$TMPHOME" "$REPORT" --out "$TMPHOME/report.md" >/dev/null
[[ -s "$TMPHOME/report.md" ]] && wrote="yes" || wrote="no"
assert "--out writes file" "$wrote" "yes"

# ── Test 12: bad flag exits 1 ─────────────────────────────────────────────────
rc=0
HOME="$TMPHOME" "$REPORT" --bogus >/dev/null 2>&1 || rc=$?
assert "bad flag exits 1" "$rc" "1"

# ── Test 13: --org-policy adds a compliance section ───────────────────────────
cat > "$TMPHOME/.superagent/org-policy.json" <<EOF
{"monthly_budget_usd":10,"allowed_model_tiers":["local","haiku"],"redact_projects":true}
EOF
out=$(HOME="$TMPHOME" "$REPORT" --org-policy 2>&1)
assert_contains "org-policy section present" "$out" "## Organisation policy"
assert_contains "over-budget flagged (15.00 > 10)" "$out" "OVER BUDGET"
assert_contains "off-policy opus call flagged" "$out" "off-policy"

# ── Test 14: --org-policy json carries compliance numbers ─────────────────────
out=$(HOME="$TMPHOME" "$REPORT" --org-policy --json 2>&1)
viol=$(echo "$out" | python3 -c "import sys,json; print(json.load(sys.stdin)['org_policy']['violations'])")
assert "violations counted (over-budget + 1 off-policy call)" "$viol" "2"
over=$(echo "$out" | python3 -c "import sys,json; print(json.load(sys.stdin)['org_policy']['over_budget'])")
assert "over_budget true" "$over" "True"

# ── Test 15: redaction anonymizes project identifiers ─────────────────────────
out=$(HOME="$TMPHOME" "$REPORT" --org-policy 2>&1)
assert_contains "project redacted to alias" "$out" "project-1"
if echo "$out" | grep -qF "p1"; then redacted=leaked; else redacted=clean; fi
assert "raw project name not present when redacted" "$redacted" "clean"

# ── Test 16: default run still omits org-policy section ────────────────────────
out=$(HOME="$TMPHOME" "$REPORT" 2>&1)
if echo "$out" | grep -qF "## Organisation policy"; then leak=yes; else leak=no; fi
assert "no org-policy section without the flag" "$leak" "no"

# ── Test 17: --org-policy with no policy file says so, exit 0 ──────────────────
EMPTYHOME=$(mktemp -d)
out=$(HOME="$EMPTYHOME" "$REPORT" --org-policy 2>&1); rc=$?
rm -rf "$EMPTYHOME"
assert "empty-policy run exits 0" "$rc" "0"
assert_contains "empty policy explains how to set one" "$out" "no organisation policy configured"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] || exit 1
