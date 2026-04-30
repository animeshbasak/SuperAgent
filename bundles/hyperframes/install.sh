#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent Bundle — hyperframes (video toolkit)
# Installs Node 22+, FFmpeg, and the global `hyperframes` npm package.
# Idempotent: safe to re-run; skips anything already present.
# Footprint: ~120 MB (Node + FFmpeg + hyperframes).
# Usage: bash bundles/hyperframes/install.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }

# ── OS detection ──────────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      fail "Unsupported OS: $OS (need Darwin or Linux)" ;;
esac

echo ""
echo -e "${BOLD}── hyperframes bundle (${PLATFORM}) ──${NC}"

# ── Helpers ───────────────────────────────────────────────────────────────────
node_major() {
  command -v node >/dev/null 2>&1 || { echo "0"; return; }
  node -v 2>/dev/null | sed -E 's/^v([0-9]+)\..*/\1/' || echo "0"
}

ensure_node() {
  local major
  major="$(node_major)"
  if [[ "$major" -ge 22 ]]; then
    ok "node $(node -v) already installed"
    return
  fi
  info "Installing Node 22+..."
  if [[ "$PLATFORM" == "macos" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install node@22 || brew install node
      brew link --overwrite node@22 2>/dev/null || true
    else
      fail "Homebrew not found. Install from https://brew.sh then re-run."
    fi
  else
    # Linux — prefer apt with NodeSource, fall back to nvm
    if command -v apt-get >/dev/null 2>&1; then
      info "Using NodeSource apt repo..."
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
      sudo apt-get install -y nodejs
    else
      info "Using nvm..."
      export NVM_DIR="$HOME/.nvm"
      if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
      fi
      # shellcheck disable=SC1091
      . "$NVM_DIR/nvm.sh"
      nvm install 22
      nvm use 22
    fi
  fi
  command -v node >/dev/null 2>&1 || fail "Node install failed"
  ok "node $(node -v) installed"
}

ensure_ffmpeg() {
  if command -v ffmpeg >/dev/null 2>&1; then
    ok "ffmpeg already installed ($(ffmpeg -version 2>/dev/null | head -1))"
    return
  fi
  info "Installing FFmpeg..."
  if [[ "$PLATFORM" == "macos" ]]; then
    command -v brew >/dev/null 2>&1 || fail "Homebrew required for ffmpeg on macOS"
    brew install ffmpeg
  else
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update -y && sudo apt-get install -y ffmpeg
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y ffmpeg
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -S --noconfirm ffmpeg
    else
      fail "No supported package manager (apt/dnf/pacman). Install ffmpeg manually."
    fi
  fi
  command -v ffmpeg >/dev/null 2>&1 || fail "ffmpeg install failed"
  ok "ffmpeg installed"
}

ensure_hyperframes() {
  if command -v hyperframes >/dev/null 2>&1; then
    ok "hyperframes already installed ($(hyperframes --version 2>/dev/null || echo unknown))"
    return
  fi
  info "Installing hyperframes globally via npm..."
  # Prefer user-global to avoid sudo on Linux
  if npm config get prefix 2>/dev/null | grep -q "/usr"; then
    if [[ "$PLATFORM" == "linux" ]]; then
      sudo npm i -g hyperframes
    else
      npm i -g hyperframes
    fi
  else
    npm i -g hyperframes
  fi
  command -v hyperframes >/dev/null 2>&1 || fail "hyperframes install failed (check npm prefix)"
  ok "hyperframes installed"
}

# ── Run ───────────────────────────────────────────────────────────────────────
ensure_node
ensure_ffmpeg
ensure_hyperframes

# ── Self-verify ───────────────────────────────────────────────────────────────
echo ""
info "Self-verification..."
hyperframes --version >/dev/null 2>&1 || fail "verify: hyperframes --version failed"
ffmpeg -version    >/dev/null 2>&1 || fail "verify: ffmpeg -version failed"
ok "hyperframes: $(hyperframes --version 2>/dev/null || echo installed)"
ok "ffmpeg: $(ffmpeg -version 2>/dev/null | head -1 | awk '{print $1, $2, $3}')"

echo ""
ok "hyperframes bundle ready"
echo ""
