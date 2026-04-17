# Global Claude Instructions

## SuperAgent — Active on ALL Sessions

The `superagent` skill and `superagent-brain` agent are always active across every project and session.

- **superagent skill**: `~/.claude/skills/superagent/SKILL.md` — full skill roster + graphify + mempalace + all best practices
- **superagent-brain agent**: `~/.claude/agents/superagent-brain.md` — PROACTIVELY auto-routes every task to the right skill chain

### Activation

- Say "superagent", "activate all agents", or "full power mode" to explicitly invoke
- The `superagent-brain` agent auto-activates on every build / fix / explore / design / review / ship task
- All skills accessible via superagent: `caveman`, `superpowers:*`, `claude-mem:*`, `ui-ux-pro-max`, `claude-api`, graphify, mempalace

### Global Rules (apply in every session)
- Start every complex task in Plan Mode before implementing
- Always give Claude a way to verify its work (2-3x quality improvement)
- Never use `--dangerously-skip-permissions` — use `/permissions` allowlists
- Rewind (`/rewind` or Esc Esc) instead of correcting on failed paths
- After every correction: "Update your CLAUDE.md so you don't make that mistake again"
- Use `/compact <hint>` at ~50% context usage, not auto-compaction
