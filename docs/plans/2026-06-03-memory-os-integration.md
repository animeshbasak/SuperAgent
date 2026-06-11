# Implementation Plan: Memory-OS Integration for SuperAgent

**Date:** 2026-06-03
**Status:** Draft — awaiting human review
**Source analysis:** `references/memory-os/` (Claudio Drews, Hermes plugin, MIT)
**Goal:** Port memory-os's seven-layer memory architecture into SuperAgent so it works uniformly across **Claude Code, Cursor, Antigravity, GitHub Copilot, Gemini CLI**.

---

## Overview

Memory-OS is a Hermes-Agent plugin that gives an LLM agent a persistent, multi-tier memory store with surgical context injection and a Ground Truth Hierarchy that forces the agent to actually use injected memory instead of rediscovering knowledge. SuperAgent already has primitives for some of this (`~/.superagent/agent-memory/<skill>/`, mempalace global index, per-platform adapters) but is missing four killer features:

1. **Semantic recall** (currently keyword/markdown only — no vector search)
2. **Ground Truth Hierarchy** (no enforcement that injected memory is authoritative)
3. **Lifecycle automation** (no decay, dedup, or auto-injection hooks)
4. **Cross-platform parity** (memory works in Claude Code, partial elsewhere)

This plan ports the **concepts**, not the Python code. The integration runs as an **MCP server** (universal across 4/5 platforms) with per-platform adapter shims and a shared CLAUDE.md-style rules file.

---

## Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Universal interface | **MCP server** (`superagent-memory`) | Supported natively by Claude Code, Cursor, Antigravity, Gemini CLI. Copilot needs an SDK shim. 80% code reuse. |
| Storage backend | **claude-mem (existing) + Qdrant (optional sidecar)** | claude-mem already installed and providing keyword + cross-session storage. Qdrant added only when user opts into semantic recall. Zero new dependencies for default install. |
| Embedding source | **Ollama (default) → OpenRouter (fallback)** | Aligns with SuperAgent's "local first" ethos. No mandatory cloud calls. |
| Ground Truth Layer 7 | **Per-platform rules-file patch** | Inject a `## Ground Truth Hierarchy` block into CLAUDE.md / .cursorrules / copilot-instructions.md / GEMINI.md / Antigravity skill manifest. |
| Lifecycle automation | **Claude Code hooks (first-class) + cron fallback (other platforms)** | Hook-driven decay/dedup on Claude Code; weekly cron on platforms without hooks. |
| Memory namespacing | **Project-scoped by git-root hash + global** | Keeps cross-project memory pollution out (lessons from `mempalace`). |
| Migration path | **Additive — existing agent-memory/ keeps working** | No breaking changes. New features opt-in via `SUPERAGENT_MEMORY=on`. |

---

## The Seven Layers — Mapping to SuperAgent

| memory-os Layer | SuperAgent Equivalent (existing or new) |
|---|---|
| L1 Workspace (MEMORY.md, USER.md) | **Existing** — `~/.claude/CLAUDE.md` + `~/.superagent/agent-memory/<skill>/MEMORY.md` |
| L2 Sessions (SQLite FTS5) | **Existing** — `claude-mem` cross-session DB |
| L3 Structured Facts | **NEW** — `~/.superagent/memory-os/facts.db` (SQLite) |
| L4 Fabric (ranked retrieval) | **Existing** — `mempalace` markdown index |
| L5 Vector DB (Qdrant) | **NEW** — opt-in Qdrant sidecar via Docker |
| L6 LLM Wiki | **NEW** — `~/.superagent/memory-os/wiki/` (auto-ingested) |
| L7 Ground Truth Hierarchy | **NEW** — rules-file patch per platform |

L1, L2, L4 already work. Plan focuses on **adding L3, L5, L6, L7** without breaking existing layers.

---

## Task List

### Phase 0 — Spec Lock-in & Foundation

- [x] **Task 0.1: Author RFC** (`docs/rfcs/0001-memory-os.md`)
  - **Acceptance:** RFC explains 7 layers, MCP-first architecture, per-platform adapter responsibilities, opt-in via `SUPERAGENT_MEMORY=on`
  - **Verification:** Self-review against memory-os README + this plan
  - **Files:** `docs/rfcs/0001-memory-os.md`
  - **Size:** S

- [x] **Task 0.2: Sanity-check claude-mem coverage**
  - **Acceptance:** Document what claude-mem already does (FTS, sessions) vs what's missing (vectors, facts, decay)
  - **Verification:** Run `claude-mem --help`; list every command; map to memory-os layer
  - **Files:** `docs/agent-memory.md` (append section)
  - **Size:** XS

**Checkpoint 0:** RFC approved by human. Existing primitives mapped.

---

### Phase 1 — MCP Server Core (the 80% reuse)

- [x] **Task 1.1: Scaffold `bin/superagent-memory` MCP server**
  - Use the official MCP TypeScript or Python SDK (TS preferred — matches superagent's adapter style)
  - **Acceptance:** Server starts via `npx @superagent/memory-mcp`; advertises tools; responds to `initialize` handshake
  - **Verification:** `npx @modelcontextprotocol/inspector` connects successfully
  - **Files:** `bin/superagent-memory-mcp/{package.json,src/server.ts}`
  - **Size:** M

- [x] **Task 1.2: Implement 5 core tools**
  - `memory_recall(query, limit?, namespace?)` — returns ranked hits across L1/L2/L4
  - `memory_write(content, kind, tags?)` — appends to current namespace
  - `memory_list(namespace?, kind?, since?)` — paginated list
  - `memory_pin(id)` — promote an entry to L1 workspace
  - `memory_forget(id_or_pattern)` — soft-delete with audit
  - **Acceptance:** Each tool documented in schema; each callable via MCP inspector; each returns deterministic JSON
  - **Verification:** Unit tests per tool (`vitest`); integration test against claude-mem fixture DB
  - **Files:** `bin/superagent-memory-mcp/src/tools/*.ts` + `test/tools/*.test.ts`
  - **Size:** M

- [x] **Task 1.3: Sanitization layer (port `_test_sanitize.py` concepts)**
  - Strip prompt-injection patterns from any text written via `memory_write`
  - **Acceptance:** All 24 memory-os sanitization test cases pass on the TypeScript port
  - **Verification:** `npm test -- sanitize.test.ts` green
  - **Files:** `bin/superagent-memory-mcp/src/sanitize.ts` + `test/sanitize.test.ts`
  - **Size:** S

- [x] **Task 1.4: Namespacing by git-root hash**
  - **Acceptance:** Two different projects can call `memory_write` with the same query and get isolated stores
  - **Verification:** Integration test with two temp git repos
  - **Files:** `bin/superagent-memory-mcp/src/namespace.ts`
  - **Size:** S

**Checkpoint 1:** MCP server runs; 5 tools work; sanitization green; isolated namespaces verified. **This alone is shippable as v0.1.**

---

### Phase 2 — Per-Platform Adapters (parallelizable across 5 agents)

> Each adapter task is independent. Dispatch in parallel after Checkpoint 1.

- [x] **Task 2.1: Claude Code adapter**
  - Update `adapters/claude-code/install.sh` to register MCP server in `~/.claude.json`
  - Add SessionStart hook that calls `memory_recall` for the current cwd
  - Add Stop hook that distills the session into one `memory_write` call
  - **Acceptance:** Fresh Claude Code session auto-loads workspace memory; session end persists learnings
  - **Verification:** Run install.sh on test box; start `claude`; confirm `<system-reminder>` shows memory wake-up
  - **Files:** `adapters/claude-code/{install.sh,hooks/session-start.sh,hooks/stop.sh}`
  - **Size:** M

- [x] **Task 2.2: Cursor adapter**
  - Update `adapters/cursor/install.sh` to register MCP server in `cursor_settings.json`
  - Generate `.cursor/rules/memory-os.mdc` rules file with Ground Truth Hierarchy block + recall-on-start prompt
  - **Acceptance:** Cursor chat can call `memory_recall` and `memory_write` tools; rules file injected every conversation
  - **Verification:** Manual smoke test in Cursor 0.45+ on a sandbox project
  - **Files:** `adapters/cursor/{install.sh,templates/memory-os.mdc}`
  - **Size:** M

- [x] **Task 2.3: Gemini CLI adapter**
  - Update `adapters/gemini/install.sh` to register MCP server via `fastmcp install`
  - Inject Ground Truth block into Gemini's project context file
  - Add a wrapper script that prefixes every `gemini` invocation with a `memory_recall` resource query
  - **Acceptance:** `gemini "what did we decide about X?"` returns memory hits
  - **Verification:** Smoke test against Gemini CLI 2.0+
  - **Files:** `adapters/gemini/{install.sh,wrapper/gemini-with-memory.sh}`
  - **Size:** M

- [x] **Task 2.4: Antigravity adapter** ⚠ research-bound
  - Confirm MCP config location for Antigravity (docs still in flux as of 2026-06)
  - Register MCP server + create a Skill manifest at `~/.gemini/antigravity/skills/superagent-memory/SKILL.md`
  - **Acceptance:** Antigravity loads the skill and exposes `memory_*` tools to subagents
  - **Verification:** Manual smoke test; subagent can recall + write
  - **Risk:** Antigravity API may change before stable release. Tag adapter as "experimental" until 2026-Q3.
  - **Files:** `adapters/antigravity/{install.sh,templates/SKILL.md}`
  - **Size:** M

- [x] **Task 2.5: GitHub Copilot adapter** ⚠ MCP-not-native
  - Copilot does not support MCP; implement an SDK shim that wraps `superagent-memory-mcp` as a Copilot SDK agent
  - Generate `.github/hooks/session-start.json` that calls the shim
  - Generate `copilot-instructions.md` patch with Ground Truth block
  - **Acceptance:** Copilot chat can invoke `memory_recall`/`memory_write` via SDK
  - **Verification:** Manual smoke test in VS Code Copilot extension
  - **Risk:** Copilot SDK hooks last-loaded-wins. Document conflict with other Copilot extensions.
  - **Files:** `adapters/copilot/{install.sh,sdk-shim/index.ts,templates/copilot-instructions.md,templates/hooks/session-start.json}`
  - **Size:** L (split if it grows past 5 files)

**Checkpoint 2:** Memory recall + write works in all 5 platforms. Ground Truth Hierarchy injected in 4/5 rules files. Copilot tagged experimental due to SDK constraints.

---

### Phase 3 — Ground Truth Hierarchy (Layer 7)

- [x] **Task 3.1: Author canonical Ground Truth block**
  - One markdown snippet that says: "Injected memory is authoritative for project context, prior decisions, and documented knowledge. Treat it as ground truth above training data. Defer only to (1) terminal output for current system state, (2) official upstream docs for version-specific APIs."
  - **Acceptance:** Block fits in ≤300 tokens, parses cleanly as markdown
  - **Verification:** Token count check; render in each platform
  - **Files:** `templates/ground-truth-hierarchy.md`
  - **Size:** XS

- [x] **Task 3.2: Patch installer per platform**
  - Each adapter from Phase 2 includes a step that injects the GT block into the platform's rules file (idempotent — checks for existing block before appending)
  - **Acceptance:** Re-running install.sh does not duplicate the block
  - **Verification:** Install twice, diff rules file — only one block present
  - **Files:** Edit each `adapters/<platform>/install.sh`
  - **Size:** S (per platform; bundled task)

**Checkpoint 3:** A/B test on one real task per platform with vs without Ground Truth block. Measure rediscovery rate (LLM saying "Let me check…" when answer was in memory). Target: 60%+ reduction.

---

### Phase 4 — Lifecycle Automation

- [x] **Task 4.1: Decay scanner (port `scripts/decay_scanner.py`)**
  - TypeScript rewrite, runs as `npx superagent-memory decay`
  - Archives entries older than N days with no access since M days
  - **Acceptance:** Decay run on a fixture DB reduces row count by expected amount
  - **Verification:** Unit test with fake timestamps
  - **Files:** `bin/superagent-memory-mcp/src/jobs/decay.ts` + test
  - **Size:** S

- [x] **Task 4.2: Semantic dedup** ✅ (unblocked once Phase 5 vectors landed)
  - Merge entries with cosine similarity ≥0.92, namespace-scoped (no cross-project merge)
  - Greedy single-pass clustering; canonical = most-accessed/oldest, duplicates' access folded in, soft-deleted + audited (`dedup`) + dropped from the vector index
  - **Acceptance:** Dedup pass on fixture reduces near-duplicate count ✅ (`test_three_way_cluster_merges_two`)
  - **Verification:** `test_dedup.py` (11 tests — exact/near dup, dry-run, pinned-skip, namespace isolation, access folding, unembeddable skip)
  - **CLI:** `superagent-memory dedup [--dry-run] [--threshold T] [--namespace NS]` (gated on `SUPERAGENT_MEMORY_VECTOR=on`)
  - **Files:** `memory_os/jobs/dedup.py`, wired into `memory_os/cli.py`

- [x] **Task 4.3: Cron installer for non-hook platforms**
  - `superagent-memory cron install` adds weekly decay + monthly dedup to user's crontab (or launchd on macOS)
  - **Acceptance:** Cron entries created; runnable manually for testing
  - **Verification:** Inspect crontab; trigger manually; confirm log output
  - **Files:** `bin/superagent-memory-mcp/src/cron-install.ts`
  - **Size:** S

**Checkpoint 4:** Decay + dedup runs cleanly on schedule across all 5 platforms.

---

### Phase 5 — Vector Recall (Opt-in Qdrant Sidecar)

> Gate behind `SUPERAGENT_MEMORY_VECTOR=on`. Default install stays zero-dep.

> **Note:** the server was built in Python (`memory_os/`), not TypeScript, so
> the file paths below were adapted. Embeddings run **in-process** in the
> Python server (Ollama → OpenRouter), so no separate Node ingestion worker is
> needed — the Qdrant sidecar alone covers Task 5.1.

- [x] **Task 5.1: Docker Compose for Qdrant** ✅
  - Single `docker-compose.yml` with Qdrant (no Node worker — embeddings are in-process)
  - Use Ollama (local) for embeddings; OpenRouter as fallback
  - **Acceptance:** `docker compose up -d` brings up healthy Qdrant on `127.0.0.1:6333` ✅
  - **Verification:** healthcheck via `/dev/tcp` probe; `curl localhost:6333/healthz`
  - **Files:** `bin/superagent-memory-mcp/docker/docker-compose.yml`

- [x] **Task 5.2: Embedding pipeline** ✅
  - On every `memory_write`, embed + upsert into the vector store (gated, best-effort)
  - Local-first provider chain Ollama → OpenRouter; failures never break a write (`indexed` flag)
  - **Verification:** `test_vector.py::test_write_indexes_when_enabled`, `test_embed_*` (provider chain), `test_hybrid_falls_back_to_fts_when_embed_fails`
  - **Files:** `memory_os/vector/{embed.py,service.py,store.py}`, wired into `tools.memory_write`

- [x] **Task 5.3: Hybrid recall in `memory_recall`** ✅
  - When `SUPERAGENT_MEMORY_VECTOR=on`, blend FTS results with vector cosine results (reciprocal rank fusion)
  - `memory_recall` returns `mode: "fts" | "hybrid"`; degrades to FTS if vector backend is down
  - **Acceptance:** Synonym queries return relevant hits that pure FTS misses ✅
  - **Verification:** `test_vector.py::test_hybrid_recall_finds_synonym_miss` ("auth bug" vs "login fix")
  - **Files:** `memory_os/vector/recall.py` (RRF), `db.get_entries_by_ids`, wired into `tools.memory_recall`

**Checkpoint 5:** ✅ Hybrid recall surfaces a stored `auth bug` doc for a `login fix` query that FTS-only returns nothing for (`test_hybrid_recall_finds_synonym_miss` asserts the FTS miss then the hybrid hit). 89 tests pass (was 66). The win is documented in `bin/superagent-memory-mcp/README.md` → "Vector recall".

---

### Phase 6 — Polish & Ship

- [ ] **Task 6.1: Telemetry (opt-in)** — local-only counters for recall calls, write calls, dedup hits. Surface via `superagent-memory stats`.
- [ ] **Task 6.2: Bench harness** — extend existing `bench/` with memory-tagged tasks; measure rediscovery-rate delta vs baseline.
- [ ] **Task 6.3: Docs** — update `README.md`, `docs/agent-memory.md`, write per-platform quickstarts.
- [ ] **Task 6.4: Version bump + release** — semver bump, CHANGELOG entry, GitHub release.

**Checkpoint 6 (Ship Gate):** All adapters pass smoke tests. Bench shows measurable win. Docs complete. Ground Truth block live in 5 platforms.

---

## Parallelization Map

| Phase | Parallelizable? | Notes |
|---|---|---|
| 0 | No | Spec must lock first |
| 1 | Sequential within phase | Each task depends on the previous |
| 2 | **YES — 5 adapters in parallel** | Dispatch via `dispatching-parallel-agents` skill |
| 3 | Sequential (patches the Phase 2 installers) | Small enough to fold into Phase 2 if preferred |
| 4 | YES — decay + dedup + cron independent | But 4.2 depends on Phase 5 |
| 5 | Sequential within phase | Worker before embed pipeline before hybrid recall |
| 6 | YES — telemetry / bench / docs independent | Final integration is sequential |

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Antigravity API churn before stable release | Medium | Tag adapter as experimental; pin to a specific Antigravity build; revisit Q3 |
| Copilot SDK lacks MCP — divergent code path | Medium | Treat Copilot as experimental v0.1; document SDK shim limits; revisit when Copilot adds MCP |
| Qdrant Docker overhead scares off users | Low | Vector recall is opt-in; default install needs zero extra processes |
| `memory_write` becomes write-amplification firehose | High | Sanitization layer + per-namespace rate limit + dedup cron |
| Ground Truth block conflicts with user's existing CLAUDE.md instructions | Medium | Inject under a clearly-marked HTML comment block; document removal command |
| Embedding cost on cloud fallback (OpenRouter) | Low | Local Ollama default; cloud path requires explicit env var |
| Cross-project memory leak | High | Namespace by git-root hash; integration test isolation explicitly |

---

## Open Questions (need human input)

1. **Storage layout** — keep memory-os data under `~/.superagent/memory-os/` (new dir) or extend existing `~/.superagent/agent-memory/`? Trade-off: new dir = clean migration; extending = no duplicate paths.
2. **Vector default** — should `SUPERAGENT_MEMORY_VECTOR=on` ship as the default once stable, or stay opt-in forever? Affects install-size and onboarding.
3. **Copilot scope** — is Copilot worth the SDK divergence today, or defer until MCP support lands? (Saves a full L-sized task.)
4. **License kept as MIT?** — memory-os is MIT (Drews). SuperAgent adapter re-implements concepts in TypeScript; should attribute Drews in NOTICE file.
5. **Mempalace coexistence** — does memory-os MCP *replace* mempalace, *wrap* it, or *run alongside*? Current plan: alongside, with mempalace owning the global index and memory-os owning per-project memory.

---

## Suggested Order of Operations

1. **Answer the 5 open questions above** (15 min with human).
2. **Phase 0 + Phase 1** (Foundation + MCP server) — 1 focused builder session.
3. **Phase 2** (5 adapters in parallel) — dispatching-parallel-agents on Claude Code; 1 builder session per slow adapter (Copilot, Antigravity).
4. **Phase 3** (Ground Truth) — folded into Phase 2 installer patches; one PR.
5. **Phase 4** (decay/dedup/cron) — single session.
6. **Phase 5** (Vector recall) — separate feature branch; merge when stable.
7. **Phase 6** (Polish + ship) — release as `superagent v2.7-memory-os`.

**Minimum viable ship:** Phases 0 + 1 + 2 (Claude Code adapter only) + Phase 3. That gets Ground Truth + recall/write live on the user's primary daily driver in ~2 builder sessions.

---

## Verification (pre-ship gate)

- [ ] MCP server passes `npx @modelcontextprotocol/inspector` validation
- [ ] All 24 sanitization tests green
- [ ] Each of the 5 adapter install scripts runnable on a fresh box
- [ ] Ground Truth block present and idempotent in all 5 rules files
- [ ] Decay + dedup cron entries verifiable on macOS + Linux
- [ ] Bench shows ≥30% reduction in rediscovery on memory-tagged tasks
- [ ] Docs updated; CHANGELOG entry; semver bump

---

*Plan author: SuperAgent (Claude Code session 2026-06-03). Source: thorough analysis of `references/memory-os/`. Awaiting human review on the 5 open questions before Phase 0 kicks off.*
