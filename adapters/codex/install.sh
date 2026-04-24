#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent — Codex CLI Installer
# Installs SuperAgent instructions + CLI tools for OpenAI Codex CLI
# Usage: bash adapters/codex/install.sh [--project-only]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }

PROJECT_ONLY=0
for a in "$@"; do [[ "$a" == "--project-only" ]] && PROJECT_ONLY=1; done

echo ""
echo -e "${CYAN}SuperAgent for Codex CLI${NC}"
echo ""

# ── Step 1: Compile latest skills ──────────────────────────────────────────
info "Compiling skills for Codex..."
python3 "$REPO_ROOT/bin/superagent-compile" --platform codex \
  --output "$SCRIPT_DIR/templates/AGENTS.md" 2>&1 | tail -2

# ── Step 2: Install global AGENTS.md ───────────────────────────────────────
if [[ "$PROJECT_ONLY" != "1" ]]; then
  CODEX_DIR="$HOME/.codex"
  mkdir -p "$CODEX_DIR"
  cp "$SCRIPT_DIR/templates/AGENTS.md" "$CODEX_DIR/AGENTS.md"
  ok "Global AGENTS.md installed at ~/.codex/AGENTS.md"
fi

# ── Step 3: Install project AGENTS.md ─────────────────────────────────────
if [[ -n "${PROJECT_DIR:-}" ]]; then
  cp "$SCRIPT_DIR/templates/AGENTS.md" "$PROJECT_DIR/AGENTS.md"
  ok "Project AGENTS.md installed at $PROJECT_DIR/AGENTS.md"
fi

# ── Step 4: Install CLI tools ─────────────────────────────────────────────
info "Installing SuperAgent CLIs..."
for tool in superagent-classify superagent-chain superagent-cost superagent-learn; do
  src="$REPO_ROOT/bin/$tool"
  dst="$HOME/.local/bin/$tool"
  if [[ -f "$src" ]]; then
    mkdir -p "$HOME/.local/bin"
    cp "$src" "$dst"
    chmod +x "$dst"
    ok "CLI: $tool"
  fi
done

echo ""
ok "SuperAgent for Codex CLI installed!"
echo "  Global: ~/.codex/AGENTS.md"
echo "  CLIs: ~/.local/bin/superagent-*"
echo ""
