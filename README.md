# SuperAgent for Claude Code

> What if every Claude Code session started already knowing your codebase, your past decisions, and exactly which expert to call?

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install.sh
```

One command. Restart Claude Code. Type `superagent`. That's it.

---

## The problem with Claude Code out of the box

Every session, you re-explain the same codebase. Claude reads 40 files to answer one question. It forgets what you decided last Tuesday. It dives into code before you've agreed on a plan. It says "done" when it isn't.

You're losing hours. And tokens.

---

## What SuperAgent adds

**A routing brain** — analyzes every task and automatically activates the right skill chain. "Fix this bug" triggers systematic debugging → TDD → verification, in that order, every time.

**A knowledge graph** — `graphify` indexes your entire codebase into a queryable graph. One query replaces reading 71 files. Your real compression ratio — measured from *your* codebase, not a benchmark — is tracked and shown in your statusline.

**A memory system** — `mempalace` stores cross-session context locally. No API key. 96.6% retrieval accuracy. Claude walks into your project already knowing what matters.

**20+ expert skills** — TDD, planning, systematic debugging, parallel agents, security review, code quality, UI/UX design intelligence, and more. Each one enforces discipline you'd otherwise skip at 11pm.

**A token savings badge** — your statusline shows exactly how much context you've avoided loading, measured from your actual index:

```
[SA: ~231k saved | 48x]
```

---

## Install

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install.sh
```

**What runs automatically:**
- Installs 5 Claude plugins + 2 Python tools (via pipx, auto-installed if missing)
- Indexes `~/.claude` into mempalace
- Builds graphify knowledge graph of all installed skills
- Wires the token savings tracker into your statusline
- Calibrates compression ratio from your actual codebase

**After install:** restart Claude Code, type `superagent`.

**Requirements:** Claude Code CLI, Node.js 18+, macOS/Linux

---

## How it works

Type `superagent` (or start any build/fix/review task). The routing brain reads your intent and activates the right stack:

| Intent | Skill chain activated |
|--------|----------------------|
| "build X" / "add feature" | brainstorming → writing-plans → TDD → verification |
| "fix bug" / "broken" | systematic-debugging → TDD → verification |
| "understand codebase" | graphify query → smart-explore |
| "ship" / "PR" / "done" | verification → finishing-branch |
| "design" / "UI" | ui-ux-pro-max → TDD → verification |
| "did we solve this?" | mempalace search → mem-search |

No configuration. No manual skill selection. It just routes.

---

## Token savings tracker

After running `graphify update` on your project, SuperAgent measures your real compression ratio and starts tracking:

```
$ /token-stats

SuperAgent Token Stats — /your/project
──────────────────────────────────────────────
Compression ratio : 48.3x  (your codebase, measured 2026-04-17)
──────────────────────────────────────────────
Lifetime
  Graphify queries  : 47      → 198k tokens saved
  Mempalace hits    : 23      → ~31k tokens saved (estimate)
  Total saved       : ~229k tokens

Last 5 sessions
  Date          Graphify    Mempalace   Saved
  2026-04-17    12          4           ~58k
  2026-04-16    8           2           ~38k
  2026-04-15    15          6           ~71k
──────────────────────────────────────────────
```

The ratio is yours — measured from your actual index, not the 71.5x benchmark number. Your statusline shows it live.

---

## What's installed

| Tool | Purpose |
|------|---------|
| **superagent** | Routing brain — activates this whole system |
| **superpowers** | 20+ workflow skills (TDD, planning, debugging, reviews) |
| **caveman** | ~75% token reduction mode for terse sessions |
| **claude-mem** | Cross-session memory + AST-level code search |
| **ui-ux-pro-max** | Frontend design intelligence (50+ styles, 161 palettes) |
| **graphify** | Codebase knowledge graph, token-efficient queries |
| **mempalace** | Local-first AI memory, no API key required |

---

## Index your project

```bash
cd ~/my-project
graphify update ./src          # build knowledge graph
mempalace init . --yes && mempalace mine .   # index for memory
```

Then in Claude Code:

```
graphify query "how does authentication work?"
mempalace search "auth decisions"
```

---

## Manual Python install (if Homebrew unavailable)

```bash
pip install pipx && pipx ensurepath
pipx install graphifyy
pipx install mempalace
mempalace init ~/.claude --yes && mempalace mine ~/.claude
cd ~/.claude && graphify update skills
```

---

## Links

- [graphify](https://github.com/animeshbasak/graphifyy) — knowledge graph engine
- [mempalace](https://github.com/animeshbasak/mempalace) — local AI memory
- [superpowers](https://github.com/claude-plugins-official/superpowers) — 20+ workflow skills
- [claude-mem](https://github.com/thedotmack/claude-mem) — cross-session observations

---

If this saved you time, star it. If it saved you tokens, `/token-stats` will tell you exactly how many.
