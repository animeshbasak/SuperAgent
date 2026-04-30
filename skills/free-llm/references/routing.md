# Tier routing

How Claude tiers (Opus / Sonnet / Haiku) map to real model IDs in the `free-claude-code` proxy. Use these IDs verbatim — Engineer A flagged fictional IDs in the audit; everything below has been verified against provider catalogs.

## Local-only (privacy default)

| Claude tier | Model ID | Provider | Context | Notes |
|---|---|---|---|---|
| Opus | `lmstudio/unsloth/MiniMax-M2.5-GGUF` | LM Studio | 192k | Best local tool-calling at Opus weight class. Requires ~64GB VRAM/RAM. |
| Opus (fallback) | `llama-cpp/qwen3.6-27b` | llama.cpp | 128k | Use if MiniMax not loaded. Requires `qwen3.6-27b.gguf` on disk. |
| Sonnet | `ollama/qwen2.5-coder:7b` | Ollama | 32k | Reliable tool calling. Pulls in ~4.7GB. |
| Sonnet (fallback) | `ollama/qwen2.5-coder:32b` | Ollama | 32k | Stronger reasoning if RAM allows. |
| Haiku | `ollama/qwen2.5-coder:7b` | Ollama | 32k | Same as Sonnet — Haiku traffic doesn't justify a separate small model on most rigs. |

## Cloud free-tier (opt-in only)

| Claude tier | Model ID | Provider | Free-tier limit |
|---|---|---|---|
| Opus | `nvidia_nim/qwen/qwen3.5-397b-a17b` | NVIDIA NIM | ~1000 req/day |
| Sonnet | `nvidia_nim/moonshotai/kimi-k2.5` | NVIDIA NIM | ~1000 req/day |
| Haiku | `open_router/stepfun/step-3.5-flash:free` | OpenRouter | 20 req/min, 200/day |

## Fallback chains

If the primary model errors (429, 5xx, canary fail), `superagent-switch` walks the chain. Never silently swap tier — surface the swap.

### Opus chain (local)
1. `lmstudio/unsloth/MiniMax-M2.5-GGUF`
2. `llama-cpp/qwen3.6-27b`
3. (if `--cloud`) `nvidia_nim/qwen/qwen3.5-397b-a17b`
4. (if user accepts) `deepseek/deepseek-reasoner`

### Sonnet chain (local)
1. `ollama/qwen2.5-coder:32b` (if installed)
2. `ollama/qwen2.5-coder:7b`
3. (if `--cloud`) `nvidia_nim/moonshotai/kimi-k2.5`

### Haiku chain (local)
1. `ollama/qwen2.5-coder:7b`
2. (if `--cloud`) `open_router/stepfun/step-3.5-flash:free`
3. (if `--cloud`) `open_router/meta-llama/llama-3.3-70b-instruct:free`

## Why these IDs

- **MiniMax-M2.5-GGUF** — verified Unsloth GGUF release on HF. Loads in LM Studio. Tool-calling works in canary depth ≥ 5.
- **qwen3.6-27b** — local-Opus alternative for users with llama.cpp set up; smaller than MiniMax but still robust.
- **qwen2.5-coder:7b** — the safe default. Tool-call schema compliance is the highest among 7b-class open weights as of Apr 2026.
- **nvidia_nim/qwen/qwen3.5-397b-a17b** — Qwen 3.5 MoE on NIM, free tier. Closest open model to Opus quality.
- **nvidia_nim/moonshotai/kimi-k2.5** — Kimi K2.5 on NIM, free tier. Strong Sonnet replacement.
- **open_router/stepfun/step-3.5-flash:free** — fast, free `:free` variant on OpenRouter; good for Haiku-tier latency-sensitive calls.

## Picking a model for `switch <model>`

When the user runs `free-llm switch <model>`, accept either a tier name (`opus`/`sonnet`/`haiku`) — which picks chain head — or a literal LiteLLM model id with prefix. Reject bare model names without prefix; LiteLLM cannot resolve them.

Examples:
- `free-llm switch sonnet` → `ollama/qwen2.5-coder:7b`
- `free-llm switch ollama/qwen2.5-coder:32b` → exact model
- `free-llm switch qwen2.5-coder:32b` → ERROR: prefix required
