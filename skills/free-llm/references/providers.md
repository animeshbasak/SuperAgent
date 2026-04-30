# Provider matrix

All providers `free-llm` can route through. Local providers are the privacy default; cloud entries are opt-in.

## Local (privacy default)

### Ollama
- **Endpoint:** `http://localhost:11434/v1` (OpenAI-compat)
- **Auth:** none
- **Install:** `brew install ollama` then `ollama serve`
- **Pull models:** `ollama pull qwen2.5-coder:7b`
- **Probe:** `ollama list`
- **Best for:** Sonnet/Haiku tiers. Tool-calling reliable on `qwen2.5-coder:7b` and `qwen2.5-coder:32b`.
- **Context:** 32k native on qwen2.5-coder.
- **free-cc model id prefix:** `ollama/`

### LM Studio
- **Endpoint:** `http://localhost:1234/v1` (OpenAI-compat)
- **Auth:** none (local)
- **Install:** download from lmstudio.ai, load a GGUF, start server.
- **Probe:** `curl -sf http://localhost:1234/v1/models`
- **Best for:** Opus tier on big GGUFs (MiniMax-M2.5, Qwen3.6-27b).
- **Context:** model-dependent; verify in LM Studio UI.
- **free-cc model id prefix:** `lmstudio/`

### llama.cpp server
- **Endpoint:** `http://localhost:8080/v1` (OpenAI-compat via `--api`)
- **Auth:** none
- **Install:** `brew install llama.cpp` then `llama-server -m model.gguf --port 8080 --api`
- **Probe:** `curl -sf http://localhost:8080/v1/models`
- **Best for:** custom GGUFs, Apple Silicon Metal.
- **free-cc model id prefix:** `llama-cpp/`

## Cloud free-tier (opt-in)

Cloud providers send your prompts off-machine. `free-llm` only routes here when the user explicitly opts in (`--cloud`) or all local providers are down and the user confirms.

### NVIDIA NIM
- **Endpoint:** `https://integrate.api.nvidia.com/v1`
- **Auth:** `NVIDIA_API_KEY` (free tier: 1000 req/day on most models)
- **Signup:** build.nvidia.com
- **Best for:** Opus / Sonnet tier — frontier open-weights (Qwen3.5-397b-a17b, Kimi-K2.5, Llama-405b).
- **Free tier limit:** ~1000 req/day per model; 429 after.
- **free-cc model id prefix:** `nvidia_nim/`

### OpenRouter
- **Endpoint:** `https://openrouter.ai/api/v1`
- **Auth:** `OPENROUTER_API_KEY` (free credits + `:free` model variants)
- **Signup:** openrouter.ai
- **Best for:** Haiku tier via `:free` variants (Step-3.5-flash:free, Llama-3.3-70b:free).
- **Free tier limit:** 20 req/min per `:free` model, 200/day on free credits.
- **free-cc model id prefix:** `open_router/`

### DeepSeek
- **Endpoint:** `https://api.deepseek.com/v1`
- **Auth:** `DEEPSEEK_API_KEY` (paid, but cheap; not strictly free)
- **Signup:** platform.deepseek.com
- **Best for:** Sonnet tier reasoning. Tool-calling reliable.
- **Note:** DeepSeek is cheap (~$0.14/MTok input) but not free. Include only when user explicitly asks.
- **free-cc model id prefix:** `deepseek/`

## Selection rules used by `free-llm`

1. If `--cloud` not passed AND any local provider responds → local-only.
2. If all local probes fail AND user confirms cloud → cloud chain (NIM → OpenRouter → DeepSeek).
3. Never mix local and cloud in one tier — stay consistent within a tier so tool-call schema does not flap.

## Model-ID format reminder

`free-claude-code` uses LiteLLM-style prefixes. Always include the prefix:

- `ollama/qwen2.5-coder:7b` — correct
- `qwen2.5-coder:7b` — wrong (LiteLLM cannot resolve)
- `nvidia_nim/qwen/qwen3.5-397b-a17b` — correct (note the `nvidia_nim/` prefix and the slash inside the model name)
