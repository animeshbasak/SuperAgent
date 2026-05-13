#!/usr/bin/env bash
# test/test-diff-risk-reviewers.sh — CODEOWNERS parsing returns matching owners
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-diff-risk"
CO="$SCRIPT_DIR/fixtures/diff-risk/CODEOWNERS"

# auth + payments paths → @sec-team + @api-leads + @payments-team
OUT=$("$BIN" reviewers --files "api/auth/login.ts,api/payments/stripe.ts" --codeowners "$CO" --json)
echo "$OUT" | jq -e '.owners | index("@sec-team") != null and index("@payments-team") != null' >/dev/null \
  || { echo "FAIL: sec/payments owners: $OUT"; exit 1; }

# Markdown → @docs-team
OUT=$("$BIN" reviewers --files "README.md,docs/x.md" --codeowners "$CO" --json)
echo "$OUT" | jq -e '.owners | index("@docs-team") != null' >/dev/null \
  || { echo "FAIL: docs owner: $OUT"; exit 1; }

# Theme dir → @design-team + @frontend-leads
OUT=$("$BIN" reviewers --files "src/theme/Toggle.tsx" --codeowners "$CO" --json)
echo "$OUT" | jq -e '.owners | index("@design-team") != null' >/dev/null \
  || { echo "FAIL: design-team owner: $OUT"; exit 1; }

# No CODEOWNERS file → empty owners
OUT=$("$BIN" reviewers --files "anything.ts" --codeowners "/nonexistent/path" --json)
echo "$OUT" | jq -e '.owners | length == 0' >/dev/null \
  || { echo "FAIL: missing CODEOWNERS: $OUT"; exit 1; }

echo "test-diff-risk-reviewers: PASS"
