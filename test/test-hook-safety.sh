#!/usr/bin/env bash
# test/test-hook-safety.sh — PreToolUse safety gate, incl. org-wide model policy
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-safety.py"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent"

pass=0; fail=0
ok()  { echo "  PASS  $1"; pass=$((pass + 1)); }
no()  { echo "  FAIL  $1"; echo "        $2"; fail=$((fail + 1)); }

# run_hook <bash-command> → prints "<exit_code>\t<permissionDecision>"
run_hook() {
  local cmd="$1" out rc dec
  out=$(printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$cmd")" \
        | HOME="$TMPHOME" python3 "$HOOK" 2>/dev/null) && rc=0 || rc=$?
  dec=$(echo "$out" | python3 -c "import sys,json;
try: print(json.load(sys.stdin)['hookSpecificOutput']['permissionDecision'])
except Exception: print('')" 2>/dev/null)
  echo "${rc}|${dec}"
}

echo "Running superagent-safety hook tests..."
echo ""

# ── baseline: safe command allowed, risky command asked ───────────────────────
r=$(run_hook "ls -la"); [[ "$r" == "0|allow" ]] && ok "safe command allowed" || no "safe command allowed" "$r"
r=$(run_hook "git push --force origin main"); [[ "$r" == "0|ask" ]] && ok "force-push asks" || no "force-push asks" "$r"

# ── no org policy → model selection is NOT gated ──────────────────────────────
r=$(run_hook "claude --model claude-opus-4-8 -p hi"); [[ "$r" == "0|allow" ]] \
  && ok "no policy: opus model allowed" || no "no policy: opus model allowed" "$r"

# ── set an org policy restricting tiers to local/haiku ────────────────────────
cat > "$TMPHOME/.superagent/org-policy.json" <<EOF
{"allowed_model_tiers":["local","haiku"]}
EOF

r=$(run_hook "claude --model claude-opus-4-8 -p hi"); [[ "$r" == "0|ask" ]] \
  && ok "policy: off-policy opus asks" || no "policy: off-policy opus asks" "$r"
r=$(run_hook "superagent-switch to opus"); [[ "$r" == "0|ask" ]] \
  && ok "policy: switch-to-opus asks" || no "policy: switch-to-opus asks" "$r"
r=$(run_hook "claude --model claude-haiku-4-5 -p hi"); [[ "$r" == "0|allow" ]] \
  && ok "policy: allowed haiku passes" || no "policy: allowed haiku passes" "$r"
r=$(run_hook "superagent-switch to ollama/qwen3"); [[ "$r" == "0|allow" ]] \
  && ok "policy: local model passes" || no "policy: local model passes" "$r"

# ── kill switch bypasses the model gate ───────────────────────────────────────
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"claude --model claude-opus-4-8"}}' \
      | HOME="$TMPHOME" SUPERAGENT_ORG_POLICY=off python3 "$HOOK" 2>/dev/null)
dec=$(echo "$out" | python3 -c "import sys,json;print(json.load(sys.stdin)['hookSpecificOutput']['permissionDecision'])")
[[ "$dec" == "allow" ]] && ok "kill switch bypasses model gate" || no "kill switch bypasses model gate" "$dec"

# ── reason names the off-policy tier ──────────────────────────────────────────
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"claude --model claude-opus-4-8"}}' \
      | HOME="$TMPHOME" python3 "$HOOK" 2>/dev/null)
echo "$out" | grep -qF "off-policy model" && ok "reason names off-policy model" || no "reason names off-policy model" "$out"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] || exit 1
