# SuperAgent for Claude Code

One command. Full power. Everything auto-initialized.

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install.sh
```

Restart Claude Code, type `superagent`. Done.

---

## What Gets Installed

| Tool | Type | Purpose |
|------|------|---------|
| **superagent** | Claude plugin | Master orchestrator — routes tasks to optimal skill chain |
| **superpowers** | Claude plugin | 20+ workflow skills: TDD, planning, debugging, reviews |
| **caveman** | Claude plugin | ~75% token reduction mode |
| **claude-mem** | Claude plugin | Cross-session memory + AST code search |
| **ui-ux-pro-max** | Claude plugin | Frontend design intelligence (50+ styles, 161 palettes) |
| **graphify** | Python CLI | 71.5x token reduction — codebase knowledge graph |
| **mempalace** | Python CLI | 96.6% retrieval accuracy — local AI memory, no API key |

All Python tools are installed via **pipx** (works on macOS system Python). If pipx is missing, it's auto-installed via Homebrew.

**Auto-initialized on install:**
- `mempalace init ~/.claude --yes` + `mempalace mine ~/.claude` — indexes your Claude config
- `graphify update ~/.claude/skills` — builds knowledge graph of all installed skills

---

## Usage

After restart, activate with any of:
- `superagent` — full activation
- `activate all agents` — alias
- `full power mode` — alias

### Session Startup (automatic on activation)

```bash
mempalace wake-up          # loads cross-session memory
graphify query "<question>" # query the knowledge graph
```

### Index a new project

```bash
cd ~/my-project
mempalace init . --yes && mempalace mine .
graphify update ./src
```

---

## Skill Roster

### Planning
| Skill | When |
|-------|------|
| `superpowers:brainstorming` | Before any new feature |
| `superpowers:writing-plans` | Have spec, need multi-step plan |
| `claude-mem:make-plan` | Phased plan with doc discovery |

### Execution
| Skill | When |
|-------|------|
| `superpowers:test-driven-development` | Before writing ANY code |
| `superpowers:systematic-debugging` | Any bug or test failure |
| `superpowers:verification-before-completion` | Before claiming done |
| `superpowers:dispatching-parallel-agents` | 2+ independent tasks |

### Code Review
| Skill | When |
|-------|------|
| `superpowers:requesting-code-review` | Before merging |
| `superpowers:receiving-code-review` | Got PR feedback |
| `simplify` | Post-implementation quality pass |
| `security-review` | Security audit |

### Codebase Intelligence
| Skill | When |
|-------|------|
| `claude-mem:smart-explore` | Token-efficient AST search |
| `claude-mem:mem-search` | "Did we solve this before?" |
| `graphify query "..."` | Understand codebase structure |

---

## Global Rules (auto-applied every session)

- Plan Mode before every complex task
- Always give Claude a way to verify its work (2-3x quality)
- Never `--dangerously-skip-permissions` — use `/permissions` allowlists
- `/rewind` instead of correcting on failed paths
- `/compact <hint>` at ~50% context, not auto-compaction

---

## Requirements

- [Claude Code CLI](https://claude.ai/code)
- Node.js 18+
- macOS/Linux (Homebrew recommended on macOS for pipx)

---

## Manual Python Install (if brew unavailable)

```bash
# Option A — pipx (recommended)
pip install pipx && pipx ensurepath
pipx install graphifyy
pipx install mempalace

# Option B — uv
uv tool install graphifyy
uv tool install mempalace
```

Then initialize:
```bash
mempalace init ~/.claude --yes && mempalace mine ~/.claude
cd ~/.claude && graphify update skills
```

---

## Docs

- [graphify](https://github.com/animeshbasak/graphifyy)
- [mempalace](https://github.com/animeshbasak/mempalace)
- [superpowers](https://github.com/claude-plugins-official/superpowers)
- [claude-mem](https://github.com/thedotmack/claude-mem)
