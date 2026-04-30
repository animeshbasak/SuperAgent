---
name: free-llm
---
# free-llm

> Route Claude Code through free or local LLMs via the free-claude-code transparent proxy on :18082. Triggers on "switch to free", "use local model", "no Anthropic key", "ollama", "deepseek", "use local llm", "free LLM". Privacy default is local-only (Ollama / LM Studio / llama.cpp); cloud free-tier (NIM / OpenRouter / DeepSeek) is opt-in. Token-savings questions stay with token-stats.

# free-llm

Wire Claude Code's outbound API calls through the `free-claude-code` proxy so the session runs on local or free-tier models instead of paid Anthropic. Default is **local-only** for privacy; cloud free-tier is opt-in.

## When to use

- User says "switch to free", "use local model", "no Anthropic key", "use local llm", "free LLM", "use ollama", "use deepseek".
- User has hit Anthropic rate limits or quota and wants to keep working.
- User wants offline / air-gapped operation.
- User explicitly opts into cloud free tier (NIM, OpenRouter, DeepSeek).

**Do NOT use for:**
- "How many tokens did I save?" → that is `token-stats`.
- "Save tokens" / "compress context" → that is `token-stats` + caveman.
- Choosing a *paid* Anthropic model — that is regular Claude Code.

## Procedure

### 0. Parse the argument

- `setup` (default if no arg) → run full install + start flow.
- `switch <model>` → re-route to a specific tier model, restart proxy.
- `back` → unset `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`, restore prior `ANTHROPIC_API_KEY`.
- `status` → curl `/health`, show current routing, exit.

### 1. Check if proxy is already running

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:18082/health
```

- `200` → proxy live; skip start (step 7). Jump to canary if `setup`/`switch`.
- non-200 / curl error → continue to install/start.

### 2. Verify `superagent-switch` CLI is available

```bash
command -v superagent-switch
```

If missing, point user to `bundles/free-claude-code/install.sh` and stop. Do not attempt manual install — installation is delegated.

### 3. Verify `free-claude-code` is installed

Check `~/.superagent/free-claude-code/.venv/bin/free-cc` exists. If not:

```
SuperAgent has not installed free-claude-code yet.
Run: bash bundles/free-claude-code/install.sh
That will: git clone repo, uv venv --python 3.14, uv sync.
```

Stop and surface this to the user. Do not pipx — package is not on PyPI.

### 4. Probe local providers (privacy default)

```bash
ollama list 2>/dev/null
curl -sf http://localhost:1234/v1/models 2>/dev/null   # LM Studio
curl -sf http://localhost:8080/v1/models 2>/dev/null   # llama.cpp server
```

Record which providers responded. If none are up, surface:

```
No local LLM provider detected. Start one of:
  - ollama serve  (then: ollama pull qwen2.5-coder:7b)
  - LM Studio (load a model, start server on :1234)
  - llama.cpp server on :8080
Or pass --cloud to opt into free cloud tier (NIM / OpenRouter / DeepSeek).
```

### 5. Show tier mapping recommendation

Default (local-only):

| Claude tier | Routed to | Provider |
|---|---|---|
| Opus | `lmstudio/unsloth/MiniMax-M2.5-GGUF` | LM Studio |
| Sonnet | `ollama/qwen2.5-coder:7b` | Ollama |
| Haiku | `ollama/qwen2.5-coder:7b` | Ollama |

Cloud opt-in (only if user passes `--cloud` or local probe failed and user confirms):

| Claude tier | Routed to | Provider |
|---|---|---|
| Opus | `nvidia_nim/qwen/qwen3.5-397b-a17b` | NVIDIA NIM |
| Sonnet | `nvidia_nim/moonshotai/kimi-k2.5` | NVIDIA NIM |
| Haiku | `open_router/stepfun/step-3.5-flash:free` | OpenRouter |

See `references/routing.md` for the complete table and fallback chains.

### 6. Write `~/.superagent/free-llm.env`

If `~/.superagent/free-llm.env` exists, back it up to `free-llm.env.bak.<timestamp>` then overwrite. Always emit BOTH variables — `free-claude-code` rejects requests missing either:

```
ANTHROPIC_BASE_URL=http://localhost:18082
ANTHROPIC_AUTH_TOKEN=freecc
SUPERAGENT_FREE_LLM_TIER=local
SUPERAGENT_FREE_LLM_OPUS=lmstudio/unsloth/MiniMax-M2.5-GGUF
SUPERAGENT_FREE_LLM_SONNET=ollama/qwen2.5-coder:7b
SUPERAGENT_FREE_LLM_HAIKU=ollama/qwen2.5-coder:7b
```

If user already has `ANTHROPIC_API_KEY` in env, write it to `~/.superagent/free-llm.env.prev` so `back` can restore it.

### 7. Start the proxy in background

```bash
superagent-switch start --port 18082 --env ~/.superagent/free-llm.env
```

Wait up to 5s, then verify:

```bash
curl -s http://localhost:18082/health
```

If port 18082 is already bound by a non-superagent process, fall back to 18083 (rewrite the env file accordingly) and emit a warning. Never silently use a different port — the user's `ANTHROPIC_BASE_URL` must match.

### 8. Run canary tool-call

Delegate to `superagent-switch`:

```bash
superagent-switch canary <opus-model> --depth=3
```

A depth-3 canary exercises a real tool-calling loop — it is the only reliable check that an open-weights model can survive Claude Code's tool-call schema. If it fails, **do not switch**. Surface the error and tell the user to either pick a different model (`switch <model>`) or stay on Anthropic.

### 9. Tell the user to restart Claude Code

```
free-llm proxy live on :18082, canary passed.
Routing: Opus→<x>  Sonnet→<y>  Haiku→<z>
RESTART your Claude Code session for ANTHROPIC_BASE_URL to take effect.
Run `free-llm back` to revert.
```

## Verification

Before declaring success, ALL of:

1. `curl -s http://localhost:18082/health` returns 200.
2. `superagent-switch canary` exited 0 with depth ≥ 3.
3. Both `ANTHROPIC_BASE_URL=http://localhost:18082` and `ANTHROPIC_AUTH_TOKEN=freecc` are present in `~/.superagent/free-llm.env`.
4. `~/.superagent/free-llm.env.prev` exists if the user previously had `ANTHROPIC_API_KEY` set.

If any check fails, do not claim the switch worked.

## Edge cases

- **Proxy already running on :18082** — reuse existing process; do not double-start. Confirm it is the SuperAgent-namespaced instance (probe `/superagent` endpoint or check pidfile at `~/.superagent/free-claude-code.pid`); if a foreign process holds the port, fall back to 18083.
- **Port collision (:18082 bound by foreign process)** — fall back to :18083, rewrite env file, log a warning. Never silently ignore.
- **Stale `~/.superagent/free-llm.env` from a previous session** — back up to `free-llm.env.bak.<unix-ts>` then overwrite.
- **Existing `ANTHROPIC_API_KEY` in user env** — back up to `~/.superagent/free-llm.env.prev` BEFORE writing the new env. `free-llm back` restores it.
- **Canary fails** — abort. Do not write env. Surface the model-id and the failing tool-call. Suggest a smaller-tier fallback from `references/routing.md`.
- **Context window truncation** — local models with smaller contexts (8k–32k) silently drop turns. Detect via canary depth-3; document in `references/troubleshooting.md`.
- **Tool-call schema mismatch** — many open-weights models malform tool-call JSON. The canary catches this. See `references/troubleshooting.md`.
- **429 from cloud free tier** — auto-fall to next provider in chain (`references/routing.md`); surface persistent 429s.
- **`back` with no prior key** — just unset `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`. Note Claude Code will fail until user supplies a key.

## References

- `references/providers.md` — provider matrix (NIM, OpenRouter, Ollama, LM Studio, llama.cpp, DeepSeek): endpoints, auth, free-tier limits, install.
- `references/routing.md` — tier → model mapping with real model IDs and fallback chains.
- `references/troubleshooting.md` — 429s, tool-call failures, port conflicts, context truncation, canary diagnostics.
