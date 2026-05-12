#!/usr/bin/env bash
# test/test-agents-files.sh — 5 specialist agents present and well-formed
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for name in architect coder reviewer security-architect tester; do
  f="$ROOT/agents/$name.md"
  [[ -f "$f" ]] || { echo "FAIL: $f missing"; exit 1; }
  grep -q "^name: $name" "$f" || { echo "FAIL: $f frontmatter name missing"; exit 1; }
  grep -q "^model: " "$f" || { echo "FAIL: $f model frontmatter missing"; exit 1; }
  grep -q "^tools: " "$f" || { echo "FAIL: $f tools frontmatter missing"; exit 1; }
  grep -q "^description: " "$f" || { echo "FAIL: $f description frontmatter missing"; exit 1; }
  grep -q "superagent-safety.py" "$f" || { echo "FAIL: $f missing scoped safety hook"; exit 1; }
done

echo "test-agents-files: PASS"
