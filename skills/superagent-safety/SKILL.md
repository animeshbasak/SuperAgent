---
name: superagent-safety
description: Reversibility-aware action gate. Universal rule any backend can follow. Triggers BEFORE the agent issues a destructive shell command, force-push, history-rewrite, mass DB mutation, sensitive-file edit, or permission-skip flag. On Claude Code, the hooks/superagent-safety.py PreToolUse hook enforces this same logic at the harness level. Use whenever the request leads toward "rm -rf", "git push --force", "git reset --hard", "DROP", "TRUNCATE", "--no-verify", "--dangerously-skip-permissions", "migrate down", "kill -9", or edits to .env / .ssh / credentials / .pem / .key / /etc.
---

# SuperAgent Safety

> **Doctrine: reversibility over speed.** A pause to confirm costs seconds. An unwanted destructive op costs hours and trust. Always pause-and-ask on irreversible actions, even when the user appears to have asked for them earlier in the session — *authorization is scoped to what was actually requested, not extrapolated from it.*

## When to use

This skill is consulted **before** the agent issues a tool call whose effect is hard to reverse. Triggering signals:

- Bash commands matching the risky list below
- Edit / Write to a sensitive path
- Git operations that rewrite history or overwrite remotes
- Database statements without a `WHERE` clause
- Network egress in `local-only` mode
- Any flag whose name contains `force`, `--no-verify`, `--dangerously-`, `--skip-`

## Risky pattern catalog

### Filesystem
- `rm -rf`, `sudo rm`, `chmod -R 777`, `dd if=… of=/dev/{sd,disk,nvme}`, `mkfs.*`
- Fork bomb (`:(){ :|:& };:`)

### Git history & remotes
- `git push --force` (use `--force-with-lease` if absolutely required, and even then prefer not to)
- `git reset --hard`, `git clean -f`, `git checkout .`, `git restore .`, `git branch -D`
- `git commit --amend` on already-pushed commits
- `--no-verify` (skipping pre-commit hooks); `git rebase -i` (interactive — needs human)

### Database
- `DROP TABLE | DATABASE | SCHEMA | INDEX | VIEW`
- `TRUNCATE TABLE`
- `DELETE FROM <table>` without `WHERE`
- `UPDATE <table> SET …` without `WHERE`
- `migrate down`, `migration:rollback`

### Package & dependency
- `npm uninstall`, `pip uninstall`, package-lock or lockfile deletes, dependency downgrades

### Process & permissions
- `kill -9`, `pkill -9`, `killall -9`
- `--dangerously-skip-permissions` — never. Use `/permissions` instead.

### Sensitive paths (Edit / Write blocked unless pre-authorized)
- `.env`, `.env.*`
- `~/.aws/credentials`, `~/.ssh/id_{rsa,ed25519,dsa,ecdsa}` (and `.pub`)
- Any `*.pem`, `*.key`, `.netrc`
- `/etc/`, `/System/`

## Decision matrix

| Pattern | Decision | Rationale |
|---|---|---|
| Fork bomb / `dd` to raw disk / `mkfs` | **deny** (hard refuse) | No legitimate use during agent work. |
| `rm -rf`, force-push, history rewrite, sensitive-file edit, mass DB mutation | **ask** | Reversibility unclear; user must confirm scope. |
| All other | **allow** | Default trust on the IDE's permission system. |

## Procedure

When you detect a risky action:

1. **Pause** before issuing the tool call.
2. **State the action and the reversibility cost** in one sentence. Example:
   > "About to run `git push --force origin main`. This rewrites the remote history of the protected branch and is hard to undo if collaborators have pulled. Confirm?"
3. **Suggest a safer alternative** when one exists:
   - `git push --force` → `git push --force-with-lease`
   - `git reset --hard` → stash + soft reset
   - `rm -rf <dir>` → `mv <dir> /tmp/superagent-trash-$(date +%s)/`
   - `DROP TABLE` → `RENAME TABLE … TO _archive_…` then `DROP` after a cooling period
4. **Check pre-authorization sources** (only on Claude Code, automatic):
   - `~/.superagent/safety/allow.txt` — one regex per line
   - `~/.claude/CLAUDE.md` section `## SuperAgent Safety Allow`
   - `SUPERAGENT_SAFETY=off` env
5. **If user re-confirms in plain English ("yes do it", "approved", "go ahead"), proceed.** Do not interpret silence or unrelated approvals as consent.

## Anti-patterns

- **Bypassing on the assumption of "they meant this"**: explicit user words on this turn, every time.
- **Adding `|| true` after a risky op to mask failure**: you're hiding signal you should be reading.
- **Renaming the risky op**: `rm -rf` wrapped in a script with a friendly name is still `rm -rf`.
- **Asking once and assuming a session-wide green light**: scope of approval is the operation as described, not similar future ops.

## Bypass surface (only if you know what you're doing)

The user can opt out of any rule by:

- Adding a regex to `~/.superagent/safety/allow.txt` (one per line).
- Adding a bullet under `## SuperAgent Safety Allow` in `~/.claude/CLAUDE.md` with a regex string.
- Setting `SUPERAGENT_SAFETY=off` in the environment for a session-wide bypass.

## Provenance

Distilled from:
- `references/system_prompts_leaks/Anthropic/claude-code.md` — reversibility doctrine
- `references/claude-code-best-practice/.claude/hooks/` — hook-event surface
- `references/ruflo/v3/@claude-flow/hooks/` — PreToolUse interception pattern

The Claude Code harness enforces these rules automatically via
`hooks/superagent-safety.py` (PreToolUse). On other backends (Codex,
Gemini, Copilot, Continue, Aider, Cursor, Windsurf), the agent
self-polices using this skill.
