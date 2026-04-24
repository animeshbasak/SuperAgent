#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Superagent — One-command installer
# Installs superagent + all required plugins + Python tools into ~/.claude
# Usage: bash install.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Flags ─────────────────────────────────────────────────────────────────────
LOCAL_ONLY=0
for a in "$@"; do
  case "$a" in
    --local-only) LOCAL_ONLY=1 ;;
  esac
done
export LOCAL_ONLY

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
PLUGINS_DIR="$CLAUDE_DIR/plugins"
INSTALLED="$PLUGINS_DIR/installed_plugins.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${CYAN}→${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
fail() { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      Superagent Installer v1.1       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

# ── Prerequisites ─────────────────────────────────────────────────────────────
info "Checking prerequisites..."
command -v claude >/dev/null 2>&1 || fail "Claude Code CLI not found. Install from https://claude.ai/code"
command -v node   >/dev/null 2>&1 || fail "node.js not found. Install from https://nodejs.org"
[[ -d "$CLAUDE_DIR" ]] || fail "~/.claude not found. Run 'claude' once to initialize."
ok "Prerequisites OK"
echo ""

# ── Step 1: Register custom marketplaces ──────────────────────────────────────
info "Registering plugin marketplaces..."
[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"

node - <<'JSEOF'
const fs = require('fs'), path = require('path');
const file = path.join(process.env.HOME, '.claude', 'settings.json');
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
cfg.extraKnownMarketplaces = cfg.extraKnownMarketplaces || {};
Object.assign(cfg.extraKnownMarketplaces, {
  animeshbasak:          { source: { source: 'github', repo: 'animeshbasak/SuperAgent' } },
  caveman:               { source: { source: 'github', repo: 'JuliusBrussee/caveman' } },
  thedotmack:            { source: { source: 'github', repo: 'thedotmack/claude-mem' } },
  'ui-ux-pro-max-skill': { source: { source: 'github', repo: 'nextlevelbuilder/ui-ux-pro-max-skill' } },
});
fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
JSEOF
ok "Marketplaces registered"
echo ""

# ── Step 2: Install Claude plugin dependencies ────────────────────────────────
info "Installing Claude plugins..."
echo ""

install_plugin() {
  local plugin="$1"
  local name="${plugin%%@*}"
  if claude plugin list 2>/dev/null | grep -q "^$name"; then
    warn "$plugin already installed, skipping"
  else
    info "Installing $plugin..."
    claude plugin install "$plugin" \
      && ok "$plugin installed" \
      || warn "$plugin failed — run manually: claude plugin install $plugin"
  fi
}

install_plugin "superpowers@claude-plugins-official"
install_plugin "caveman@caveman"
install_plugin "claude-mem@thedotmack"
install_plugin "ui-ux-pro-max@ui-ux-pro-max-skill"

echo ""

# ── Step 3: Install superagent as a local plugin ─────────────────────────────
info "Installing superagent (local plugin)..."

SUPERAGENT_CACHE="$PLUGINS_DIR/cache/local/superagent/1.0.0"
mkdir -p "$SUPERAGENT_CACHE/agents"

cp "$SCRIPT_DIR/skills/superagent/SKILL.md" "$SUPERAGENT_CACHE/SKILL.md"
[[ -f "$SCRIPT_DIR/agents/superagent-brain.md" ]] && \
  cp "$SCRIPT_DIR/agents/superagent-brain.md" "$SUPERAGENT_CACHE/agents/superagent-brain.md"

cat > "$SUPERAGENT_CACHE/package.json" <<'PKGJSON'
{
  "name": "superagent",
  "version": "1.0.0",
  "description": "Master orchestrator skill for Claude Code"
}
PKGJSON

[[ -f "$INSTALLED" ]] || echo '{"version":2,"plugins":{}}' > "$INSTALLED"
node - <<'JSEOF'
const fs = require('fs'), path = require('path');
const file = path.join(process.env.HOME, '.claude', 'plugins', 'installed_plugins.json');
let db = { version: 2, plugins: {} };
try { db = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
db.plugins['superagent@local'] = [{
  scope: 'user',
  installPath: path.join(process.env.HOME, '.claude', 'plugins', 'cache', 'local', 'superagent', '1.0.0'),
  version: '1.0.0',
  installedAt: new Date().toISOString(),
  lastUpdated: new Date().toISOString(),
  gitCommitSha: 'local',
}];
fs.writeFileSync(file, JSON.stringify(db, null, 2));
JSEOF
ok "superagent local plugin registered"
echo ""

# ── Step 4: Enable all plugins in settings.json ───────────────────────────────
info "Enabling plugins..."
node - <<'JSEOF'
const fs = require('fs'), path = require('path');
const file = path.join(process.env.HOME, '.claude', 'settings.json');
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
cfg.enabledPlugins = cfg.enabledPlugins || {};
['superagent@local','superpowers@claude-plugins-official','caveman@caveman',
 'claude-mem@thedotmack','ui-ux-pro-max@ui-ux-pro-max-skill']
  .forEach(p => { cfg.enabledPlugins[p] = true; });
fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
JSEOF
ok "All plugins enabled in settings.json"
echo ""

# ── Step 5: Wire up ~/.claude/agents ─────────────────────────────────────────
info "Linking agent files..."

AGENTS_DIR="$CLAUDE_DIR/agents"
mkdir -p "$AGENTS_DIR"
if [[ -f "$SCRIPT_DIR/agents/superagent-brain.md" && ! -f "$AGENTS_DIR/superagent-brain.md" ]]; then
  cp "$SCRIPT_DIR/agents/superagent-brain.md" "$AGENTS_DIR/superagent-brain.md"
  ok "superagent-brain agent installed at ~/.claude/agents/"
fi
echo ""

# ── Step 6: Link SuperAgent v2 skills into ~/.claude/skills/ ──────────────────
info "Linking 13 SuperAgent skills..."

mkdir -p "$HOME/.claude/skills"
for skill in superagent token-stats webgl-craft plan-ceo-review plan-eng-review plan-design-review autoplan review investigate ship office-hours cso learn; do
  src="$SCRIPT_DIR/skills/$skill"
  dst="$HOME/.claude/skills/$skill"
  if [[ ! -d "$src" ]]; then
    warn "skip: $skill (not present)"
    continue
  fi
  rm -rf "$dst"
  if ln -sfn "$src" "$dst" 2>/dev/null; then
    ok "linked: $skill"
  else
    cp -r "$src" "$dst"
    ok "copied: $skill (symlink unsupported)"
  fi
done
echo ""

# ── Step 6: Configure global CLAUDE.md ───────────────────────────────────────
info "Configuring ~/.claude/CLAUDE.md..."

GLOBAL_CLAUDE="$CLAUDE_DIR/CLAUDE.md"
read -r -d '' SUPERAGENT_SECTION << 'MDEOF' || true
# Global Claude Instructions

## SuperAgent — Active on ALL Sessions

The `superagent` skill and `superagent-brain` agent are always active across every project and session.

- **superagent skill**: routes every task to the optimal skill chain
- **superagent-brain agent**: PROACTIVELY auto-routes build/fix/explore/design/review/ship tasks

### Activation
- Say "superagent", "activate all agents", or "full power mode" to invoke
- Available skill stacks: `caveman`, `superpowers:*`, `claude-mem:*`, `ui-ux-pro-max`, graphify, mempalace

### Global Rules
- Start every complex task in Plan Mode before implementing
- Always give Claude a way to verify its work (2-3x quality improvement)
- Never use `--dangerously-skip-permissions` — use `/permissions` allowlists
- Rewind (`/rewind`) instead of correcting on failed paths
MDEOF

if [[ -f "$GLOBAL_CLAUDE" ]]; then
  if grep -q "SuperAgent" "$GLOBAL_CLAUDE"; then
    warn "~/.claude/CLAUDE.md already has SuperAgent config, skipping"
  else
    { echo ""; echo "$SUPERAGENT_SECTION"; } >> "$GLOBAL_CLAUDE"
    ok "SuperAgent section added to existing CLAUDE.md"
  fi
else
  echo "$SUPERAGENT_SECTION" > "$GLOBAL_CLAUDE"
  ok "~/.claude/CLAUDE.md created"
fi
echo ""

# ── Step 7: Install Python tools (graphify + mempalace) ───────────────────────
info "Installing Python tools (graphify + mempalace)..."

# Prefer pipx — works on macOS system Python (externally-managed-environment)
# Auto-install pipx via brew if missing
if ! command -v pipx >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    info "pipx not found — installing via brew..."
    brew install pipx --quiet \
      && pipx ensurepath --force >/dev/null 2>&1 \
      && export PATH="$HOME/.local/bin:$PATH" \
      && ok "pipx installed" \
      || warn "brew install pipx failed — install manually: brew install pipx"
  else
    warn "pipx not found. Install it: https://pipx.pypa.io/stable/installation/"
    warn "Then re-run: bash install.sh"
  fi
else
  # Ensure pipx-managed bins are in PATH for this session
  export PATH="$HOME/.local/bin:$PATH"
fi

if command -v pipx >/dev/null 2>&1; then
  info "Installing graphify (71.5x token reduction)..."
  pipx install graphifyy 2>&1 | tail -2 \
    && ok "graphify installed" \
    || { pipx upgrade graphifyy 2>&1 | tail -1 && ok "graphify upgraded"; }

  info "Installing mempalace (96.6% retrieval accuracy)..."
  pipx install mempalace 2>&1 | tail -2 \
    && ok "mempalace installed" \
    || { pipx upgrade mempalace 2>&1 | tail -1 && ok "mempalace upgraded"; }
else
  warn "Skipping Python tools — pipx unavailable."
  warn "Install pipx then re-run: bash install.sh"
fi
echo ""

# ── Step 8: Auto-initialize mempalace ────────────────────────────────────────
info "Initializing mempalace for ~/.claude ..."
MEMPALACE_BIN=$(command -v mempalace 2>/dev/null || echo "$HOME/.local/bin/mempalace")
if [[ -x "$MEMPALACE_BIN" ]]; then
  "$MEMPALACE_BIN" init "$CLAUDE_DIR" --yes 2>&1 | tail -3 \
    && ok "mempalace init complete" \
    || warn "mempalace init failed — run manually after restart: mempalace init ~/.claude --yes"

  info "Mining ~/.claude into mempalace (skills, agents, config)..."
  "$MEMPALACE_BIN" mine "$CLAUDE_DIR" 2>&1 | tail -3 \
    && ok "mempalace index built for ~/.claude" \
    || warn "mempalace mine failed — run manually: mempalace mine ~/.claude"
else
  warn "mempalace not found — restart terminal then run:"
  warn "  mempalace init ~/.claude --yes && mempalace mine ~/.claude"
fi
echo ""

# ── Step 9: Auto-build graphify knowledge graph ───────────────────────────────
info "Building graphify knowledge graph for ~/.claude/skills ..."
GRAPHIFY_BIN=$(command -v graphify 2>/dev/null || echo "$HOME/.local/bin/graphify")
if [[ -x "$GRAPHIFY_BIN" ]]; then
  pushd "$CLAUDE_DIR" >/dev/null
  "$GRAPHIFY_BIN" update "$CLAUDE_DIR/skills" 2>&1 | tail -3 \
    && ok "graphify graph built (graphify-out/graph.json)" \
    && { bash "$CLAUDE_DIR/superagent-tracker.sh" --calibrate "$CLAUDE_DIR" 2>/dev/null || true; } \
    || warn "graphify update failed — run manually: cd ~/.claude && graphify update skills"
  popd >/dev/null
else
  warn "graphify not found — restart terminal then run:"
  warn "  cd ~/.claude && graphify update skills"
fi
echo ""

# ── Step 10: Install token savings tracker ────────────────────────────────────
info "Installing token savings tracker..."
TRACKER_SRC="$SCRIPT_DIR/hooks/superagent-tracker.sh"
STATUSLINE_SRC="$SCRIPT_DIR/hooks/superagent-statusline.sh"

if [[ -f "$TRACKER_SRC" && -f "$STATUSLINE_SRC" ]]; then
  cp "$TRACKER_SRC"    "$CLAUDE_DIR/superagent-tracker.sh"
  cp "$STATUSLINE_SRC" "$CLAUDE_DIR/superagent-statusline.sh"
  chmod +x "$CLAUDE_DIR/superagent-tracker.sh"
  chmod +x "$CLAUDE_DIR/superagent-statusline.sh"
  ok "Tracker scripts installed to ~/.claude/"

  # Wire PostToolUse hook and statusLine in settings.json
  node - <<'JSEOF'
const fs = require('fs'), path = require('path');
const file = path.join(process.env.HOME, '.claude', 'settings.json');
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}

cfg.hooks = cfg.hooks || {};
cfg.hooks.PostToolUse = cfg.hooks.PostToolUse || [];
const trackerCmd = `bash "${path.join(process.env.HOME, '.claude', 'superagent-tracker.sh')}"`;
const alreadyWired = cfg.hooks.PostToolUse.some(h =>
  h.hooks && h.hooks.some(hh => hh.command && hh.command.includes('superagent-tracker'))
);
if (!alreadyWired) {
  cfg.hooks.PostToolUse.push({
    matcher: "Bash",
    hooks: [{ type: "command", command: trackerCmd }]
  });
}

const statusCmd = `bash "${path.join(process.env.HOME, '.claude', 'superagent-statusline.sh')}"`;
if (!cfg.statusLine || !cfg.statusLine.command || !cfg.statusLine.command.includes('superagent-statusline')) {
  cfg.statusLine = { type: "command", command: statusCmd };
}

fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
JSEOF
  ok "PostToolUse hook + statusLine wired in ~/.claude/settings.json"
else
  warn "Hook scripts not found in $SCRIPT_DIR/hooks/ — skipping tracker install"
fi
echo ""

# ── Step 11: Initialize superagent state root ────────────────────────────────
info "Initializing superagent state root..."
INIT_SRC="$SCRIPT_DIR/hooks/superagent-state-init.sh"
if [[ -f "$INIT_SRC" ]]; then
  bash "$INIT_SRC" \
    && ok "State root initialized at ~/.superagent/" \
    || warn "State root init failed — run manually: bash $INIT_SRC"
else
  warn "superagent-state-init.sh not found in $SCRIPT_DIR/hooks/ — skipping"
fi
echo ""

# ── Step 12: Install SuperAgent CLIs into ~/.local/bin/ ───────────────────────
info "Installing SuperAgent CLIs..."

for tool in superagent-classify superagent-ship superagent-learn; do
  src="$SCRIPT_DIR/bin/$tool"
  dst="$HOME/.local/bin/$tool"
  if [[ -f "$src" ]]; then
    mkdir -p "$HOME/.local/bin"
    cp "$src" "$dst"
    chmod +x "$dst"
    ok "bin installed: $tool -> $dst"
  else
    warn "bin not found: $tool"
  fi
done
if ! echo "$PATH" | tr ':' '\n' | grep -Fxq "$HOME/.local/bin"; then
  warn "~/.local/bin is not on PATH — add: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
echo ""

# ── Step 13: Install distill Stop hook (writes CLAUDE.md.superagent-proposed) ──
info "Installing distill Stop hook..."
DISTILL_SRC="$SCRIPT_DIR/hooks/superagent-distill.sh"
if [[ -f "$DISTILL_SRC" ]]; then
  cp "$DISTILL_SRC" "$CLAUDE_DIR/superagent-distill.sh"
  chmod +x "$CLAUDE_DIR/superagent-distill.sh"
  ok "Distill hook installed to ~/.claude/"

  node - <<'JSEOF'
const fs = require('fs'), path = require('path');
const file = path.join(process.env.HOME, '.claude', 'settings.json');
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
cfg.hooks = cfg.hooks || {};
cfg.hooks.Stop = cfg.hooks.Stop || [];
const stopCmd = `bash "${path.join(process.env.HOME, '.claude', 'superagent-distill.sh')}" || true`;
const alreadyWired = cfg.hooks.Stop.some(h =>
  h.hooks && h.hooks.some(hh => hh.command && hh.command.includes('superagent-distill'))
);
if (!alreadyWired) {
  cfg.hooks.Stop.push({
    matcher: "*",
    hooks: [{ type: "command", command: stopCmd }]
  });
}
fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
JSEOF
  ok "Stop hook wired in ~/.claude/settings.json"
else
  warn "superagent-distill.sh not found — skipping"
fi
echo ""

# ── Step 14: Honor --local-only flag ──────────────────────────────────────────
if [[ "$LOCAL_ONLY" == "1" ]]; then
  mkdir -p "$HOME/.superagent"
  touch "$HOME/.superagent/local-only"
  ok "--local-only marker written to ~/.superagent/local-only"
  info "Hooks and tools will honor this marker and avoid outbound calls."
  echo ""
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Superagent installed & initialized!       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Installed:"
echo "    ✓ superagent         — master orchestrator"
echo "    ✓ superpowers        — 20+ workflow skills (TDD, planning, debugging)"
echo "    ✓ caveman            — token reduction mode"
echo "    ✓ claude-mem         — cross-session memory & AST search"
echo "    ✓ ui-ux-pro-max      — frontend design intelligence"
echo "    ✓ webgl-craft        — premium WebGL/3D creative web (Awwwards-class techniques)"
echo "    ✓ graphify           — knowledge graph (auto-indexed ~/.claude/skills)"
echo "    ✓ mempalace          — cross-session memory (auto-indexed ~/.claude)"
echo "    ✓ token-stats        — real token savings tracking (statusline + /token-stats)"
echo ""
echo "  One step remaining:"
echo "    1. Restart Claude Code"
echo "    2. Type: superagent"
echo ""
echo "  Everything else is already set up. graphify + mempalace are live."
echo ""
echo -e "  ${CYAN}Docs:${NC} https://github.com/animeshbasak/SuperAgent"
echo ""
