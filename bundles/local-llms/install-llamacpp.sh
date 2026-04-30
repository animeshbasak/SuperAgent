#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SuperAgent Bundle — llama.cpp + Qwen3-class 27B (Q4_K_M ~16 GB)
# Installs llama.cpp (provides `llama-server`) and downloads a large GGUF.
# Footprint: ~17 GB (llama.cpp + ~16 GB model). Disk pre-flight: ≥21 GB free.
# Idempotent: skips when binary present and model file already large enough.
# Resume: uses `curl -C -` so partial downloads can continue.
# Usage: bash bundles/local-llms/install-llamacpp.sh
#        SUPERAGENT_ASSUME_YES=1 bundles/local-llms/install-llamacpp.sh   # CI
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
ARCH="$(uname -m)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      fail "Unsupported OS: $OS" ;;
esac

MODEL_DIR="$HOME/.cache/llama.cpp/models"
MODEL_FILE="$MODEL_DIR/qwen3.6-27b-q4km.gguf"
# Primary URL (Qwen org). If Qwen3.6 naming differs, the user can override
# with SUPERAGENT_GGUF_URL=... when re-running.
DEFAULT_URL="https://huggingface.co/Qwen/Qwen3.6-27B-Instruct-GGUF/resolve/main/Qwen3.6-27B-Instruct-Q4_K_M.gguf"
MODEL_URL="${SUPERAGENT_GGUF_URL:-$DEFAULT_URL}"
MIN_FREE_KB=$((21 * 1024 * 1024))   # 21 GB in KB
MIN_MODEL_BYTES=$((14 * 1024 * 1024 * 1024))  # 14 GB sanity floor

echo ""
echo -e "${BOLD}── llama.cpp bundle (${PLATFORM}/${ARCH}) ──${NC}"

# ── Step 1: Disk pre-flight (≥21 GB free in $HOME) ───────────────────────────
free_kb="$(df -k "$HOME" | awk 'NR==2 {print $4}')"
if [[ -z "$free_kb" || "$free_kb" -lt "$MIN_FREE_KB" ]]; then
  fail "Need ≥21 GB free in \$HOME (have $((free_kb/1024/1024)) GB). Free up disk and retry."
fi
ok "Disk: $((free_kb/1024/1024)) GB free in \$HOME (≥21 GB required)"

# ── Step 2: Confirm prompt (skippable in CI) ─────────────────────────────────
if [[ "${SUPERAGENT_ASSUME_YES:-0}" != "1" ]]; then
  printf "Download Qwen3.6-27B Q4_K_M (~16 GB)? [y/N] "
  read -r reply || reply=""
  case "${reply:-}" in
    y|Y|yes|YES) ;;
    *) fail "Aborted by user." ;;
  esac
fi

# ── Step 3: Install llama.cpp (provides llama-server) ─────────────────────────
ensure_llamacpp() {
  if command -v llama-server >/dev/null 2>&1; then
    ok "llama-server already installed ($(llama-server --version 2>&1 | head -1 || echo present))"
    return
  fi
  info "Installing llama.cpp..."
  if [[ "$PLATFORM" == "macos" ]]; then
    command -v brew >/dev/null 2>&1 || fail "Homebrew required on macOS"
    brew install llama.cpp
  else
    # Linux — try apt, otherwise pre-built release tarball
    if command -v apt-get >/dev/null 2>&1 \
       && apt-cache show llama.cpp >/dev/null 2>&1; then
      sudo apt-get update -y && sudo apt-get install -y llama.cpp
    else
      info "Fetching pre-built llama.cpp release..."
      tmpdir="$(mktemp -d)"
      case "$ARCH" in
        x86_64|amd64)
          asset="llama-bin-ubuntu-x64.zip" ;;
        aarch64|arm64)
          asset="llama-bin-ubuntu-arm64.zip" ;;
        *) fail "Unsupported Linux arch: $ARCH (build llama.cpp from source)" ;;
      esac
      # Resolve latest release asset URL via GitHub API
      api_url="https://api.github.com/repos/ggerganov/llama.cpp/releases/latest"
      asset_url="$(curl -fsSL "$api_url" \
        | grep -Eo "\"browser_download_url\": *\"[^\"]+${asset}\"" \
        | head -1 | sed -E 's/.*"(https[^"]+)".*/\1/')"
      [[ -n "$asset_url" ]] || fail "Could not resolve llama.cpp release asset $asset"
      curl -fL -o "$tmpdir/llama.zip" "$asset_url"
      unzip -q -o "$tmpdir/llama.zip" -d "$HOME/.local/llama.cpp"
      mkdir -p "$HOME/.local/bin"
      # Symlink server binary onto PATH
      bin="$(find "$HOME/.local/llama.cpp" -type f -name 'llama-server' | head -1)"
      [[ -n "$bin" ]] || fail "llama-server binary not found in release"
      chmod +x "$bin"
      ln -sf "$bin" "$HOME/.local/bin/llama-server"
      rm -rf "$tmpdir"
    fi
  fi
  command -v llama-server >/dev/null 2>&1 || fail "llama-server still not on PATH"
  ok "llama.cpp installed"
}
ensure_llamacpp

# ── Step 4: Download GGUF (resumable) ─────────────────────────────────────────
mkdir -p "$MODEL_DIR"

current_size=0
if [[ -f "$MODEL_FILE" ]]; then
  current_size="$(stat -f%z "$MODEL_FILE" 2>/dev/null || stat -c%s "$MODEL_FILE" 2>/dev/null || echo 0)"
fi

if [[ "$current_size" -ge "$MIN_MODEL_BYTES" ]]; then
  ok "Model already present and ≥14 GB: $MODEL_FILE"
else
  info "Downloading model (resumable) → $MODEL_FILE"
  info "URL: $MODEL_URL"
  # `curl -C -` resumes if file partially exists. -L follows redirects.
  if ! curl -L -C - --fail --output "$MODEL_FILE" "$MODEL_URL"; then
    warn "Download failed."
    warn "If Qwen3.6-27B-Instruct-GGUF doesn't exist yet, override the URL:"
    warn "  SUPERAGENT_GGUF_URL='https://huggingface.co/<repo>/resolve/main/<file>.gguf' \\"
    warn "    bash bundles/local-llms/install-llamacpp.sh"
    fail "Aborting — model not downloaded."
  fi
fi

# ── Self-verify ───────────────────────────────────────────────────────────────
echo ""
info "Self-verification..."
command -v llama-server >/dev/null 2>&1 || fail "verify: llama-server not on PATH"
[[ -f "$MODEL_FILE" ]] || fail "verify: model file missing at $MODEL_FILE"
size_bytes="$(stat -f%z "$MODEL_FILE" 2>/dev/null || stat -c%s "$MODEL_FILE" 2>/dev/null || echo 0)"
[[ "$size_bytes" -gt "$MIN_MODEL_BYTES" ]] \
  || fail "verify: model file too small (${size_bytes} bytes, expected >14 GB)"
ok "llama-server on PATH"
ok "model: $MODEL_FILE ($((size_bytes/1024/1024/1024)) GB)"

echo ""
ok "llama.cpp bundle ready"
echo "  Start server: llama-server -m $MODEL_FILE --port 8080"
echo ""
