#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent — Cursor Installer
# Installs SuperAgent .mdc rule files for Cursor AI
# Usage: bash adapters/cursor/install.sh [--project <path>]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }

# Parse --project flag
TARGET="${PROJECT_DIR:-.}"
for i in "$@"; do
  case "$i" in
    --project) shift; TARGET="${1:-.}"; shift ;;
  esac
done

echo ""
echo -e "${CYAN}SuperAgent for Cursor${NC}"
echo ""

# ── Step 1: Compile latest skills ──────────────────────────────────────────
info "Compiling skills for Cursor (compact format)..."
python3 "$REPO_ROOT/bin/superagent-compile" --platform cursor \
  --output "$SCRIPT_DIR/templates/" 2>&1 | tail -3

# ── Step 2: Install .mdc files into project ────────────────────────────────
CURSOR_RULES="$TARGET/.cursor/rules"
mkdir -p "$CURSOR_RULES"

for mdc in "$SCRIPT_DIR/templates/"*.mdc; do
  cp "$mdc" "$CURSOR_RULES/"
  ok "Rule: $(basename "$mdc")"
done

# Count total chars
TOTAL_CHARS=0
for mdc in "$CURSOR_RULES/"*.mdc; do
  CHARS=$(wc -c < "$mdc" | tr -d ' ')
  TOTAL_CHARS=$((TOTAL_CHARS + CHARS))
done

if [[ "$TOTAL_CHARS" -gt 12000 ]]; then
  warn "Total: ${TOTAL_CHARS} chars (exceeds Cursor 12k limit — only core is always-apply)"
else
  ok "Total: ${TOTAL_CHARS} chars (under 12k limit)"
fi

echo ""
ok "SuperAgent for Cursor installed!"
echo "  Rules: $CURSOR_RULES/"
echo "  Note: superagent-core.mdc is always-apply, others are agent-requested"
echo ""
