#!/usr/bin/env bash
# test/test-canary.sh — verify superagent-switch canary fires the 3-step probe and parses responses.
#
# Phase 1: mock proxy returns the expected tool-call shape for all 3 steps; assert exit 0.
# Phase 2: mock proxy returns malformed response on step 2; assert exit non-zero.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCH="$SCRIPT_DIR/../bin/superagent-switch"
FIXTURES="$SCRIPT_DIR/canary-fixtures"

pass=0
fail=0

assert_eq() {
  local desc="$1" got="$2" expected="$3"
  if [[ "$got" == "$expected" ]]; then
    echo "  PASS  $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL  $desc — got:[$got] expected:[$expected]"
    fail=$((fail + 1))
  fi
}

PORT=18082
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"; if [[ -n "${MOCK_PID:-}" ]]; then kill "$MOCK_PID" 2>/dev/null || true; fi' EXIT

# ── Phase 1: happy-path mock ─────────────────────────────────────────────────
cat > "$MOCK_DIR/mock_ok.py" <<PY
import http.server, json, sys

PORT = int(sys.argv[1])

class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0"))
        try:
            req = json.loads(self.rfile.read(n))
        except Exception:
            req = {}
        # echo back the expected tool name as a successful tool-call
        tool = req.get("expected") or "Bash"
        body = json.dumps({"tool": tool, "ok": True}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a, **k): pass

http.server.HTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY

# Start mock
python3 "$MOCK_DIR/mock_ok.py" $PORT &
MOCK_PID=$!

# Wait for port
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS --max-time 1 -X POST -H "Content-Type: application/json" \
       -d '{"expected":"Read"}' "http://localhost:$PORT/v1/messages" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

echo "Phase 1: happy-path mock"
SUPERAGENT_PROXY_URL="http://localhost:$PORT" \
SUPERAGENT_CANARY_FIXTURES="$FIXTURES" \
  "$SWITCH" canary mock-model --depth=3
rc1=$?
assert_eq "canary exit code is 0 with happy-path mock" "$rc1" "0"

# Verify canary-last.json was written w/ ok=true
CANARY_FILE="$HOME/.superagent/canary-last.json"
if [[ -f "$CANARY_FILE" ]]; then
  ok=$(jq -r '.ok' "$CANARY_FILE")
  pass_count=$(jq -r '.pass' "$CANARY_FILE")
  assert_eq "canary-last.json ok=true" "$ok" "true"
  assert_eq "canary-last.json pass=3" "$pass_count" "3"
fi

kill "$MOCK_PID" 2>/dev/null || true
wait "$MOCK_PID" 2>/dev/null || true
MOCK_PID=""
sleep 0.5

# ── Phase 2: malformed-on-step-2 mock ────────────────────────────────────────
cat > "$MOCK_DIR/mock_bad.py" <<PY
import http.server, json, sys

PORT = int(sys.argv[1])
COUNT = {"n": 0}

class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0"))
        try:
            req = json.loads(self.rfile.read(n))
        except Exception:
            req = {}
        COUNT["n"] += 1
        if COUNT["n"] == 2:
            # malformed: not JSON
            body = b"<<<not-json>>>"
        else:
            tool = req.get("expected") or "Bash"
            body = json.dumps({"tool": tool, "ok": True}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a, **k): pass

http.server.HTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY

python3 "$MOCK_DIR/mock_bad.py" $PORT &
MOCK_PID=$!

for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS --max-time 1 -X POST -H "Content-Type: application/json" \
       -d '{"expected":"Read"}' "http://localhost:$PORT/v1/messages" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

echo ""
echo "Phase 2: malformed-on-step-2 mock"
set +e
SUPERAGENT_PROXY_URL="http://localhost:$PORT" \
SUPERAGENT_CANARY_FIXTURES="$FIXTURES" \
  "$SWITCH" canary mock-model --depth=3
rc2=$?
set -e

if [[ "$rc2" -ne 0 ]]; then
  echo "  PASS  canary exits non-zero on malformed step"
  pass=$((pass + 1))
else
  echo "  FAIL  canary should have exited non-zero (got 0)"
  fail=$((fail + 1))
fi

kill "$MOCK_PID" 2>/dev/null || true
wait "$MOCK_PID" 2>/dev/null || true
MOCK_PID=""

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Tests: $((pass + fail))   PASS: $pass   FAIL: $fail"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ $fail -eq 0 ]]
