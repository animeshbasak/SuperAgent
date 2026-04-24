#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent — GitHub Copilot Installer
# Installs SuperAgent instructions for GitHub Copilot
# Usage: bash adapters/copilot/install.sh [--project <path>]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }

TARGET="${PROJECT_DIR:-.}"

echo ""
echo -e "${CYAN}SuperAgent for GitHub Copilot${NC}"
echo ""

info "Compiling skills for Copilot..."
python3 "$REPO_ROOT/bin/superagent-compile" --platform copilot \
  --output "$SCRIPT_DIR/templates/copilot-instructions.md" 2>&1 | tail -2

GITHUB_DIR="$TARGET/.github"
mkdir -p "$GITHUB_DIR"
cp "$SCRIPT_DIR/templates/copilot-instructions.md" "$GITHUB_DIR/copilot-instructions.md"
ok "Installed at $GITHUB_DIR/copilot-instructions.md"

echo ""
ok "SuperAgent for GitHub Copilot installed!"
echo ""
