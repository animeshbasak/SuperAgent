# superagent-memory-mcp

MCP server providing persistent multi-tier memory for SuperAgent across Claude Code, Cursor, Antigravity, Gemini CLI, and GitHub Copilot.

Ported in spirit from [memory-os](https://github.com/cd-drews/memory-os) (MIT, Claudio Drews). See [`docs/rfcs/0001-memory-os.md`](../../docs/rfcs/0001-memory-os.md) for the architectural decisions.

## What it does

Five tools, served over MCP stdio:

| Tool | Purpose |
|---|---|
| `memory_recall(query, limit?, namespace?)` | BM25-ranked search over stored memory in the current project namespace |
| `memory_write(content, kind, tags?)` | Append-only store with prompt-injection sanitization |
| `memory_list(namespace?, kind?, since?)` | Recent entries, ordered by timestamp |
| `memory_pin(id)` | Promote an entry to the workspace L1 layer |
| `memory_forget(id_or_pattern)` | Soft-delete by id or SQL LIKE pattern |

Namespacing is automatic: entries are isolated per git-root hash. Cross-project facts go under the reserved `__global__` namespace.

## Install

Requires Python ≥ 3.11.

```bash
# from this directory
uv pip install -e .                  # or: pip install -e .
```

Then register with your MCP-aware client. For Claude Code:

```bash
bash adapters/claude-code/install.sh
```

Or manually add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "superagent-memory": {
      "command": "superagent-memory-mcp"
    }
  }
}
```

## Lifecycle jobs

A second console script, `superagent-memory`, runs maintenance jobs (used by
hooks or cron — not the MCP transport):

```bash
superagent-memory decay --dry-run          # report stale entries, no changes
superagent-memory decay                     # archive entries older than 90d AND idle 30d
superagent-memory decay --max-age-days 180 --idle-days 60 --namespace <ns>
superagent-memory dedup --dry-run           # report near-duplicate merges (needs SUPERAGENT_MEMORY_VECTOR=on)
superagent-memory dedup                      # merge entries with cosine ≥0.92, namespace-scoped
superagent-memory cron install              # schedule weekly decay (launchd on macOS, crontab elsewhere)
superagent-memory cron status
superagent-memory cron uninstall
```

Decay is a soft-delete (`forgotten = 1`, recorded in the `audit` table) and
never touches pinned entries. Recall refreshes an entry's `last_access`, so
frequently-used memory is never archived.

**Semantic dedup** (Phase 4.2, needs vector recall enabled) merges
near-duplicate entries within a namespace: it embeds live non-pinned entries,
greedily clusters by cosine similarity ≥0.92, keeps the most-accessed/oldest
as canonical (folding the duplicates' access counts into it), and soft-deletes
the rest — audited as `dedup` and removed from the vector index. Different
namespaces are never merged.

## Storage

- `~/.superagent/memory-os/memory.db` — SQLite + FTS5
- `~/.superagent/memory-os/pinned/` — promoted entries (markdown)
- Override the root via `SUPERAGENT_MEMORY_HOME`.

Default install is zero-dep (FTS only). Vector recall (Qdrant sidecar) is opt-in.

## Vector recall (opt-in, Phase 5)

FTS5 is keyword-only: a query for `login fix` will never match a stored
`auth bug in the middleware`. Vector recall closes that gap by blending the
BM25 ranking with embedding cosine similarity via **reciprocal rank fusion**,
so semantic/synonym hits surface that pure keyword search misses.

It is fully gated — the default install imports neither `qdrant-client` nor
`httpx` and makes no network call. Turn it on:

```bash
uv pip install -e ".[vector]"
docker compose -f docker/docker-compose.yml up -d   # Qdrant on 127.0.0.1:6333
curl -s localhost:6333/healthz                       # health check
export SUPERAGENT_MEMORY_VECTOR=on
```

- **Embeddings:** local-first — Ollama (`nomic-embed-text`, 768-dim) by
  default, falling back to OpenRouter only if `OPENROUTER_API_KEY` is set and
  Ollama is unreachable. A failed embed never fails a write (best-effort
  indexing); recall transparently degrades to FTS-only if the vector backend
  is down.
- **Store backend** (`SUPERAGENT_MEMORY_VECTOR_BACKEND`): `auto` (default —
  Qdrant, else in-memory), `qdrant` (required), or `memory` (zero-dep, in-process).
- `memory_recall` reports `mode: "fts" | "hybrid"` so callers can tell which
  path served the query.

Relevant env: `SUPERAGENT_MEMORY_QDRANT_URL`, `SUPERAGENT_MEMORY_OLLAMA_URL`,
`SUPERAGENT_MEMORY_EMBED_MODEL`.

## Tests

```bash
uv pip install -e ".[dev]"
pytest
```

## License

MIT. Concepts inspired by [memory-os](https://github.com/cd-drews/memory-os) (Claudio Drews, MIT). Independent TypeScript-then-Python reimplementation; no upstream code copied.
