# Troubleshooting

Common failures when routing Claude Code through `free-claude-code` on :18082, with diagnosis and fix.

## 429 / rate-limit from cloud free tier

**Symptom:** proxy logs `429 Too Many Requests` from `nvidia_nim` or `open_router`. Claude Code stalls on tool calls.

**Diagnosis:**
- NVIDIA NIM free tier: ~1000 req/day per model. Tool-call loops hit this fast.
- OpenRouter `:free` variants: 20 req/min, 200/day across free credits.

**Fix:**
1. `superagent-switch chain --next` — falls to next entry in `references/routing.md` chain.
2. Switch tier to local: `free-llm switch ollama/qwen2.5-coder:7b`.
3. Wait until reset (NIM resets at 00:00 UTC; OpenRouter rolling-window).
4. If you keep hitting 429s, your workflow is too chatty for free tier — consider DeepSeek paid (`deepseek/deepseek-reasoner`, ~$0.14/MTok) or accept Anthropic.

## Tool-call malformed / "Could not parse tool input"

**Symptom:** Claude Code shows `tool_use` blocks but execution fails with JSON parse errors, or the model emits XML when JSON was expected.

**Diagnosis:** Open-weights model is not honoring the tool-call schema. Most common on:
- 7b-and-under models without coder/instruct fine-tunes.
- Llama-3.x base models (use Instruct variants only).
- Any model loaded into LM Studio without the right chat template.

**Fix:**
1. Run canary at depth 5: `superagent-switch canary <model> --depth=5`.
2. If canary fails, switch chain head: `free-llm switch <next>`.
3. In LM Studio, verify the chat template matches the model card (Qwen template for Qwen, Llama-3 template for Llama).
4. Stick to coder/instruct fine-tunes for tool calls (`qwen2.5-coder`, `kimi-k2.5`, `MiniMax-M2.5`).

## Port :18082 already in use

**Symptom:** `superagent-switch start` errors with `EADDRINUSE` or proxy never becomes healthy.

**Diagnosis:**
```bash
lsof -nP -iTCP:18082 -sTCP:LISTEN
```

If the listener is `free-cc` or matches `~/.superagent/free-claude-code.pid`, it is **the same proxy** — reuse it, do not restart.

If it is a foreign process, fall back to :18083:

**Fix:**
1. Rewrite `~/.superagent/free-llm.env`: change `ANTHROPIC_BASE_URL=http://localhost:18083`.
2. Restart proxy: `superagent-switch start --port 18083 --env ~/.superagent/free-llm.env`.
3. Tell the user — they MUST restart Claude Code for the new base URL to take effect.

Never silently use a different port from what is in the env file: Claude Code reads `ANTHROPIC_BASE_URL` once at session start.

## Context truncation / model "forgets" earlier turns

**Symptom:** Local model loses context mid-task — references files/decisions that were in earlier turns as if they never happened.

**Diagnosis:** Local model context window is smaller than the conversation needs. Common culprits:
- Ollama defaults to 2048 ctx unless overridden — set `OLLAMA_CONTEXT_LENGTH=32768` or pass `num_ctx` in modelfile.
- LM Studio: ctx is whatever you set in the load dialog; reload at higher ctx.
- llama.cpp: pass `-c 32768` to `llama-server`.

**Fix:**
1. Verify ctx: `curl localhost:11434/api/show -d '{"name":"qwen2.5-coder:7b"}'` for Ollama.
2. Restart provider with full 32k or 128k ctx as model supports.
3. If conversation legitimately exceeds model max, run `/compact` before continuing.

## Canary fails at depth 3

**Symptom:** `superagent-switch canary <model> --depth=3` returns non-zero. `free-llm` aborts the switch (correct).

**Diagnosis:** Model can do single-turn tool calls but breaks down on multi-turn chains. This is an Anthropic-API-shape mismatch, not a bug in `free-claude-code`.

**Fix:**
1. Try a stronger model in the same tier (`free-llm switch <next-in-chain>`).
2. For Opus tier, MiniMax-M2.5 and Qwen3.5-397b-a17b reliably pass depth 3+. Smaller open models often fail at depth 2.
3. If every model in chain fails, the issue is likely your local provider's chat template — recheck step "Tool-call malformed" above.

## `back` does not restore Anthropic auth

**Symptom:** After `free-llm back`, Claude Code still hits the proxy or fails with no API key.

**Diagnosis:** `back` only unsets `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN`. If `ANTHROPIC_API_KEY` was not in the user's shell profile and was only set for the previous session, there is nothing to restore.

**Fix:**
1. Check `~/.superagent/free-llm.env.prev` — if it exists, that was the captured prior key. `source` it or restore it manually.
2. Otherwise, set `ANTHROPIC_API_KEY` in your shell profile and start a new shell + new Claude Code session.

## Proxy is healthy but Claude Code still goes to api.anthropic.com

**Symptom:** `curl localhost:18082/health` returns 200 but Claude Code is clearly hitting Anthropic (paid usage shows up).

**Diagnosis:** The Claude Code session was started before `ANTHROPIC_BASE_URL` was set. Env vars are read once at session start.

**Fix:** Fully quit Claude Code (close all tabs/windows), confirm `echo $ANTHROPIC_BASE_URL` returns `http://localhost:18082`, then restart Claude Code.

## ANTHROPIC_AUTH_TOKEN missing → 401 from proxy

**Symptom:** Claude Code errors with 401 Unauthorized even though the proxy is up.

**Diagnosis:** `free-claude-code` requires the `ANTHROPIC_AUTH_TOKEN` header to be set (any non-empty value; default `freecc`). If only `ANTHROPIC_BASE_URL` is set, Claude Code sends no auth header and the proxy refuses.

**Fix:** Confirm both env vars are present:
```bash
env | grep -E '^ANTHROPIC_(BASE_URL|AUTH_TOKEN)='
```
Both must be set. `~/.superagent/free-llm.env` always emits both — if only one shows up, the env file was not sourced. Restart Claude Code.
