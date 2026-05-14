---
name: dynamic-skills
---
# dynamic-skills

> |

# dynamic-skills

Distilled from **jcode** (https://github.com/1jehuang/jcode) — specifically
[Phase 1 of PLAN_MCP_SKILLS.md](https://github.com/1jehuang/jcode/blob/main/PLAN_MCP_SKILLS.md):

> Skills can be reloaded without restarting. New tool `reload_skills`: agent can
> trigger `reload_skills` to pick up new skills.

jcode is Rust. We're not vendoring it — we're capturing the *intent* in bash.

---

## What it does

Diffs and mirrors skill files between two source directories:

- **Repo**: `./skills/<name>/SKILL.md` (this superagent checkout, project-local)
- **Claude**: `~/.claude/skills/<name>/SKILL.md` (what Claude Code actually loads at startup)

If a skill exists in the repo but not in `~/.claude/skills/`, the next session won't
see it. `superagent-reload sync` fixes that by copying the dir over.

---

## Important limit (read this first)

**Claude Code does not expose a runtime skill-reload API to hooks or to skills
themselves.** A hook can edit files on disk, but it cannot force the active
Claude Code process to rescan the skills directory mid-session.

The bin can *prepare* the filesystem. The actual pickup requires one of:

1. The user types `/reload` in the active session, OR
2. The user restarts the Claude Code session (Ctrl-D → re-launch), OR
3. A new session is started after the sync ran.

Do not promise "live" hot-reload. We mirror files; the harness decides when to
re-scan them. This is the difference between us and jcode's Rust implementation
where the registry is owned by the same process.

---

## Procedure

1. **Diff.** Run `superagent-reload list` to see:
   - skills present in both repo and `~/.claude/skills/`
   - skills only in the repo (will need sync)
   - skills only in `~/.claude/skills/` (likely third-party or stale)

2. **Sync.** Run `superagent-reload sync` to copy any repo skill dirs that are
   missing or older than the `~/.claude/skills/` copy. Use `--dry-run` first if
   the user wants to preview the changes.

3. **Diff a single skill** (optional): `superagent-reload diff <name>` shows a
   `diff -u` between the repo's SKILL.md and the installed copy.

4. **Trigger the rescan.** Tell the user to type `/reload`, or note that the
   new skill will be active on next session start. The skill never lies about
   forcing a live reload.

5. **Status.** `superagent-reload status` for the one-line summary
   (N in repo, N in claude, N out-of-sync).

---

## When NOT to use this

- For adapter sync (Codex, Continue, Aider, Cursor) — that's `bin/superagent-install`.
- For learning new routing patterns — that's `superagent-learn-loop`.
- For installing third-party skills from a registry — out of scope.

---

## Credit

- jcode: https://github.com/1jehuang/jcode
- Phase 1 of the dynamic-skills plan:
  https://github.com/1jehuang/jcode/blob/main/PLAN_MCP_SKILLS.md
