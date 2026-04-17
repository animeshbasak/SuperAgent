#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Superagent — One-command installer
# Installs superagent + all required plugins + Python tools into ~/.claude
# Usage: bash install.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

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
echo -e "${CYAN}║      Superagent Installer v1.0       ║${NC}"
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

# ── Step 5: Wire up ~/.claude/skills and ~/.claude/agents ─────────────────────
info "Linking skill and agent files..."

SKILLS_DIR="$CLAUDE_DIR/skills/superagent"
if [[ ! -d "$SKILLS_DIR" ]]; then
  mkdir -p "$CLAUDE_DIR/skills"
  ln -s "$SCRIPT_DIR/skills/superagent" "$SKILLS_DIR" 2>/dev/null \
    || cp -r "$SCRIPT_DIR/skills/superagent" "$SKILLS_DIR"
  ok "Skill linked at ~/.claude/skills/superagent"
else
  warn "~/.claude/skills/superagent already exists, skipping"
fi

AGENTS_DIR="$CLAUDE_DIR/agents"
mkdir -p "$AGENTS_DIR"
if [[ -f "$SCRIPT_DIR/agents/superagent-brain.md" && ! -f "$AGENTS_DIR/superagent-brain.md" ]]; then
  cp "$SCRIPT_DIR/agents/superagent-brain.md" "$AGENTS_DIR/superagent-brain.md"
  ok "superagent-brain agent installed at ~/.claude/agents/"
fi
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

PIP_CMD=""
command -v pip3  >/dev/null 2>&1 && PIP_CMD="pip3"
command -v pip   >/dev/null 2>&1 && [[ -z "$PIP_CMD" ]] && PIP_CMD="pip"
command -v pipx  >/dev/null 2>&1 && [[ -z "$PIP_CMD" ]] && PIP_CMD="pipx"

if [[ -z "$PIP_CMD" ]]; then
  warn "pip not found — after installing Python 3, run:"
  warn "  pip install graphifyy && graphify install"
  warn "  pip install mempalace"
else
  info "Installing graphify (71.5x token reduction for codebase queries)..."
  $PIP_CMD install graphifyy --quiet 2>&1 | tail -1 \
    && graphify install --quiet 2>/dev/null \
    && ok "graphify installed — use: graphify . to index a project" \
    || warn "graphify install failed — try: pip install graphifyy && graphify install"

  info "Installing mempalace (96.6% cross-session memory retrieval)..."
  $PIP_CMD install mempalace --quiet 2>&1 | tail -1 \
    && ok "mempalace installed — use: mempalace init ~/projects/myapp" \
    || warn "mempalace install failed — try: pip install mempalace"
fi
echo ""

# ── Done ─────────────────────────────────────────────────────────────────────
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Superagent ready!                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  What was installed:"
echo "    ✓ superagent         — master orchestrator"
echo "    ✓ superpowers        — 20+ workflow skills (TDD, planning, debugging)"
echo "    ✓ caveman            — token reduction mode"
echo "    ✓ claude-mem         — cross-session memory & AST search"
echo "    ✓ ui-ux-pro-max      — frontend design intelligence"
echo "    ✓ graphify           — 71.5x token reduction for codebase queries"
echo "    ✓ mempalace          — 96.6% retrieval accuracy local memory"
echo ""
echo "  Getting started:"
echo "    1. Restart Claude Code  (or /reload-plugins)"
echo "    2. Type: superagent     (to activate)"
echo "    3. /graphify .          (to index current project)"
echo "    4. mempalace wake-up    (to load session context)"
echo ""
echo -e "  ${CYAN}Docs:${NC} https://github.com/animeshbasak/SuperAgent"
echo ""
