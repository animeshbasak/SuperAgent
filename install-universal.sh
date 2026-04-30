#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent Universal Installer
# Auto-detects installed AI coding platforms and installs SuperAgent for each.
# Does NOT touch the existing Claude Code install.sh — that remains separate.
#
# Usage:
#   bash install-universal.sh                       # auto-detect and install all
#   bash install-universal.sh --platform codex      # install for specific platform
#   bash install-universal.sh --list                # list detected platforms
#
#   Optional bundles (Phase B — opt-in, all idempotent):
#     --with-video       hyperframes + Node 22+ + FFmpeg          (~120 MB)
#     --with-free-llm    free-claude-code + Ollama qwen2.5-coder  (~5 GB)   [Claude Code only]
#     --with-near-opus   llama.cpp + Qwen3.6-27B Q4_K_M GGUF       (~17 GB) [Claude Code only]
#     --full             all of the above                          (~21 GB total)
#
#   Privacy default: bundles install LOCAL-only LLMs. Cloud free-tier is opt-in.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }

# ── Prerequisites ─────────────────────────────────────────────────────────────
command -v python3 >/dev/null 2>&1 || fail "python3 required"

# ── Platform Detection ────────────────────────────────────────────────────────
detect_platforms() {
  DETECTED=()

  # Claude Code
  if command -v claude >/dev/null 2>&1; then
    DETECTED+=("claude")
  fi

  # Codex CLI
  if command -v codex >/dev/null 2>&1; then
    DETECTED+=("codex")
  fi

  # Gemini CLI / Antigravity
  if command -v gemini >/dev/null 2>&1 || [[ -d "$HOME/.gemini" ]]; then
    DETECTED+=("gemini")
  fi

  # Cursor (check for .cursor/ in common locations or Cursor app)
  if [[ -d "$HOME/.cursor" ]] || command -v cursor >/dev/null 2>&1; then
    DETECTED+=("cursor")
  fi

  # Windsurf
  if command -v windsurf >/dev/null 2>&1 || [[ -d "$HOME/.windsurf" ]]; then
    DETECTED+=("windsurf")
  fi

  # GitHub Copilot (check for VS Code Copilot extension or gh copilot)
  if command -v gh >/dev/null 2>&1 && gh extension list 2>/dev/null | grep -q copilot; then
    DETECTED+=("copilot")
  elif [[ -d "$HOME/.vscode/extensions" ]] && ls "$HOME/.vscode/extensions" 2>/dev/null | grep -q copilot; then
    DETECTED+=("copilot")
  fi

  # Continue.dev
  if [[ -d "$HOME/.continue" ]]; then
    DETECTED+=("continue")
  fi

  # Aider
  if command -v aider >/dev/null 2>&1; then
    DETECTED+=("aider")
  fi
}

# ── Parse Arguments ───────────────────────────────────────────────────────────
SPECIFIC_PLATFORM=""
LIST_ONLY=0
WITH_VIDEO=0
WITH_FREE_LLM=0
WITH_NEAR_OPUS=0

for arg in "$@"; do
  case "$arg" in
    --list)           LIST_ONLY=1 ;;
    --platform)       :;; # next arg is the platform name
    --with-video)     WITH_VIDEO=1 ;;
    --with-free-llm)  WITH_FREE_LLM=1 ;;
    --with-near-opus) WITH_NEAR_OPUS=1 ;;
    --full)           WITH_VIDEO=1; WITH_FREE_LLM=1; WITH_NEAR_OPUS=1 ;;
    -h|--help)
      sed -n '2,18p' "$0"; exit 0 ;;
    claude|codex|gemini|cursor|windsurf|copilot|continue|aider)
      SPECIFIC_PLATFORM="$arg" ;;
  esac
done

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   SuperAgent Universal Installer v1.0    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Detect ────────────────────────────────────────────────────────────────────
detect_platforms

echo "Detected platforms:"
ALL_PLATFORMS=(claude codex gemini cursor windsurf copilot continue aider)
for p in "${ALL_PLATFORMS[@]}"; do
  if printf '%s\n' "${DETECTED[@]}" | grep -qx "$p"; then
    echo -e "  ${GREEN}✓${NC} $p"
  else
    echo -e "  ${RED}✗${NC} $p (not detected)"
  fi
done
echo ""

if [[ "$LIST_ONLY" == "1" ]]; then
  exit 0
fi

# ── Install ───────────────────────────────────────────────────────────────────
install_platform() {
  local platform="$1"
  local adapter="$SCRIPT_DIR/adapters/$platform/install.sh"

  if [[ "$platform" == "claude" ]]; then
    info "Claude Code: use the original install.sh (bash install.sh)"
    warn "Skipping — Claude install is handled separately to preserve existing behavior"
    return
  fi

  if [[ ! -f "$adapter" ]]; then
    warn "No adapter found for $platform (expected $adapter)"
    return
  fi

  echo -e "\n${BOLD}── Installing for $platform ──${NC}"
  bash "$adapter"
}

if [[ -n "$SPECIFIC_PLATFORM" ]]; then
  install_platform "$SPECIFIC_PLATFORM"
else
  # Install for all detected platforms (except Claude — that has its own installer)
  for p in "${DETECTED[@]}"; do
    install_platform "$p"
  done
fi

# ── Python Tools (shared across all platforms) ────────────────────────────────
echo ""
echo -e "${BOLD}── Shared Python Tools ──${NC}"
echo ""

if ! command -v pipx >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    info "Installing pipx via brew..."
    brew install pipx --quiet \
      && pipx ensurepath --force >/dev/null 2>&1 \
      && export PATH="$HOME/.local/bin:$PATH" \
      && ok "pipx installed" \
      || warn "brew install pipx failed"
  else
    warn "pipx not found. Install: https://pipx.pypa.io/stable/installation/"
  fi
else
  export PATH="$HOME/.local/bin:$PATH"
fi

if command -v pipx >/dev/null 2>&1; then
  info "Installing graphify..."
  pipx install graphifyy 2>&1 | tail -1 \
    && ok "graphify installed" \
    || { pipx upgrade graphifyy 2>&1 | tail -1 && ok "graphify upgraded"; }

  info "Installing mempalace..."
  pipx install mempalace 2>&1 | tail -1 \
    && ok "mempalace installed" \
    || { pipx upgrade mempalace 2>&1 | tail -1 && ok "mempalace upgraded"; }
fi

# ── Install SuperAgent CLIs ──────────────────────────────────────────────────
echo ""
info "Installing SuperAgent CLIs..."
for tool in superagent-classify superagent-chain superagent-cost superagent-learn superagent-compile; do
  src="$SCRIPT_DIR/bin/$tool"
  dst="$HOME/.local/bin/$tool"
  if [[ -f "$src" ]]; then
    mkdir -p "$HOME/.local/bin"
    cp "$src" "$dst"
    chmod +x "$dst"
    ok "$tool"
  fi
done

if ! echo "$PATH" | tr ':' '\n' | grep -Fxq "$HOME/.local/bin"; then
  warn "~/.local/bin is not on PATH — add: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ── Optional Bundles (Phase B) ────────────────────────────────────────────────
# `--with-free-llm` and `--with-near-opus` are scoped to Claude Code only,
# because the proxy + GGUF integration paths target the Claude Code CLI.
# On Cursor/Copilot/etc. we warn and skip rather than silently install.
have_claude=0
if printf '%s\n' "${DETECTED[@]}" | grep -qx "claude"; then
  have_claude=1
fi

run_bundle() {
  local label="$1"; shift
  local script="$1"; shift
  echo ""
  echo -e "${BOLD}── Bundle: ${label} ──${NC}"
  if [[ ! -f "$script" ]]; then
    warn "Bundle script not found: $script — skipping"
    return
  fi
  bash "$script" "$@" || warn "Bundle '${label}' returned non-zero — continuing"
}

if [[ "$WITH_VIDEO" == "1" ]]; then
  run_bundle "hyperframes (~120 MB)" "$SCRIPT_DIR/bundles/hyperframes/install.sh"
fi

if [[ "$WITH_FREE_LLM" == "1" ]]; then
  if [[ "$have_claude" == "1" ]]; then
    run_bundle "free-claude-code (~400 MB)"   "$SCRIPT_DIR/bundles/free-claude-code/install.sh"
    run_bundle "Ollama + qwen2.5-coder:7b (~4.5 GB)" "$SCRIPT_DIR/bundles/local-llms/install-ollama.sh"
  else
    warn "--with-free-llm is Claude Code only; not detected → skipping"
  fi
fi

if [[ "$WITH_NEAR_OPUS" == "1" ]]; then
  if [[ "$have_claude" == "1" ]]; then
    run_bundle "llama.cpp + Qwen3.6-27B Q4_K_M (~17 GB)" "$SCRIPT_DIR/bundles/local-llms/install-llamacpp.sh"
  else
    warn "--with-near-opus is Claude Code only; not detected → skipping"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║    SuperAgent Universal — installed!             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Platforms installed: ${DETECTED[*]:-none}"
echo "  Python tools: graphify + mempalace"
echo "  CLIs: ~/.local/bin/superagent-*"
echo ""
echo "  For Claude Code: use the original 'bash install.sh'"
echo "  For other platforms: everything is ready!"
echo ""
echo -e "  ${CYAN}Docs:${NC} https://github.com/animeshbasak/SuperAgent"
echo ""
