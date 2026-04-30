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

# ── Step 2: Install global GEMINI.md (idempotent — always refresh SuperAgent block) ──
GEMINI_DIR="$HOME/.gemini"
mkdir -p "$GEMINI_DIR"

GLOBAL_GEMINI="$GEMINI_DIR/GEMINI.md"
SA_BEGIN="<!-- SUPERAGENT-BEGIN -->"
SA_END="<!-- SUPERAGENT-END -->"

# Strip any existing SuperAgent block (between markers, OR an unmarked legacy
# block we can detect by the first heading). Re-append the latest template
# wrapped in markers so future runs are surgical.
if [[ -f "$GLOBAL_GEMINI" ]]; then
  if grep -q "$SA_BEGIN" "$GLOBAL_GEMINI"; then
    # Modern: marker-wrapped — strip and replace
    awk -v b="$SA_BEGIN" -v e="$SA_END" '
      $0==b {skip=1; next}
      $0==e {skip=0; next}
      !skip
    ' "$GLOBAL_GEMINI" > "$GLOBAL_GEMINI.tmp" && mv "$GLOBAL_GEMINI.tmp" "$GLOBAL_GEMINI"
  elif grep -q "^# SuperAgent" "$GLOBAL_GEMINI"; then
    # Legacy: no markers but starts with SuperAgent heading — strip from that
    # heading to EOF (assumes SuperAgent block is always last).
    awk '/^# SuperAgent/{exit} {print}' "$GLOBAL_GEMINI" > "$GLOBAL_GEMINI.tmp" && mv "$GLOBAL_GEMINI.tmp" "$GLOBAL_GEMINI"
  fi
fi

# Append the fresh SuperAgent block, marker-wrapped.
{
  [[ -s "$GLOBAL_GEMINI" ]] && echo ""
  echo "$SA_BEGIN"
  cat "$SCRIPT_DIR/templates/GEMINI.md"
  echo "$SA_END"
} >> "$GLOBAL_GEMINI"
ok "~/.gemini/GEMINI.md refreshed (SuperAgent block updated in place)"

# ── Step 3: Install skill files to ~/.gemini/skills/ (global) ─────────────
# Always sync globally so Gemini CLI / Antigravity see the latest skill set.
GEMINI_SKILLS="$GEMINI_DIR/skills"
mkdir -p "$GEMINI_SKILLS"
# Purge prior superagent skills so renames don't leave stale dirs.
for d in "$GEMINI_SKILLS"/*/; do
  [[ -d "$d" ]] || continue
  if [[ -f "$d/SKILL.md" ]] && grep -q "superagent\|SuperAgent" "$d/SKILL.md" 2>/dev/null; then
    rm -rf "$d"
  fi
done
for skill_dir in "$SCRIPT_DIR/templates/skills"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir")"
  dst="$GEMINI_SKILLS/$skill_name"
  rm -rf "$dst"
  cp -r "$skill_dir" "$dst"
done
ok "$(ls "$GEMINI_SKILLS" | wc -l | tr -d ' ') skills synced to ~/.gemini/skills/"

# Also drop into .agent/rules/ for project-local Antigravity layouts when
# PROJECT_DIR is set (rare; --project flag from a wrapper).
if [[ -n "${PROJECT_DIR:-}" ]]; then
  AGENT_RULES="$PROJECT_DIR/.agent/rules"
  mkdir -p "$AGENT_RULES"
  for skill_dir in "$SCRIPT_DIR/templates/skills"/*/; do
    skill_name="$(basename "$skill_dir")"
    dst="$AGENT_RULES/$skill_name"
    rm -rf "$dst"
    cp -r "$skill_dir" "$dst"
  done
  ok "Project skills mirrored to $AGENT_RULES/"
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
echo "  Skills: ~/.gemini/skills/"
echo "  CLIs: ~/.local/bin/superagent-*"
echo ""
