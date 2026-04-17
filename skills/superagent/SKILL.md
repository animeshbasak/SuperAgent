---
name: superagent
description: Use when starting any session or complex task — master routing skill that activates the right combination of skills for the job. Use when user says "superagent", "activate all agents", "full power mode", or when facing a complex multi-phase task requiring planning + execution + review.
---

# Superagent

Master orchestrator. Routes every task to the optimal skill stack. Invoke this FIRST, then chain the relevant skills below.

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
| `graphify` | Cross-modal graph (code + docs + papers + video) |
| `claude-mem:smart-explore` | AST structural code search, token-efficient |
| `claude-mem:mem-search` | "Did we solve this before?" cross-session search |
| `claude-mem:knowledge-agent` | Build AI knowledge base from observations |
| `claude-mem:timeline-report` | Project history narrative |

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
| `caveman:caveman` | Token reduction mode (invoke /caveman) |
| `caveman:caveman-commit` | Compressed commit messages |
| `caveman:caveman-review` | Compressed PR review comments |

## Master Decision Flow

```
Task received
  ├── Creative / new feature? → brainstorming → writing-plans → executing-plans
  ├── Bug / failure? → systematic-debugging → TDD fix → verification-before-completion
  ├── Multi-task independent? → dispatching-parallel-agents → subagent-driven-development
  ├── Codebase exploration? → smart-explore or graphify → mem-search for prior work
  ├── UI work? → ui-ux-pro-max → TDD → verification-before-completion
  ├── Ready to ship? → requesting-code-review → finishing-a-development-branch
  └── Past context needed? → mem-search → knowledge-agent
```

## Activation Sequence

When invoked:
1. Read this skill
2. Identify which phase the task is in (plan / execute / review / explore)
3. Invoke the matching skill(s) from the roster above
4. Chain: plan → execute → verify — never skip verify

---

## Boris Cherny Best Practices (Claude Code Creator)

### Parallelism
- Run 5+ Claudes in parallel in terminal tabs (numbered 1–5)
- Use git worktrees (`claude -w`) for parallel work in same repo — the single biggest productivity unlock
- Use `claude.ai/code` web sessions alongside local for even more parallelism
- Dozens of parallel sessions with worktrees is normal at the Claude Code team level

### Planning
- Start every complex task in **Plan Mode** (Shift+Tab twice)
- Pour energy into the plan so Claude can 1-shot implementation
- Have one Claude write the plan, a second Claude review it as a staff engineer
- Switch back to plan mode the moment something goes sideways — don't keep pushing
- Use plan mode for verification steps too, not just build steps

### CLAUDE.md
- After every correction: "Update your CLAUDE.md so you don't make that mistake again"
- Share one CLAUDE.md per repo, check into git, have whole team contribute weekly
- Tag `@claude` on PRs to update CLAUDE.md as part of code review
- Keep CLAUDE.md under 200 lines per file for reliable adherence
- Ruthlessly edit until Claude's mistake rate measurably drops
- Use `.claude/rules/` for larger instruction sets

### Skills & Commands
- If you do something >1x/day, turn it into a skill or command
- Build `/techdebt` slash command — run at end of every session to kill duplicated code
- Build `/commit-push-pr` — commit, push, open PR in one command
- Build `/go` — test end-to-end → run `/simplify` → put up PR
- Create analytics skills (bq, SQL) — commit to codebase for whole team
- Reuse skills across every project by committing them to git

### Subagents
- Append "use subagents" to any request for more compute on the problem
- Offload tasks to subagents to keep main context clean
- Route permission requests to Opus via hook — auto-approve safe ones
- Build: `code-simplifier`, `verify-app`, `code-reviewer` agents as standard
- Subagents **cannot** invoke other subagents via bash — use the Agent tool instead

### Verification (Most Important)
- Give Claude a way to verify its work — 2-3x quality improvement
- Backend: have Claude run server/service to test end-to-end
- Frontend: use Chrome extension so Claude controls the browser
- Desktop apps: use Computer Use
- For long tasks: use a background agent to verify when done, or a Stop hook
- Claude tests every single change before shipping

### Context Management
- Sessions degrade around 300-400k tokens
- Use `/compact` with hints rather than auto-compaction
- Use `/rewind` instead of corrections mid-session
- Manual `/compact` at ~50% context usage
- Use `/clear` when switching tasks entirely
- Use subagents to isolate intermediate work and keep main context clean

### Hooks
- `PostToolUse` → auto-format code after every write/edit
- `SessionStart` → dynamically load context each session start
- `PreToolUse` → log every bash command the model runs
- `PermissionRequest` → route to WhatsApp/Slack for approve/deny
- `Stop` → poke Claude to keep going automatically

### Permissions
- Never use `--dangerously-skip-permissions`
- Use `/permissions` to pre-allow safe bash commands
- Check permissions into `.claude/settings.json` for team sharing
- Full wildcard syntax: `Bash(bun run *)`, `Edit(/docs/**)`
- Use **Auto Mode** (Shift+Tab cycle) for Opus 4.7 — model-based classifier auto-approves safe commands

### Loops & Scheduling
- `/loop 5m /babysit` — auto-address code review, auto-rebase, shepherd PRs
- `/loop 30m /slack-feedback` — auto-PRs for Slack feedback
- `/loop 1h /pr-pruner` — close stale PRs
- `/schedule` — cloud-based routines running even when machine is offline
- Turn any workflow into a skill + loop

### Model Selection
- Use Opus with thinking for everything (Boris's personal default)
- Bigger/slower but better tool use → almost always faster overall due to less steering
- Opus 4.7: use adaptive thinking via effort slider (low→max)
- Lower effort = faster/cheaper; higher effort = maximum intelligence
- High effort for everything is Boris's preference

### Power Features
- `/btw` — ask side questions without interrupting agent's current task
- `/branch` or `claude --resume <id> --fork-session` — fork a session
- `/batch` — fan out massive changesets
- `/teleport` — pull cloud session down to local terminal
- `/remote-control` — control local session from phone/web
- `/focus` — hide intermediate work, focus on final result only
- `/loop` + `/schedule` — two most powerful features for automation
- Recaps — short summaries of what agent did (disable in `/config` if unwanted)

### Git Practices
- Keep PRs small (median 118 lines)
- Use squash merging for clean history
- Separate commits per file — never bundle multiple files in one commit
- Use worktrees for feature isolation

### Prompting
- "Grill me on these changes and don't make a PR until I pass your test"
- "Prove to me this works" — have Claude diff main vs feature branch
- "Knowing everything you know now, scrap this and implement the elegant solution"
- "Go fix the failing CI tests" — don't micromanage how
- Use voice dictation — 3x faster than typing, prompts get more detailed
- Prototype 20-30 versions rather than write detailed PRDs

### MCP & Tools
- Enable Slack MCP: paste bug thread and say "fix" — zero context switching
- Use `bq` CLI for analytics — build a BigQuery skill for whole team
- Use Chrome extension every time doing web/frontend work
- Point Claude at docker logs for distributed systems debugging

### Terminal Setup
- Use Ghostty (synchronized rendering, 24-bit color, proper unicode)
- `/statusline` — always shows context usage + git branch
- Color-code and name terminal tabs, one per task/worktree
- Enable shift+enter for newlines via `/terminal-setup`
- Use tmux for multi-session management

---

## Priority Order

1. User's explicit instructions (CLAUDE.md)
2. Skill stack from this router
3. Default system behavior

## Non-Negotiables

- NEVER skip `verification-before-completion` before claiming done
- NEVER skip `systematic-debugging` before proposing fixes
- NEVER skip `brainstorming` before creative/feature work
- ALWAYS invoke `TDD` before writing implementation code
- NEVER use `--dangerously-skip-permissions`
- ALWAYS give Claude a way to verify its work
