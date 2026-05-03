# Plan: Integrate 4 Reference Repos into SuperAgent

**Date:** 2026-05-04
**Sources:** `references/{ruflo, codeburn, system_prompts_leaks, claude-code-best-practice}`
**Method:** 4 parallel Explore agents → cross-cut analysis → ranked port list

---

## Cross-cutting signal

| Theme | ruflo | codeburn | cc-best-practice | sys-prompts | Superagent today |
|---|---|---|---|---|---|
| Hooks infra | ✅ 17 hooks | — | ✅ 27 events | ✅ reversibility-gating | ❌ none |
| Cost-aware routing | ✅ 3-tier (Booster→Haiku→Sonnet) | ✅ pricing engine | — | — | ⚠️ `auto-fallback` skill only |
| Task classifier | — | ✅ 13-cat deterministic | — | — | ⚠️ `superagent-classify` (rules-based) |
| Agent memory | ✅ ReasoningBank/SONA | — | ✅ `agent-memory/<name>/` | ✅ 4-pillar typed | ⚠️ mempalace, no per-skill |
| MCP grouping | ✅ ADR-035 | — | ✅ `.mcp.json` | — | ❌ no `.mcp.json` |
| Reversibility gate | — | — | — | ✅ Claude-Code-style | ⚠️ implicit |
| Provider/IDE adapter | — | ✅ 18 session parsers | — | — | ⚠️ 7 IDE adapters, no telemetry |

**Strongest converging signal: HOOKS.** 3 of 4 sources independently advocate hooks/gating. Superagent has none. Highest leverage.

**Second signal: per-agent typed memory.** 2 of 4 sources. Superagent has mempalace globally but not scoped per-skill.

---

## Ranked port list (top 10)

### P0 — Ship this week

1. **27-hook infrastructure** ← `claude-code-best-practice/.claude/hooks/`
   - Port `hooks.json` schema + `hooks.py` Python framework
   - Wire into `adapters/claude/install.sh`
   - Events to enable first: `PreToolUse` (safety gate), `PostToolUse` (route logging), `SessionStart` (mempalace wake), `Stop` (route flush)
   - Files to create: `superagent/.claude/hooks/{hooks.json,scripts/hooks.py}`
   - Ref: claude-code-best-practice agent report

2. **Reversibility-aware action gate** ← `system_prompts_leaks/Anthropic/claude-code.md`
   - Implement as a `PreToolUse` hook that classifies Bash/Edit/Write actions
   - Risky list: `rm -rf`, `git push --force`, `reset --hard`, `drop`, `delete`, `migrate down`
   - Block + ask unless pre-authorized in CLAUDE.md or user-confirmed
   - Plugs into hook system from #1

3. **`.mcp.json` baseline** ← `claude-code-best-practice/.mcp.json`
   - Pin `playwright`, `context7`, `deepwiki` as default MCP set
   - Document opt-in MCP groups (mirrors ruflo ADR-035 grouping idea)

### P1 — Next sprint

4. **3-tier cost-aware router formalized** ← `ruflo/v3/@claude-flow/integration/src/multi-model-router.ts`
   - Tier 1: WASM/local <1ms ($0) — for trivial classify/format
   - Tier 2: Haiku 4.5 ~500ms ($0.0002) — for simple tasks
   - Tier 3: Sonnet 4.6 / Opus 4.7 ($0.003-0.015) — for complex
   - Wire into `superagent-switch` and `auto-fallback` skill
   - Add a "tier" field to `superagent-classify` output

5. **Per-skill agent memory** ← `claude-code-best-practice/.claude/agent-memory/`
   - Convention: `~/.superagent/agent-memory/<skill-name>/MEMORY.md`
   - Skills append learnings; mempalace indexes them
   - Templates in `skills/*/MEMORY.md.template`

6. **Codeburn-style task classifier upgrade** ← `codeburn/src/classifier.ts`
   - 13 categories: coding, debugging, feature, refactor, test, plan, doc, config, security, infra, ui, data, meta
   - Replace single-label classify with multi-label scoring
   - Keep current rules.yaml as fallback

### P2 — Future

7. **One-shot rate metric** ← `codeburn/src/classifier.ts:120-143`
   - Detect Edit→Bash→Edit retry cycles in routes.jsonl
   - Surface in `token-stats` skill

8. **Agent frontmatter hooks** ← `claude-code-best-practice/.claude/agents/weather-agent.md`
   - Per-agent scoped hooks without cluttering global config
   - Useful as agents/skills grow

9. **MCP tool grouping ENV pattern** ← `ruflo/v3/mcp/server.ts` ADR-035
   - `MCP_GROUP_*` env vars to enable/disable tool groups
   - Prevents context flooding as MCP roster grows

10. **Codeburn provider adapter pattern** ← `codeburn/src/providers/`
    - Pluggable session parsers for telemetry across IDEs
    - Feeds into `token-stats` and one-shot metric

---

## Anti-patterns to NOT port

- **Ruflo's full federation/swarm stack** — too heavy, MIT-but-WASM-binary deps fragile in sandboxed IDEs
- **Codex dual-mode** (ruflo) — Codex API deprecated by OpenAI 2025
- **AgentDB Mongo backend** (ruflo) — no in-memory fallback
- **Hedging personalization** ("Based on your profile…") — system_prompts_leaks anti-pattern

---

## Suggested execution order

```
Week 1 (P0):
  Day 1-2: hooks/ scaffolding + PreToolUse + PostToolUse wiring
  Day 3:   reversibility classifier + risky-op list
  Day 4:   .mcp.json + adapter install hooks
  Day 5:   bench update + smoke across 6 platforms

Week 2 (P1):
  Day 1-2: tier classifier output + auto-fallback wiring
  Day 3-4: per-skill agent-memory convention
  Day 5:   13-category classifier

Week 3+ (P2):
  As-needed
```

## Open decisions for user

1. Hooks language: Python (matches cc-best-practice) or shell? Python wins for portability across adapters.
2. P0 scope: ship all 3 P0 items together, or hooks-only first?
3. Per-skill memory: store in `~/.superagent/` (current convention) or `~/.claude/agent-memory/` (claude-only)?
