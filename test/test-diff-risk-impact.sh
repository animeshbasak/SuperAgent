#!/usr/bin/env bash
# test/test-diff-risk-impact.sh — IMPACT_KEYWORDS scoring + risk factor booleans
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-diff-risk"

# Critical: security + auth + payment = score >= 5
OUT=$("$BIN" impact --files "api/auth/login.ts,api/payments/stripe.ts,api/security/csrf.ts" \
                    --branch "feature/payments-flow" --diff-lines 100 --json)
echo "$OUT" | jq -e '.impact == "critical" and .score >= 5' >/dev/null \
  || { echo "FAIL: critical: $OUT"; exit 1; }
echo "$OUT" | jq -e '.risk_factors | map(.name) | index("security_paths") != null' >/dev/null \
  || { echo "FAIL: security_paths factor missing: $OUT"; exit 1; }

# High: api + database = score 4 → high
OUT=$("$BIN" impact --files "api/users.ts,database/migrations/001_init.sql" \
                    --branch "feature/users" --diff-lines 100 --json)
echo "$OUT" | jq -e '.impact == "high" and .score >= 3 and .score < 5' >/dev/null \
  || { echo "FAIL: high: $OUT"; exit 1; }
echo "$OUT" | jq -e '.risk_factors | map(.name) | index("db_migration") != null' >/dev/null \
  || { echo "FAIL: db_migration factor missing: $OUT"; exit 1; }

# Low: pure util + test
OUT=$("$BIN" impact --files "src/util/dates.ts,src/util/dates.test.ts" --branch "feat/dates" --diff-lines 30 --json)
echo "$OUT" | jq -e '.impact == "low" or .impact == "medium"' >/dev/null \
  || { echo "FAIL: low/medium: $OUT"; exit 1; }

# Large diff factor: >500 lines
OUT=$("$BIN" impact --files "src/x.ts" --branch "feat/big" --diff-lines 1000 --json)
echo "$OUT" | jq -e '.risk_factors | map(.name) | index("large_diff") != null' >/dev/null \
  || { echo "FAIL: large_diff factor not triggered: $OUT"; exit 1; }

# Cross-module factor: 3+ top-level dirs
OUT=$("$BIN" impact --files "api/a.ts,src/b.ts,docs/c.md,db/d.sql" --branch "feat/wide" --diff-lines 50 --json)
echo "$OUT" | jq -e '.risk_factors | map(.name) | index("cross_module") != null' >/dev/null \
  || { echo "FAIL: cross_module factor not triggered: $OUT"; exit 1; }

echo "test-diff-risk-impact: PASS"
