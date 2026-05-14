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
for src in "$REPO_ROOT"/bin/superagent-*; do
  [[ -f "$src" ]] || continue
  tool="$(basename "$src")"
  dst="$HOME/.local/bin/$tool"
  mkdir -p "$HOME/.local/bin"
  cp "$src" "$dst"
  chmod +x "$dst"
  ok "CLI: $tool"
done

# ── Step 5: Install Codex plugin + slash command ──────────────────────────
info "Installing /superagent for Codex..."

CODEX_PLUGIN_SRC="$HOME/.codex/plugins/superagent"
CODEX_PLUGIN_CACHE="$HOME/.codex/plugins/cache/superagent-local/superagent/local"
PERSONAL_MARKETPLACE="$HOME/.agents/plugins/marketplace.json"
CODEX_PROMPTS_DIR="$HOME/.codex/prompts"

stage_plugin() {
  local dst="$1"
  local tmp="${dst}.tmp.$$"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  cp -R "$REPO_ROOT/.codex-plugin" "$tmp/.codex-plugin"
  cp -R "$REPO_ROOT/commands" "$tmp/commands"
  cp -R "$REPO_ROOT/skills" "$tmp/skills"
  [[ -d "$REPO_ROOT/agents" ]] && cp -R "$REPO_ROOT/agents" "$tmp/agents"
  rm -rf "$dst"
  mv "$tmp" "$dst"
}

mkdir -p "$(dirname "$CODEX_PLUGIN_SRC")" "$(dirname "$CODEX_PLUGIN_CACHE")"
stage_plugin "$CODEX_PLUGIN_SRC"
stage_plugin "$CODEX_PLUGIN_CACHE"
ok "Plugin staged at ~/.codex/plugins/superagent"
ok "Plugin cache installed at ~/.codex/plugins/cache/superagent-local/superagent/local"

mkdir -p "$CODEX_PROMPTS_DIR"
cp "$REPO_ROOT/commands/superagent.md" "$CODEX_PROMPTS_DIR/superagent.md"
ok "Compatibility prompt installed at ~/.codex/prompts/superagent.md"

python3 - "$PERSONAL_MARKETPLACE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]).expanduser()
path.parent.mkdir(parents=True, exist_ok=True)

if path.exists():
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        backup = path.with_suffix(path.suffix + ".bak")
        backup.write_text(path.read_text())
        data = {}
else:
    data = {}

data.setdefault("name", "superagent-local")
data.setdefault("interface", {}).setdefault("displayName", "SuperAgent Local")
plugins = data.setdefault("plugins", [])

entry = {
    "name": "superagent",
    "source": {
        "source": "local",
        "path": "./.codex/plugins/superagent"
    },
    "policy": {
        "installation": "INSTALLED_BY_DEFAULT",
        "authentication": "ON_INSTALL"
    },
    "category": "Coding"
}

for i, existing in enumerate(plugins):
    if existing.get("name") == "superagent":
        plugins[i] = entry
        break
else:
    plugins.append(entry)

path.write_text(json.dumps(data, indent=2) + "\n")
PY
ok "Personal marketplace updated at ~/.agents/plugins/marketplace.json"

python3 - "$HOME/.codex/config.toml" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1]).expanduser()
path.parent.mkdir(parents=True, exist_ok=True)
text = path.read_text() if path.exists() else ""

section = '[plugins."superagent@superagent-local"]'
block = f'{section}\nenabled = true\n'

pattern = re.compile(r'(?ms)^\[plugins\."superagent@superagent-local"\]\n(?:^[^\[].*?\n)*')
if pattern.search(text):
    text = pattern.sub(block, text)
else:
    if text and not text.endswith("\n"):
        text += "\n"
    if text and not text.endswith("\n\n"):
        text += "\n"
    text += block

path.write_text(text)
PY
ok "Codex config enabled superagent@superagent-local"

echo ""
ok "SuperAgent for Codex CLI installed!"
echo "  Global: ~/.codex/AGENTS.md"
echo "  Slash:  /superagent"
echo "  Plugin: superagent@superagent-local"
echo "  CLIs: ~/.local/bin/superagent-*"
echo "  Restart Codex for the slash command/plugin cache to refresh."
echo ""
