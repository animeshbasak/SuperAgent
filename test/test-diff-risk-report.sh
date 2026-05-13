#!/usr/bin/env bash
# test/test-diff-risk-report.sh — report composes classifier + impact + reviewers; caches last.json
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-diff-risk"

TMPHOME=$(mktemp -d)
TMPREPO=$(mktemp -d)
trap 'rm -rf "$TMPHOME" "$TMPREPO"' EXIT

# Bootstrap a tiny git repo with a security-touching diff
cd "$TMPREPO"
git init -q
git config user.email "test@example.com"
git config user.name "Test"
mkdir -p api/auth
echo "old" > api/auth/login.ts
git add . && git commit -qm "initial"
echo "new auth flow" > api/auth/login.ts
echo "payment route" > api/payments.ts
mkdir -p .github
cat > .github/CODEOWNERS <<'EOF'
/api/auth/ @sec-team
/api/payments* @payments-team
EOF
git add . && git commit -qm "feat: implement OAuth login + payment route"

OUT=$(HOME="$TMPHOME" "$BIN" report --base HEAD~1 --json)
echo "$OUT" | jq -e '.classification.primary == "feature"' >/dev/null \
  || { echo "FAIL: primary classification: $OUT"; exit 1; }
echo "$OUT" | jq -e '.impactReport.impact == "critical" or .impactReport.impact == "high"' >/dev/null \
  || { echo "FAIL: impact level: $OUT"; exit 1; }
echo "$OUT" | jq -e '.reviewers.owners | length >= 1' >/dev/null \
  || { echo "FAIL: no reviewers: $OUT"; exit 1; }

# Cache file written
[[ -f "$TMPHOME/.superagent/diff/last.json" ]] \
  || { echo "FAIL: last.json cache missing"; exit 1; }

# Human-readable output
OUT_HUMAN=$(HOME="$TMPHOME" "$BIN" report --base HEAD~1)
echo "$OUT_HUMAN" | grep -q "Diff Analysis:" || { echo "FAIL: human heading missing"; exit 1; }
echo "$OUT_HUMAN" | grep -qE "Suggested reviewers:" || { echo "FAIL: reviewers line missing"; exit 1; }

echo "test-diff-risk-report: PASS"
