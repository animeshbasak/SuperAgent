#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent — Gemini / Antigravity Installer
# Installs SuperAgent instructions + skills for Google Gemini CLI / Antigravity IDE
# Usage: bash adapters/gemini/install.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }

echo ""
echo -e "${CYAN}SuperAgent for Gemini / Antigravity${NC}"
echo ""

# ── Step 1: Compile latest skills ──────────────────────────────────────────
info "Compiling skills for Gemini..."
python3 "$REPO_ROOT/bin/superagent-compile" --platform gemini \
  --output "$SCRIPT_DIR/templates/" 2>&1 | tail -3

# ── Step 2: Install global GEMINI.md ──────────────────────────────────────
GEMINI_DIR="$HOME/.gemini"
mkdir -p "$GEMINI_DIR"

GLOBAL_GEMINI="$GEMINI_DIR/GEMINI.md"
if [[ -f "$GLOBAL_GEMINI" ]]; then
  if grep -q "SuperAgent" "$GLOBAL_GEMINI"; then
    warn "~/.gemini/GEMINI.md already has SuperAgent config, skipping"
  else
    { echo ""; cat "$SCRIPT_DIR/templates/GEMINI.md"; } >> "$GLOBAL_GEMINI"
    ok "SuperAgent section added to existing GEMINI.md"
  fi
else
  cp "$SCRIPT_DIR/templates/GEMINI.md" "$GLOBAL_GEMINI"
  ok "~/.gemini/GEMINI.md created"
fi

# ── Step 3: Install skill files to .agent/rules/ ─────────────────────────
if [[ -n "${PROJECT_DIR:-}" ]]; then
  AGENT_RULES="$PROJECT_DIR/.agent/rules"
  mkdir -p "$AGENT_RULES"

  for skill_dir in "$SCRIPT_DIR/templates/skills"/*/; do
    skill_name="$(basename "$skill_dir")"
    dst="$AGENT_RULES/$skill_name"
    rm -rf "$dst"
    cp -r "$skill_dir" "$dst"
    ok "Skill: $skill_name"
  done
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
ok "SuperAgent for Gemini / Antigravity installed!"
echo "  Global: ~/.gemini/GEMINI.md"
echo "  Skills: adapters/gemini/templates/skills/"
echo "  CLIs: ~/.local/bin/superagent-*"
echo ""
