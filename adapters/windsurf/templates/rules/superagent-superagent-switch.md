# superagent-switch

> Drive the `superagent-switch` CLI to inspect, swap, or restore the active LLM backend. Triggers on "list local models", "switch to <model>", "switch back", "restore anthropic", "canary <model>", "what model am i on", "auto fallback on/off", "/superagent-switch <op>". Use when the user wants direct, surgical control over the model swap — not when they're asking *whether* to switch (that is `auto-fallback`) or *how to set up* the proxy (that is `free-llm`).

# superagent-switch

Surgical operator for the cost-aware proxy / model switcher. Wraps the
`superagent-switch` CLI in a thin, deterministic skill so the agent always
runs the *right* subcommand, parses output the same way, and reports state
back to the user in a consistent shape.

## When to use

- User typed `/superagent-switch <op>` (one of: `list`, `to`, `back`,
  `canary`, `status`, `auto`).
- User said "list local models", "switch to qwen3", "switch back to
  Anthropic", "what backend am I on", "run a canary on …", "turn auto-fallback
  on/off".
- A peer skill (`auto-fallback`, `free-llm`) needs to perform the actual
  switch — it dispatches here.

**Do NOT use for:**
- Deciding *whether* to switch — that is `auto-fallback`.
- First-time proxy install / setup — that is `free-llm`.
- Token-savings questions — that is `token-stats`.

## Subcommand routing

| Op                          | What it does                                            | When |
| --------------------------- | ------------------------------------------------------- | ---- |
| `list`                      | Enumerate detected local models (Ollama / LM Studio / llama.cpp). Always safe; no state change. | First call when the user asks "what's available" or before `to`. |
| `to <model>`                | Set `ANTHROPIC_BASE_URL` → `http://localhost:18082`, set token, route Claude Code through the free-claude-code proxy with the given local model. | After `canary` passes, or when user explicitly demands the swap. |
| `back`                      | Unset proxy env, restore the prior `ANTHROPIC_API_KEY`. | User says "switch back", "restore anthropic", "kill local". |
| `canary <model> --depth=N`  | Run an N-step Read → Edit → Bash sanity probe against the model. Default N=3. | Always before `to <model>` unless user explicitly skips. |
| `status`                    | Show current backend, model, auto-flag, last canary. No state change. | Health check, "what am I on". |
| `auto on` / `auto off`      | Toggle `~/.superagent/auto-fallback.flag`.              | User says "turn auto on/off". |
| `help`                      | Print CLI help.                                         | Unknown op. |

## Procedure

### 0. Parse the argument

If invoked via `/superagent-switch <args>`, the first token is the
subcommand. Default to `status` if no subcommand is given (safest read-only
op). If `args` look like a bare model name (e.g. `qwen2.5-coder:7b`), treat
as `to <model>` and **require** a `canary` first — never bypass the canary
unless the user explicitly types `--no-canary`.

### 1. Verify the CLI exists

```bash
command -v superagent-switch
```

If missing, point user to `bundles/free-claude-code/install.sh` and stop.
Do not attempt to install via `npm` / `pip` / `brew` directly.

### 2. Run the subcommand

| User intent                                      | Exact command                                  |
| ------------------------------------------------ | ---------------------------------------------- |
| "what's available"                               | `superagent-switch list`                       |
| "what am I on right now"                         | `superagent-switch status`                     |
| "switch to qwen3-coder:next" (first time)        | `superagent-switch canary qwen3-coder:next --depth=3` then on pass `superagent-switch to qwen3-coder:next` |
| "switch back to anthropic"                       | `superagent-switch back`                       |
| "test if qwen2.5 works without switching"        | `superagent-switch canary qwen2.5-coder:7b --depth=3` |
| "auto-fallback on" / "off"                       | `superagent-switch auto on` / `auto off`       |

### 3. Report the result back

After every op, print **three lines** to the user:

1. **What ran** — exact CLI command.
2. **What changed** — diff of state (backend / model / auto-flag).
3. **What's next** — restart Claude Code if the backend flipped, or "no
   action required" if it was a read-only op.

Example after a successful `to qwen3-coder:next`:

```
ran:    superagent-switch to qwen3-coder:next
state:  backend Anthropic → free-claude-code (localhost:18082) · model → qwen3-coder:next
next:   restart Claude Code so the new env is picked up
```

### 4. Failure handling

- **Canary fails** → DO NOT call `to`. Surface the canary log verbatim and
  ask the user: try a different model, wait, or stay on Anthropic.
- **`to` fails** (proxy down, port conflict) → run `superagent-switch
  status` to confirm current state, then prompt to run `free-llm setup`.
- **`back` fails** (env restore broken) → tell the user to manually
  `unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN` and restart their shell;
  do not silently retry.

### 5. Never

- Run `to <model>` without a passing canary (unless `--no-canary`).
- Edit `~/.superagent/state.json` by hand — always go through the CLI.
- Touch anything in `~/.claude/` — switcher state lives in `~/.superagent/`.
- Skip restart instructions after a backend flip.

## Verification

After the op, the skill is done iff:

- [ ] CLI exited 0.
- [ ] If state changed: `superagent-switch status` confirms the new state.
- [ ] User has been told whether they need to restart Claude Code.

## Slash command

A Claude Code slash command at `commands/superagent-switch.md` invokes this
skill with `$ARGUMENTS` so users can type:

```
/superagent-switch list
/superagent-switch to qwen3-coder:next
/superagent-switch back
/superagent-switch canary qwen2.5-coder:7b
/superagent-switch status
/superagent-switch auto on
```
