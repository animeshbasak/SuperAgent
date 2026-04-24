#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent — Continue.dev Installer
# Installs SuperAgent rules for Continue.dev
# Usage: bash adapters/continue/install.sh [--project <path>]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }

TARGET="${PROJECT_DIR:-.}"

echo ""
echo -e "${CYAN}SuperAgent for Continue.dev${NC}"
echo ""

info "Compiling skills for Continue.dev..."
python3 "$REPO_ROOT/bin/superagent-compile" --platform continue \
  --output "$SCRIPT_DIR/templates/rules/" 2>&1 | tail -2

CONTINUE_RULES="$TARGET/.continue/rules"
mkdir -p "$CONTINUE_RULES"
cp "$SCRIPT_DIR/templates/rules/"*.md "$CONTINUE_RULES/"
ok "Rules installed at $CONTINUE_RULES/"

echo ""
ok "SuperAgent for Continue.dev installed!"
echo ""
