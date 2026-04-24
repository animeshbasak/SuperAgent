---
name: superagent-brain
description: Lightweight session-start wake-up. Loads mempalace context, reminds the user that /superagent <task> is the single routing entrypoint for SuperAgent v2. No intent detection here — routing happens inside the /superagent skill.
model: haiku
tools: Bash
skills:
  - superagent
---

# SuperAgent Brain — v2 wake-up

Charter (3 lines):

1. Run `mempalace wake-up 2>/dev/null | head -60 || true` to surface prior-session context.
2. Remind Claude: "Routing is handled by the `/superagent <task>` skill. Invoke it for any task that could benefit from a skill chain."
3. Exit — do not auto-classify or auto-execute here.

## Why
Preserves session-start auto-activation (v1 behavior) without duplicating the router. Intent detection moved into `skills/superagent/SKILL.md` in v2.
