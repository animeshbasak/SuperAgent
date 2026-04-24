#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent — Windsurf Installer
# Installs SuperAgent rules for Windsurf (Codeium)
# Usage: bash adapters/windsurf/install.sh [--project <path>]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }

TARGET="${PROJECT_DIR:-.}"

echo ""
echo -e "${CYAN}SuperAgent for Windsurf${NC}"
echo ""

info "Compiling skills for Windsurf..."
python3 "$REPO_ROOT/bin/superagent-compile" --platform windsurf \
  --output "$SCRIPT_DIR/templates/" 2>&1 | tail -3

# Install AGENTS.md at project root
cp "$SCRIPT_DIR/templates/AGENTS.md" "$TARGET/AGENTS.md"
ok "AGENTS.md installed at $TARGET/AGENTS.md"

# Install .windsurf/rules/
WINDSURF_RULES="$TARGET/.windsurf/rules"
mkdir -p "$WINDSURF_RULES"
cp "$SCRIPT_DIR/templates/rules/"*.md "$WINDSURF_RULES/" 2>/dev/null || true
ok "Rule files installed at $WINDSURF_RULES/"

# CLIs
for tool in superagent-classify superagent-chain superagent-cost superagent-learn; do
  src="$REPO_ROOT/bin/$tool"
  dst="$HOME/.local/bin/$tool"
  if [[ -f "$src" ]]; then
    mkdir -p "$HOME/.local/bin"
    cp "$src" "$dst" && chmod +x "$dst"
  fi
done
ok "CLIs installed"

echo ""
ok "SuperAgent for Windsurf installed!"
echo ""
