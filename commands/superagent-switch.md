---
description: Run the cost-aware proxy/model switcher (list / to / back / canary / status / auto on|off). Wraps the `superagent-switch` CLI through the `superagent-switch` skill so canary always runs before a flip.
argument-hint: "[list | to <model> | back | canary <model> | status | auto on|off]"
allowed-tools: ["Bash", "Read"]
---

You were invoked via `/superagent-switch $ARGUMENTS`.

Invoke the **`superagent-switch` skill** with the argument string `$ARGUMENTS`
exactly as typed. The skill knows:

- Which CLI subcommand to run (`list`, `to`, `back`, `canary`, `status`, `auto on|off`).
- That `to <model>` MUST be preceded by a `canary <model> --depth=3` unless
  the user explicitly typed `--no-canary`.
- That state lives in `~/.superagent/`, never `~/.claude/`.
- That after a backend flip, the user must restart Claude Code.

If `$ARGUMENTS` is empty, default to `status` — it is the safe read-only op.

After the skill finishes, print the three-line state report
(ran / state / next) defined in the skill, then stop. Do not chain into
other skills unless the user explicitly asks.
