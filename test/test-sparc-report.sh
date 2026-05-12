#!/usr/bin/env bash
# test/test-sparc-report.sh — traceability matrix output
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-sparc"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT

HOME="$TMPHOME" "$BIN" init feat-rep >/dev/null
DIR="$TMPHOME/.superagent/sparc/feat-rep"

cat > "$DIR/spec.md" <<EOF
# Spec
- AC: ac-one    — first criterion
- AC: ac-two    — second criterion
- AC: ac-three  — third criterion
EOF

cat > "$DIR/pseudo.md" <<EOF
covers ac-one and ac-two only.
EOF

cat > "$DIR/arch.md" <<EOF
function impl_ac_one() {}
function impl_ac_two() {}
function impl_ac_three() {}
EOF

cat > "$DIR/refine.md" <<EOF
it('ac-one happy path')
it('ac-two error path')
EOF

OUT=$(HOME="$TMPHOME" "$BIN" report)
echo "$OUT" | grep -q "Traceability Matrix" || { echo "FAIL: heading missing"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "ac-one" || { echo "FAIL: ac-one row missing"; exit 1; }
echo "$OUT" | grep -q "ac-three" || { echo "FAIL: ac-three row missing"; exit 1; }
# ac-three is only in arch.md → status should be ✗
echo "$OUT" | grep "ac-three" | grep -q "✗" || { echo "FAIL: ac-three should be incomplete"; exit 1; }
# ac-one appears in pseudo+arch+refine → status ✓
echo "$OUT" | grep "ac-one" | grep -q "✓" || { echo "FAIL: ac-one should be complete"; exit 1; }

echo "test-sparc-report: PASS"
