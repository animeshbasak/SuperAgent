# SuperAgent

A master orchestrator skill for Claude Code that routes every task to the optimal skill stack — with 82+ best practices from Boris Cherny (Claude Code creator) baked in.

## What's Inside

### AI Brain (Auto-Router)

[`agents/superagent-brain.md`](agents/superagent-brain.md) — A PROACTIVE Claude agent that automatically analyzes every incoming task, scores it against all skill triggers, and invokes the optimal skill chain without you having to ask. Uses Opus model. Triggers on build / fix / explore / design / review / ship intents.

### Skills

| Skill | Purpose |
|-------|---------|
| [`skills/superagent/`](skills/superagent/SKILL.md) | Master router skill — includes graphify, all best practices, full skill roster |

### Best Practices

Distilled from [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) — 82+ tips from Boris Cherny and the Claude Code team, organized by category in [`best-practices/`](best-practices/).

## Skill Stack

SuperAgent bundles and routes to these skill groups:

**Planning** — `superpowers:writing-plans`, `superpowers:brainstorming`, `claude-mem:make-plan`

**Execution** — `superpowers:executing-plans`, `superpowers:dispatching-parallel-agents`, `superpowers:subagent-driven-development`, `claude-mem:do`

**Development Quality** — `superpowers:test-driven-development`, `superpowers:systematic-debugging`, `superpowers:verification-before-completion`, `superpowers:using-git-worktrees`, `superpowers:finishing-a-development-branch`

**Code Review** — `superpowers:requesting-code-review`, `superpowers:receiving-code-review`, `review`, `security-review`, `simplify`

**Codebase Intelligence** — `graphify`, `claude-mem:smart-explore`, `claude-mem:mem-search`, `claude-mem:knowledge-agent`, `claude-mem:timeline-report`

**UI/UX** — `ui-ux-pro-max:ui-ux-pro-max`

**API & Infra** — `claude-api`, `update-config`, `schedule`, `loop`

**Communication** — `caveman:caveman`, `caveman:caveman-commit`, `caveman:caveman-review`

## Installation

### Option 1: Copy skills and agent

```bash
cp -r skills/superagent ~/.claude/skills/superagent
cp agents/superagent-brain.md ~/.claude/agents/superagent-brain.md
```

### Option 2: Clone and symlink

```bash
git clone https://github.com/animeshbasak/SuperAgent
ln -s $(pwd)/SuperAgent/skills/superagent ~/.claude/skills/superagent
cp SuperAgent/agents/superagent-brain.md ~/.claude/agents/superagent-brain.md
```

Also install graphify CLI tool:

```bash
pip install graphifyy && graphify install
```

## Usage

Invoke in Claude Code:

```
/superagent
```

Or just say "activate all agents" / "full power mode" — the skill auto-triggers.

## Decision Flow

```
Task received
  ├── Creative / new feature?  → brainstorming → writing-plans → executing-plans
  ├── Bug / failure?           → systematic-debugging → TDD fix → verification
  ├── 2+ independent tasks?    → dispatching-parallel-agents → subagent-driven-development
  ├── Explore codebase?        → smart-explore or graphify → mem-search
  ├── UI work?                 → ui-ux-pro-max → TDD → verification
  ├── Ready to ship?           → requesting-code-review → finishing-a-development-branch
  └── Need past context?       → mem-search → knowledge-agent
```

## Non-Negotiables (from Boris Cherny)

- ALWAYS give Claude a way to verify its work — 2-3x quality improvement
- NEVER use `--dangerously-skip-permissions` — use `/permissions` allowlists instead
- Start every complex task in Plan Mode
- After every correction: "Update your CLAUDE.md so you don't make that mistake again"
- Keep PRs small (median 118 lines), squash merge for clean history

## Best Practices Source

All best practices distilled from:
- [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) (45.7k stars)
- Boris Cherny's tip threads (82+ tips across Jan–Apr 2026)
- Claude Code team workflows

## Author

Built by [animeshbasak](https://github.com/animeshbasak)
