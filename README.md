# SuperAgent for Claude Code

> One install. Every skill. Zero manual routing.

SuperAgent is a master orchestrator plugin for [Claude Code](https://claude.ai/code) that automatically routes every task to the right skill stack — with graphify and MemPalace active by default for 71.5x token reduction and 96.6% cross-session memory retrieval.

---

## What It Does

When you type `superagent` (or just start working), SuperAgent:

1. **Loads your memory** — `mempalace wake-up` surfaces prior decisions, known bugs, recent work
2. **Indexes your codebase** — `graphify .` builds a queryable knowledge graph (once, cached)
3. **Routes your task** — the AI brain reads intent and chains the right skills automatically

No more manually picking between TDD, debugging, planning, or code review workflows. SuperAgent picks for you.

---

## Quick Install

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install.sh
```

Then restart Claude Code and type: `superagent`

---

## What Gets Installed

| Tool | Type | What it does |
|------|------|--------------|
| **superagent** | Claude plugin | Master routing skill + AI brain agent |
| **superpowers** | Claude plugin | 20+ workflow skills (TDD, planning, debugging, code review) |
| **caveman** | Claude plugin | Token reduction mode for compressed output |
| **claude-mem** | Claude plugin | Cross-session memory search + AST-level code exploration |
| **ui-ux-pro-max** | Claude plugin | Frontend design intelligence |
| **graphify** | Python tool | 71.5x token reduction — codebase knowledge graph |
| **mempalace** | Python tool | 96.6% retrieval accuracy — local AI memory system |

All 7 installed automatically. No manual steps.

---

## Always-On: Graphify + MemPalace

These two are **default active** — they run at session start without being asked.

### MemPalace (Session Memory)
```bash
# Runs automatically at every Claude Code session start (via SessionStart hook)
mempalace wake-up
```
Surfaces: past decisions, bug fixes, architectural choices, things you told Claude before.

Architecture: conversations → **Wings** (people/projects) → **Rooms** (topics) → **Drawers** (verbatim content). SQLite-backed with temporal validity windows.

```bash
mempalace init ~/projects/myapp    # Initialize for a project
mempalace mine ~/projects/myapp    # Index project files
mempalace search "auth flow"       # Search past work
mempalace wake-up                  # Load context at session start
```

### Graphify (Codebase Intelligence)
```bash
# Runs once per project, SHA256-cached after that
graphify .           # Index current directory
graphify ./src       # Index specific folder
```

Ask questions about your codebase without reading dozens of files:
```bash
/graphify query "what connects the auth middleware to the session store?"
/graphify path "UserService" "Database"
/graphify ./src --watch    # Auto-reindex on file changes
```

Supports: 25+ languages, PDFs, images, audio/video (local Whisper). Outputs `GRAPH_REPORT.md` + interactive HTML.

---

## Skill Stack

SuperAgent routes to these skill groups:

### Planning & Architecture
| Skill | When |
|-------|------|
| `superpowers:brainstorming` | New feature, creative work |
| `superpowers:writing-plans` | Multi-step task with requirements |
| `claude-mem:make-plan` | Phased plan with doc discovery |

### Execution
| Skill | When |
|-------|------|
| `superpowers:subagent-driven-development` | Independent tasks, current session |
| `superpowers:dispatching-parallel-agents` | 2+ tasks, no shared state |
| `superpowers:executing-plans` | Written plan, need review checkpoints |

### Development Quality
| Skill | When |
|-------|------|
| `superpowers:test-driven-development` | Any feature/bugfix, BEFORE writing code |
| `superpowers:systematic-debugging` | Bug, test failure, unexpected behavior |
| `superpowers:verification-before-completion` | Before claiming done |

### Code Review
| Skill | When |
|-------|------|
| `superpowers:requesting-code-review` | Completing major feature |
| `simplify` | Post-implementation quality pass |
| `security-review` | Security audit |

### Codebase Intelligence
| Skill | When |
|-------|------|
| `graphify` | Codebase structure/connection questions (**default**) |
| `claude-mem:smart-explore` | AST-level symbol search |
| `claude-mem:mem-search` | Cross-session: "did we solve this before?" |
| `mempalace` | Verbatim conversation/decision history (**default**) |

### UI/UX
| Skill | When |
|-------|------|
| `ui-ux-pro-max:ui-ux-pro-max` | Any frontend design or component work |

### Communication
| Skill | When |
|-------|------|
| `caveman:caveman` | Token reduction mode |
| `caveman:caveman-commit` | Compressed commit messages |

---

## Decision Flow

```
SESSION START (always automatic)
  ├── mempalace wake-up      ← load cross-session memory
  └── graphify . (if new)   ← index codebase once

Task received
  ├── Build / create?    → brainstorming → writing-plans → TDD → executing-plans
  ├── Bug / failure?     → systematic-debugging → TDD → verification
  ├── 2+ tasks?          → dispatching-parallel-agents
  ├── Explore code?      → graphify query → smart-explore
  ├── Past context?      → mempalace search → mem-search
  ├── UI work?           → ui-ux-pro-max → TDD → verification
  └── Ship it?           → requesting-code-review → finishing-a-development-branch
```

---

## Usage

```
superagent           # Activate + run session startup protocol
activate all agents  # Same
full power mode      # Same
```

Or just start working — the `superagent-brain` agent auto-activates on build/fix/explore/design/review/ship tasks.

### Manual skill invocation
```
/superpowers:writing-plans    # Write an implementation plan
/superpowers:systematic-debugging  # Debug a failure
/caveman:caveman              # Enable token reduction mode
/ui-ux-pro-max:ui-ux-pro-max # Frontend design mode
```

---

## Non-Negotiables (from Boris Cherny, Claude Code creator)

- ALWAYS give Claude a way to verify its work — 2-3x quality improvement
- NEVER use `--dangerously-skip-permissions` — use `/permissions` allowlists
- Start every complex task in Plan Mode (Shift+Tab twice)
- After every correction: "Update your CLAUDE.md so you don't make that mistake again"
- Rewind (`/rewind`) instead of correcting on failed paths

---

## Manual Installation

If you prefer step-by-step:

### 1. Register marketplaces
Add to `~/.claude/settings.json`:
```json
{
  "extraKnownMarketplaces": {
    "caveman":               { "source": { "source": "github", "repo": "JuliusBrussee/caveman" } },
    "thedotmack":            { "source": { "source": "github", "repo": "thedotmack/claude-mem" } },
    "ui-ux-pro-max-skill":   { "source": { "source": "github", "repo": "nextlevelbuilder/ui-ux-pro-max-skill" } }
  }
}
```

### 2. Install Claude plugins
```bash
claude plugin install superpowers@claude-plugins-official
claude plugin install caveman@caveman
claude plugin install claude-mem@thedotmack
claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

### 3. Install superagent skill + agent
```bash
cp -r skills/superagent ~/.claude/skills/superagent
cp agents/superagent-brain.md ~/.claude/agents/superagent-brain.md
```

### 4. Install Python tools
```bash
pip install graphifyy && graphify install
pip install mempalace
```

### 5. Add to global CLAUDE.md
Add to `~/.claude/CLAUDE.md`:
```markdown
## SuperAgent — Active on ALL Sessions
- Say "superagent" to activate
- mempalace wake-up runs at session start
- graphify indexes each project on first use
```

### 6. Add SessionStart hook
Add to `~/.claude/settings.json`:
```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{ "type": "command", "command": "mempalace wake-up 2>/dev/null || true" }]
    }]
  }
}
```

---

## Publishing to the Claude Marketplace

### Option A: Community Marketplace (GitHub-based) — Live Now

SuperAgent is already published as a community marketplace plugin. Users install with two commands:

```bash
# 1. Register the marketplace (one-time)
# Add to ~/.claude/settings.json → extraKnownMarketplaces:
#   "animeshbasak": { "source": { "source": "github", "repo": "animeshbasak/SuperAgent" } }

# 2. Install
claude plugin install superagent@animeshbasak
```

Or just use the installer which handles everything:
```bash
bash <(curl -s https://raw.githubusercontent.com/animeshbasak/SuperAgent/main/install.sh)
```

**How it works — the required files in your repo:**

```
SuperAgent/
  .claude-plugin/
    plugin.json       ← plugin metadata (name, version, author)
    marketplace.json  ← marketplace definition
  skills/
    superagent/
      SKILL.md        ← skill content (auto-discovered)
  agents/
    superagent-brain.md  ← agent files (auto-discovered)
```

**`.claude-plugin/plugin.json`** (the key file):
```json
{
  "name": "superagent",
  "description": "Master orchestrator for Claude Code",
  "version": "1.0.0",
  "author": { "name": "Your Name", "email": "you@email.com" },
  "homepage": "https://github.com/you/your-plugin",
  "repository": "https://github.com/you/your-plugin",
  "license": "MIT"
}
```

**To create your own plugin marketplace** — same pattern, just fork any existing plugin repo, add `.claude-plugin/plugin.json`, and share the install command.

### Option B: Official Claude Marketplace

Anthropic's official plugin marketplace (`claude-plugins-official`) requires:
1. Contact Anthropic via [claude.ai/code](https://claude.ai/code) or GitHub issues
2. Submit for review — they evaluate quality, security, usefulness
3. Once approved, users can install via `claude plugin install yourplugin@claude-plugins-official`

Current official plugins: `superpowers`, and a few others. The bar is high — open source, well-documented, actively maintained.

### What You Need for Either

| Requirement | Details |
|-------------|---------|
| Public GitHub repo | Plugin files must be publicly accessible |
| `SKILL.md` with frontmatter | `name`, `description` fields required |
| Semantic versioning | Tag releases: `git tag v1.0.0 && git push --tags` |
| Working install | Test `claude plugin install` from a clean machine |
| README | Clear docs for users |

### Release Checklist

```bash
# 1. Tag the release
git tag v1.0.0
git push origin v1.0.0

# 2. Test clean install
claude plugin install superagent@yourgithubuser  # (once marketplace is registered)

# 3. Verify skills load
# In Claude Code: /skills → check superagent appears

# 4. Submit to Anthropic (optional)
# Open issue at: https://github.com/anthropics/claude-code
# Title: "Plugin submission: superagent"
```

---

## Project Structure

```
SuperAgent/
  install.sh                    ← one-command installer
  CLAUDE.md                     ← global Claude instructions template
  skills/
    superagent/
      SKILL.md                  ← master orchestrator skill
  agents/
    superagent-brain.md         ← PROACTIVE AI routing agent (Opus)
  best-practices/               ← 82+ tips from Boris Cherny
```

---

## Contributing

PRs welcome. Key areas:
- New skill triggers in `agents/superagent-brain.md`
- Best practices additions in `best-practices/`
- Install script improvements for Windows/Linux

---

## Credits

- **Skills**: [superpowers](https://github.com/claude-plugins-official), [caveman](https://github.com/JuliusBrussee/caveman), [claude-mem](https://github.com/thedotmack/claude-mem), [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)
- **Best practices**: [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) (Boris Cherny, Claude Code creator)
- **Python tools**: [graphify](https://github.com/safishamsi/graphify), [MemPalace](https://github.com/MemPalace/mempalace)
- **Built by**: [animeshbasak](https://github.com/animeshbasak)
