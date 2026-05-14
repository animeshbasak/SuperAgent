---
name: agent-pool
---
# agent-pool

> Multi-Claude-Code session orchestration. Spawn, list, tag, and abandon parallel coding agents — each with its own scoped context window, working directory, and conversation history. Triggers on "agent pool", "spawn agent", "spawn another claude", "parallel sessions", "dispatch agent", "octogent", "multi-agent orchestration", "claude code session".

# agent-pool

Coordinate multiple Claude Code sessions running in parallel against the same workspace, each with its own scoped task, context window, and conversation history. Distilled from [octogent](https://github.com/hesamsheikh/octogent) by Hesam Sheikh ([Discord: Open Source AI Builders](https://discord.gg/vtJykN3t)) — the multi-Claude-Code orchestrator that introduced the "tentacle" abstraction.

The original octogent is a Hono + React app with a websocket-driven UI. We distill the *pattern* — session enumeration, tagging, and dispatch — into a thin bash CLI (`superagent-pool`) + cooperative directive emission. No daemon. No long-lived server. The harness (or you) does the actual spawning via the Agent tool.

## When to use

- The user has ≥3 truly parallel workstreams (docs + db + frontend + API) and wants each in its own session with its own context window.
- The user says "spawn another agent", "run this in parallel", "dispatch a Claude Code session for X", "fork a tentacle".
- The user is juggling too many open terminals and wants a status board (`superagent-pool list`).
- The user wants to *tag* a long-running session so they can recognize it later ("the one fixing payments").
- The user wants to *abandon* a stuck or no-longer-relevant session without killing the OS process.

## When NOT to use

- **Sequential specialist work in one session.** That is the Wave 2 specialist-agents skill (architect → coder → tester role swaps inside one context window). Use Wave 2 when you want *roles*, agent-pool when you want *parallel sessions*.
- **In-session parallel tool calls.** Use `fanout` / `dispatching-parallel-agents` when subtasks share the parent's context and the parent can merge their reports.
- **Subagents within the current Claude Code session.** That's the built-in Agent tool — agent-pool is for *new top-level Claude Code sessions* (each its own conversation tree under `~/.claude/projects/`).

## Hand-off rules

| Situation                                                | Skill                          |
| -------------------------------------------------------- | ------------------------------ |
| One session, multiple roles, sequential                  | Wave 2 specialist agents       |
| One session, independent subtasks, in-context merge      | `fanout` / `dispatching-parallel-agents` |
| ≥3 truly parallel top-level sessions, scoped contexts    | **agent-pool**                 |
| Schedule recurring work for later                        | `autopilot` + `ScheduleWakeup` |

## Procedure

1. **Survey the field.** Enumerate the Claude Code sessions already running on this machine:
   ```bash
   superagent-pool list
   superagent-pool list --json
   ```
   This walks `~/.claude/projects/` — one directory per project, JSONL files per session — same pattern octogent uses in `claudeSessionScanner.ts`.

2. **Decide whether to spawn.** If the user wants a new parallel session, emit a dispatch directive:
   ```bash
   superagent-pool spawn "fix the payments webhook in /apps/api"
   ```
   This **does not actually spawn a process.** It prints a JSON directive:
   ```json
   {"directive":"spawn-claude","cwd":"/Users/...","description":"...","sessionTag":"abc12345"}
   ```
   The calling agent (you) is responsible for invoking the Agent tool with this brief — the same cooperative pattern autopilot uses with `ScheduleWakeup`. No daemon, no privileged spawning.

3. **Tag long-running sessions.** When a session has a recognizable purpose, tag it so the human (and future you) can find it:
   ```bash
   superagent-pool tag <session-id> "payments webhook refactor"
   ```
   Tags persist in `~/.superagent/pool/tags.jsonl`.

4. **Abandon stuck sessions.** If a session has gone sideways and the user wants to stop relying on it (but does not want you to `kill -9` a process you do not own):
   ```bash
   superagent-pool kill <session-id>
   ```
   This appends an abandon record to `~/.superagent/pool/abandons.jsonl`. The user can still scroll their actual terminal back; agent-pool just marks the session as "not part of the current plan".

5. **Status board.**
   ```bash
   superagent-pool status
   ```
   Summarizes: N active sessions, N tagged, N abandoned.

## State

All state lives under `~/.superagent/pool/`:

- `tags.jsonl` — one record per tag: `{"sessionId":"...","description":"...","ts":"<iso>"}`
- `abandons.jsonl` — one record per abandon: `{"action":"abandon","sessionId":"...","ts":"<iso>"}`

Read-only sources:

- `~/.claude/projects/<project-slug>/<session-id>.jsonl` — Claude Code's own session log.

## Limits and honesty

- agent-pool **does not own** any OS process. It cannot `kill -9` Claude Code; it only records intent in `abandons.jsonl`.
- agent-pool **does not spawn** Claude Code directly. It emits a directive; the Agent tool does the actual work.
- agent-pool **does not communicate** between sessions. octogent has websocket inter-agent messaging; we omit that. Use the filesystem (`docs/handoff/*.md`) or octogent itself if you need real coordination.

This is intentionally the thinnest possible distillation of the pattern. For the full vision — tentacles, todo.md execution surfaces, inter-agent messaging — install octogent.

## Credits

octogent — [github.com/hesamsheikh/octogent](https://github.com/hesamsheikh/octogent) by [Hesam Sheikh](https://x.com/Hesamation). Discord: [Open Source AI Builders](https://discord.gg/vtJykN3t).
