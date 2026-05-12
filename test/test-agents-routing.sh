#!/usr/bin/env bash
# test/test-agents-routing.sh — classifier emits specialist agent ref on trigger phrases
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CBIN="$SCRIPT_DIR/../bin/superagent-classify"

declare -a CASES=(
  "threat-model the auth flow|agent:security-architect"
  "write unit tests for the billing prorate function|agent:tester"
  "review this diff for safety|agent:reviewer"
  "implement the new webhook endpoint|agent:coder"
  "design the API for the comments service|agent:architect"
)

for case in "${CASES[@]}"; do
  prompt="${case%|*}"
  want="${case#*|}"
  OUT=$("$CBIN" "$prompt")
  echo "$OUT" | jq -e --arg w "$want" '.chain | index($w) != null' >/dev/null \
    || { echo "FAIL: '$prompt' → $OUT (want '$want' in chain)"; exit 1; }
done

echo "test-agents-routing: PASS"
