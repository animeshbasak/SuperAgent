#!/usr/bin/env bash
# Smoke test for safety invariant: distill hook MUST NOT touch CLAUDE.md
set -eu

HOOK="./hooks/superagent-distill.sh"
[[ -x "$HOOK" ]] || { echo "FAIL: hook not executable"; exit 1; }

TMP_TRANSCRIPT=$(mktemp)
trap 'rm -f "$TMP_TRANSCRIPT" CLAUDE.md.superagent-proposed' EXIT

cat > "$TMP_TRANSCRIPT" <<'EOF'
{"role":"user","content":"no, don't use mocks in these tests"}
{"role":"assistant","content":"got it"}
EOF

BEFORE_HASH=""
[[ -f CLAUDE.md ]] && BEFORE_HASH=$(shasum -a 256 CLAUDE.md | cut -d' ' -f1)

echo "{\"transcript_path\":\"$TMP_TRANSCRIPT\"}" | bash "$HOOK"

AFTER_HASH=""
[[ -f CLAUDE.md ]] && AFTER_HASH=$(shasum -a 256 CLAUDE.md | cut -d' ' -f1)

if [[ "$BEFORE_HASH" != "$AFTER_HASH" ]]; then
  echo "FAIL: CLAUDE.md mutated"
  exit 1
fi

if [[ ! -f CLAUDE.md.superagent-proposed ]]; then
  echo "FAIL: no proposal file written"
  exit 1
fi

if ! grep -q "don't use mocks" CLAUDE.md.superagent-proposed; then
  echo "FAIL: proposal missing correction"
  exit 1
fi

LEARN_ROOT="$HOME/.superagent/learnings"
PROJECT_HASH=$(printf '%s' "$PWD" | shasum -a 256 | cut -c1-12)
LEARN_FILE="$LEARN_ROOT/$PROJECT_HASH.jsonl"
if [[ ! -f "$LEARN_FILE" ]] || ! grep -q "don't use mocks" "$LEARN_FILE"; then
  echo "FAIL: learnings jsonl missing entry"
  exit 1
fi

echo "PASS: 4 invariants held"
