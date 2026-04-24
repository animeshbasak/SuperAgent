#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent — Aider Installer
# Installs SuperAgent conventions for Aider
# Usage: bash adapters/aider/install.sh [--project <path>]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }

TARGET="${PROJECT_DIR:-.}"

echo ""
echo -e "${CYAN}SuperAgent for Aider${NC}"
echo ""

info "Compiling skills for Aider..."
python3 "$REPO_ROOT/bin/superagent-compile" --platform aider \
  --output "$SCRIPT_DIR/templates/" 2>&1 | tail -3

cp "$SCRIPT_DIR/templates/CONVENTIONS.md" "$TARGET/CONVENTIONS.md"
ok "CONVENTIONS.md installed at $TARGET/"

if [[ ! -f "$TARGET/.aider.conf.yml" ]]; then
  cp "$SCRIPT_DIR/templates/.aider.conf.yml" "$TARGET/.aider.conf.yml"
  ok ".aider.conf.yml installed"
else
  if ! grep -q "CONVENTIONS.md" "$TARGET/.aider.conf.yml"; then
    echo "read: CONVENTIONS.md" >> "$TARGET/.aider.conf.yml"
    ok "Added CONVENTIONS.md to existing .aider.conf.yml"
  fi
fi

echo ""
ok "SuperAgent for Aider installed!"
echo ""
