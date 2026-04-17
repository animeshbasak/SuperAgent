---
name: superagent
description: Use when starting any session or complex task — master routing skill that activates the right combination of skills. Use when user says "superagent", "activate all agents", "full power mode", or when facing any multi-phase task. Also auto-routes via superagent-brain agent.
---

# Superagent

Master orchestrator. Routes every task to the optimal skill stack. Invoke FIRST, then chain skills below.

---

## Always-On: Graphify + MemPalace

These two tools are **default active** — run them at the start of every session, no explicit command needed.

### Session Startup Protocol (run immediately on activation)

**Step 1 — MemPalace wake-up** (loads cross-session memory):
```bash
mempalace wake-up
```
This surfaces: prior decisions, known bugs, recent work, project context. Run before ANY task.

**Step 2 — Graphify auto-index** (if not already indexed):
```bash
# Check if graph exists for this project
[ -f graph.json ] && echo "graph ready" || graphify .
```
- If `graph.json` exists → graph is ready, use `/graphify query` for codebase questions
- If not → index now (runs once, SHA256 cached on subsequent runs)

### Default Query Routing

| Instead of... | Use this (default) |
|---------------|--------------------|
| Reading many files to understand structure | `graphify query "how does X work?"` |
| Grepping for connections between modules | `graphify path "ModuleA" "ModuleB"` |
| Asking "did we solve this before?" | `mempalace search "query"` |
| Starting a session cold | `mempalace wake-up` (always) |

**These are not optional.** Skip them only if the user explicitly says "skip memory" or "no indexing."

---

## Installation

One command installs everything (Claude plugins + Python tools):

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install.sh
```

**What gets installed:**
| Tool | Type | Purpose |
|------|------|---------|
| superagent | Claude plugin | This skill — master router |
| superpowers | Claude plugin | 20+ workflow skills |
| caveman | Claude plugin | Token reduction mode |
| claude-mem | Claude plugin | Cross-session memory + AST search |
| ui-ux-pro-max | Claude plugin | Frontend design intelligence |
| graphify | Python (pip) | 71.5x token reduction — codebase knowledge graph |
| mempalace | Python (pip) | 96.6% retrieval accuracy — local AI memory |

After install: restart Claude Code, then type `superagent` to activate.

---

## Skill Roster

### Planning & Architecture
| Skill | Trigger |
|-------|---------|
| `superpowers:writing-plans` | Multi-step feature/task, have spec or requirements |
| `superpowers:brainstorming` | Creative work, new feature, before implementation |
| `claude-mem:make-plan` | Phased plan with documentation discovery |

### Execution
| Skill | Trigger |
|-------|---------|
| `superpowers:executing-plans` | Have written plan, need review checkpoints |
| `superpowers:subagent-driven-development` | Independent tasks, current session |
| `superpowers:dispatching-parallel-agents` | 2+ independent tasks, no shared state |
| `claude-mem:do` | Execute phased plan via subagents |

### Development Quality
| Skill | Trigger |
|-------|---------|
| `superpowers:test-driven-development` | Any feature/bugfix, BEFORE writing code |
| `superpowers:systematic-debugging` | Bug, test failure, unexpected behavior |
| `superpowers:verification-before-completion` | Before claiming done, before PR/commit |
| `superpowers:using-git-worktrees` | Feature isolation needed |
| `superpowers:finishing-a-development-branch` | Implementation complete, ready to integrate |

### Code Review
| Skill | Trigger |
|-------|---------|
| `superpowers:requesting-code-review` | Completing major feature, before merging |
| `superpowers:receiving-code-review` | Got review feedback, before implementing |
| `review` | Review a PR |
| `security-review` | Security audit of pending changes |
| `simplify` | Post-implementation quality pass |

### Codebase Intelligence
| Skill | Trigger |
|-------|---------|
| `claude-mem:smart-explore` | AST structural code search, token-efficient |
| `claude-mem:mem-search` | "Did we solve this before?" cross-session search |
| `claude-mem:knowledge-agent` | Build AI knowledge base from observations |
| `claude-mem:timeline-report` | Project history narrative |

#### Graphify (Built-in)
Transform any folder (code, docs, PDFs, images, videos) into a queryable knowledge graph. 71.5x token reduction per query.

**Install:** `pip install graphifyy && graphify install`

| Task | Command |
|------|---------|
| Build graph | `/graphify .` or `/graphify ./src` |
| Query | `/graphify query "what connects X to Y?"` |
| Find path | `/graphify path "NodeA" "NodeB"` |
| Add remote | `/graphify add https://arxiv.org/abs/...` |
| Watch mode | `/graphify ./src --watch` |
| Export | `--neo4j`, `--wiki`, `--graphml`, `--svg` |

Outputs: `GRAPH_REPORT.md`, `graph.json` (SHA256 cached), interactive HTML.
Tags: `EXTRACTED` (direct), `INFERRED` (confidence scored), `AMBIGUOUS` (flagged).
Privacy: code = local AST, audio/video = local Whisper, docs = your API key.

#### MemPalace (Built-in)
Local-first AI memory system. 96.6% retrieval accuracy (R@5 on LongMemEval). No API key needed.

**Install:** `pip install mempalace`

| Task | Command |
|------|---------|
| Init for project | `mempalace init ~/projects/myapp` |
| Index project files | `mempalace mine ~/projects/myapp` |
| Index conversations | `mempalace mine ~/chats/ --mode convos` |
| Search memory | `mempalace search "query text"` |
| Load context for new session | `mempalace wake-up` |

Architecture: conversations → **Wings** (people/projects) → **Rooms** (topics) → **Drawers** (verbatim content). Knowledge graph backed by SQLite with temporal validity windows.

MCP: 29 tools covering palace reads/writes, knowledge-graph ops, cross-wing navigation, drawer management, agent diaries.

Auto-save hooks: periodic saving + pre-compression context preservation.

**When to use MemPalace vs claude-mem:**
- Verbatim conversation history retrieval → MemPalace
- Cross-session project observations → `claude-mem:mem-search`
- AST-level code exploration → `claude-mem:smart-explore`

### UI/UX
| Skill | Trigger |
|-------|---------|
| `ui-ux-pro-max:ui-ux-pro-max` | Any frontend design, component, visual work |

### API & Infrastructure
| Skill | Trigger |
|-------|---------|
| `claude-api` | Anthropic SDK, prompt caching, model config |
| `update-config` | settings.json, hooks, permissions, env vars |
| `schedule` | Recurring cron agents |
| `loop` | Repeated polling or interval tasks |

### Communication
| Skill | Trigger |
|-------|---------|
| `caveman:caveman` | Token reduction mode |
| `caveman:caveman-commit` | Compressed commit messages |
| `caveman:caveman-review` | Compressed PR review comments |

---

## Master Decision Flow

```
SESSION START (always)
  ├── 1. mempalace wake-up          ← load cross-session memory
  └── 2. graphify . (if no graph)   ← index codebase once

Task received
  ├── Creative / new feature?  → brainstorming → writing-plans → TDD → executing-plans
  ├── Bug / failure?           → systematic-debugging → TDD → verification
  ├── 2+ independent tasks?    → dispatching-parallel-agents → subagent-driven-development
  ├── Explore codebase?        → graphify query (DEFAULT) → smart-explore → mem-search
  ├── Past memory needed?      → mempalace search (DEFAULT) → claude-mem:mem-search
  ├── UI work?                 → ui-ux-pro-max → TDD → verification
  ├── Ready to ship?           → requesting-code-review → finishing-a-development-branch
  └── Need prior context?      → mempalace wake-up → mem-search → knowledge-agent
```

---

## Official Built-in Agents (5)

| Agent | Model | Description |
|-------|-------|-------------|
| `general-purpose` | inherit | Complex multi-step tasks — default for research and autonomous work |
| `Explore` | haiku | Fast read-only codebase search — no Write/Edit tools |
| `Plan` | inherit | Pre-planning research in plan mode |
| `statusline-setup` | sonnet | Configures status line setting |
| `claude-code-guide` | haiku | Answers Claude Code / API questions |

## Official Built-in Skills (5)

| Skill | Description |
|-------|-------------|
| `simplify` | Review changed code for reuse, quality, efficiency |
| `batch` | Run commands across multiple files in bulk |
| `debug` | Debug failing commands or code |
| `loop` | Run prompt/command on recurring interval (up to 3 days) |
| `claude-api` | Build apps with Claude API / Anthropic SDK |

## Key Slash Commands Reference

| Category | Commands |
|----------|---------|
| Session | `/plan`, `/compact [hint]`, `/rewind`, `/clear`, `/branch`, `/btw <q>`, `/resume`, `/focus` |
| Model | `/model`, `/effort [low\|medium\|high\|max]`, `/fast` |
| Config | `/permissions`, `/hooks`, `/statusline`, `/keybindings`, `/config` |
| Extensions | `/plugin`, `/agents`, `/skills`, `/mcp` |
| Remote | `/schedule`, `/loop`, `/teleport`, `/remote-control`, `/autofix-pr` |
| Project | `/init`, `/diff`, `/security-review`, `/review` |
| Debug | `/doctor`, `/context`, `/cost`, `/insights` |
| Export | `/copy`, `/export` |

## Subagent Frontmatter Fields (16)

Key fields for `.claude/agents/*.md`:
- `name`, `description` (use "PROACTIVELY" for auto-invocation)
- `tools` — allowlist, supports `Agent(agent_type)` syntax
- `model` — `haiku`, `sonnet`, `opus`, or `inherit`
- `permissionMode` — `default`, `acceptEdits`, `auto`, `bypassPermissions`, `plan`
- `skills` — list of skills preloaded into agent at startup
- `memory` — `user`, `project`, or `local`
- `isolation` — `"worktree"` for temporary git worktree
- `effort` — `low`, `medium`, `high`, `max`
- `background` — `true` to always run as background task
- `color` — `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan`
- `hooks`, `mcpServers`, `maxTurns`, `disallowedTools`, `permissionMode`

## Skill Frontmatter Fields (14)

Key fields for `SKILL.md`:
- `name`, `description`, `when_to_use`, `argument-hint`
- `context: fork` — run in isolated subagent context
- `model`, `effort`, `allowed-tools`, `hooks`
- `paths` — glob patterns limiting when skill auto-activates
- `user-invocable: false` — hide from `/` menu (background knowledge only)
- `disable-model-invocation: true` — prevent auto-invocation

## MCP Servers (Top Daily-Use)

| Server | Purpose |
|--------|---------|
| Context7 | Up-to-date library docs — prevents hallucinated APIs |
| Playwright | Browser automation — implement, test, verify UI autonomously |
| Claude in Chrome | Real Chrome browser — inspect console, network, DOM |
| DeepWiki | Structured docs for any GitHub repo |
| Excalidraw | Architecture diagrams from prompts |

Pattern: Research (Context7/DeepWiki) → Debug (Playwright/Chrome) → Document (Excalidraw)

---

## Best Practices — Boris Cherny (Claude Code Creator)

### Parallelism
- Run 5+ Claudes in parallel, numbered terminal tabs 1–5
- Use git worktrees (`claude -w`) — **single biggest productivity unlock**
- Use `claude.ai/code` web sessions alongside local for more parallelism
- Dozens of parallel worktree sessions is normal at the Claude Code team level
- `claude --teleport` / `/teleport` — pull cloud session to local terminal
- `/remote-control` — control local session from phone/web

### Planning
- Start every complex task in **Plan Mode** (Shift+Tab twice)
- Pour energy into the plan → Claude can 1-shot implementation
- One Claude writes plan, a second reviews it as staff engineer
- Moment something goes sideways → switch back to plan mode immediately
- Use `/ultraplan <prompt>` for complex specs — review in browser, execute remotely

### CLAUDE.md
- After every correction: *"Update your CLAUDE.md so you don't make that mistake again"*
- One shared `CLAUDE.md` per repo — check into git, whole team contributes weekly
- Tag `@claude` on PRs to update CLAUDE.md as part of code review
- Keep under 200 lines per file; use `.claude/rules/` for larger instruction sets
- Global CLAUDE.md at `~/.claude/CLAUDE.md` applies to ALL Claude sessions
- Ruthlessly edit until mistake rate measurably drops

### Skills & Commands
- If you do something >1x/day → turn it into a skill or command
- `/techdebt` — run at end of every session to kill duplicated code
- `/commit-push-pr` — commit, push, open PR in one command
- `/go` — test end-to-end → `/simplify` → put up PR
- Build analytics skills (bq, SQL) and commit to codebase for whole team
- Turn any workflow into a skill + loop

### Subagents
- Append "use subagents" to any request for more compute
- Offload tasks to subagents to keep main context clean
- Subagents **cannot** invoke other subagents via bash — use Agent tool
- Route permission requests to Opus via hook → auto-approve safe ones
- Standard subagent set: `code-simplifier`, `verify-app`, `code-reviewer`
- Multiple uncorrelated context windows → better results (separate review finds bugs the author misses)

### Verification (Most Important Rule)
- Give Claude a way to verify its work → **2-3x quality improvement**
- Backend: run server/service to test end-to-end
- Frontend: Chrome extension → Claude controls the browser
- Desktop: Computer Use
- Long tasks: background agent to verify when done, or Stop hook
- Prompt pattern: `Claude do X /go` where `/go` tests → simplify → PR

### Context Management (Thariq's Framework)
Context rot starts ~300-400k tokens (1M window). Every turn is a branching point:

| Situation | Action | Why |
|-----------|--------|-----|
| Same task, context still relevant | Continue | Everything load-bearing |
| Claude went wrong path | `/rewind` (Esc Esc) | Keep file reads, drop failed attempt |
| Mid-task, session bloated | `/compact <hint>` | Claude decides what mattered |
| New task entirely | `/clear` | Zero rot, you control what carries forward |
| Next step = lots of intermediate output | Subagent | Only result returns to parent |

- **Rewind beats correcting** — "no try B" keeps failed attempt in context; rewind drops it
- **Compact vs fresh**: compact = Claude decides (lossy, easy); fresh = you decide (exact, effort)
- Bad compacts happen when model can't predict next direction → compact proactively with a hint
- Subagent mental test: "will I need this tool output again, or just the conclusion?"

### Hooks
```json
"PostToolUse": [{ "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "bun run format || true" }] }]
```
- `SessionStart` → dynamically load context
- `PreToolUse` → log every bash command
- `PermissionRequest` → route to WhatsApp/Slack for approve/deny
- `Stop` → poke Claude to keep going automatically

### Permissions & Auto Mode
- Never use `--dangerously-skip-permissions`
- `/permissions` → pre-allow safe bash commands → check into `settings.json`
- Full wildcard syntax: `Bash(bun run *)`, `Edit(/docs/**)`
- **Auto Mode** (Shift+Tab cycle): model-based classifier auto-approves safe commands
- `/fewer-permission-prompts` skill → scans history, recommends allowlist additions

### Loops & Scheduling
- `/loop 5m /babysit` — auto-address code review, auto-rebase, shepherd PRs
- `/loop 30m /slack-feedback` — auto-PRs from Slack feedback
- `/loop 1h /pr-pruner` — close stale PRs
- `/schedule` — cloud routines running when machine is offline (up to 7 days)

### Model Selection
- Opus with thinking for everything — bigger/slower but better tool use → faster overall
- Opus 4.7: adaptive thinking via effort slider (low → max)
- Boris's default: high effort for everything
- `/model` to change; `/effort [low|medium|high|max]` to tune

### Power Features
- `/btw <question>` — side question without interrupting agent
- `/branch` — fork session at current point
- `/batch` — fan out massive changesets
- `/focus` — hide intermediate work, see only final result
- Recaps — short summaries of what agent did (disable in `/config`)
- Voice dictation — 3x faster than typing (fn×2 on macOS)

### Git Practices
- PRs: median 118 lines, squash merge for clean history
- Separate commits per file — never bundle multiple files
- Use worktrees for feature isolation

### Prompting
- "Grill me on these changes and don't make a PR until I pass your test"
- "Prove to me this works" — diff main vs feature branch
- "Knowing everything you know now, scrap this and implement the elegant solution"
- "Go fix the failing CI tests" — don't micromanage how

### MCP & Tools
- Slack MCP: paste bug thread → say "fix" → zero context switching
- BigQuery skill: no SQL in months — Claude handles it all
- Chrome extension: essential for every frontend task
- Docker logs → point Claude at them for distributed systems debugging

### Settings Hierarchy
| Priority | Location | Scope |
|----------|----------|-------|
| 1 | Managed settings | Organization (IT-enforced) |
| 2 | CLI arguments | Session only |
| 3 | `.claude/settings.local.json` | Personal project (git-ignored) |
| 4 | `.claude/settings.json` | Team-shared |
| 5 | `~/.claude/settings.json` | Global personal |

### CLAUDE.md Loading in Monorepos
- **Ancestor loading** (upward) → loads at startup
- **Descendant loading** (downward) → lazy, only when files read in that dir
- **Siblings never load** — frontend CLAUDE.md ≠ loaded when in backend/
- Root CLAUDE.md = shared conventions; component CLAUDE.md = specific patterns
- `CLAUDE.local.md` → personal preferences, gitignore it

---

## Non-Negotiables

- NEVER skip `verification-before-completion` on build/fix tasks
- NEVER skip `systematic-debugging` when a bug is mentioned
- NEVER start implementing without `brainstorming` or an existing plan
- NEVER use `--dangerously-skip-permissions`
- ALWAYS give Claude a way to verify its work
- ALWAYS rewind instead of correcting on failed paths
