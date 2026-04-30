#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent Bundle — Ollama + qwen2.5-coder:7b (default fallback model)
# Installs Ollama and pulls the 4 GB qwen2.5-coder:7b model.
# Footprint: ~4.5 GB (ollama runtime + 4 GB model).
# Idempotent: skips install/pull if already present.
# Usage: bash bundles/local-llms/install-ollama.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }

OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      fail "Unsupported OS: $OS" ;;
esac

MODEL="qwen2.5-coder:7b"

echo ""
echo -e "${BOLD}── Ollama bundle (${PLATFORM}) ──${NC}"

# ── Step 1: Install ollama ────────────────────────────────────────────────────
ensure_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    ok "ollama already installed ($(ollama --version 2>/dev/null | head -1 || echo present))"
    return
  fi
  info "Installing ollama..."
  if [[ "$PLATFORM" == "macos" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install ollama
    else
      fail "Homebrew required on macOS. Install from https://brew.sh"
    fi
  else
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  command -v ollama >/dev/null 2>&1 || fail "ollama install failed"
  ok "ollama installed"
}
ensure_ollama

# ── Step 2: Make sure ollama daemon is reachable ──────────────────────────────
# On macOS the brew formula installs as a service; on Linux the official
# installer registers a systemd unit. We try the API; if it fails we
# kick off `ollama serve` in the background just for this script run.
api_alive() { curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; }

if ! api_alive; then
  info "Starting ollama daemon in background..."
  if [[ "$PLATFORM" == "macos" ]] && command -v brew >/dev/null 2>&1; then
    brew services start ollama 2>/dev/null || nohup ollama serve >/tmp/ollama.log 2>&1 &
  else
    nohup ollama serve >/tmp/ollama.log 2>&1 &
  fi
  # Wait up to ~10s for the API to come up
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    api_alive && break
    sleep 1
  done
  api_alive || warn "ollama API still not reachable — pull may fail"
fi

# ── Step 3: Pull default fallback model ───────────────────────────────────────
if ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$MODEL"; then
  ok "$MODEL already pulled"
else
  info "Pulling $MODEL (~4 GB)..."
  ollama pull "$MODEL"
  ok "$MODEL pulled"
fi

# ── Self-verify ───────────────────────────────────────────────────────────────
echo ""
info "Self-verification..."
command -v ollama >/dev/null 2>&1 || fail "verify: ollama not on PATH"
ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$MODEL" \
  || fail "verify: $MODEL not present in 'ollama list'"
ok "ollama list shows $MODEL"

echo ""
ok "Ollama + $MODEL ready"
echo "  Run:  ollama run $MODEL"
echo ""
