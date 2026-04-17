---
name: graphify
description: Use when you need to map, visualize, or query relationships in a codebase, docs, papers, images, or videos — transforms any folder into a queryable knowledge graph. Use when user says /graphify, "build knowledge graph", "map codebase relationships", "why does X connect to Y", or needs 71x token-efficient codebase exploration.
---

# Graphify

Transforms any folder (code, docs, PDFs, images, videos) into a queryable knowledge graph. 71.5x token reduction per query vs raw file reads.

## Install

```bash
pip install graphifyy && graphify install
```

## Commands

| Task | Command |
|------|---------|
| Build graph from current dir | `/graphify .` |
| Build from specific folder | `/graphify ./src` |
| Query relationships | `/graphify query "what connects X to Y?"` |
| Find path between nodes | `/graphify path "NodeA" "NodeB"` |
| Add remote content | `/graphify add https://arxiv.org/abs/...` |
| Watch mode (auto-sync) | `/graphify ./src --watch` |
| Export to Neo4j | `/graphify . --neo4j` |
| Export formats | `--wiki`, `--graphml`, `--svg` |

## Output Artifacts

- **`GRAPH_REPORT.md`** — god nodes, surprising connections, architectural highlights
- **`graph.json`** — persistent queryable graph (reuse weeks later, SHA256 cached)
- **Interactive HTML** — visual graph exploration

## How It Works

1. **AST extraction** — deterministic, no LLM, 25+ languages via tree-sitter
2. **Local transcription** — video/audio via Whisper (private, local)
3. **Parallel Claude subagents** — extract from docs, papers, images

## Relationship Tags

- `EXTRACTED` — found directly in source
- `INFERRED` — reasonable inference with confidence score
- `AMBIGUOUS` — flagged for human review

## When to Use vs claude-mem:smart-explore

| Need | Tool |
|------|------|
| Structural AST-level code map | `claude-mem:smart-explore` |
| Cross-modal graph (code + docs + papers + video) | `graphify` |
| Persistent queryable graph across sessions | `graphify` |
| Quick one-off symbol search | `Grep` directly |

## Privacy

- Code: local AST only, never sent to API
- Audio/video: local Whisper transcription
- Docs/images/papers: sent to your platform's API with your key
