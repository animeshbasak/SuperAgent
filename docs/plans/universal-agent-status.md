# SuperAgent Universal — Implementation Status

> **Purpose**: Track progress on multi-platform support. Designed to be picked up by any AI agent if token limits are reached or work continues in a new session.
>
> **Plan**: See `docs/plans/universal-agent-plan.md` for the full architecture and rationale.
>
> **Constraint**: ZERO impact on existing Claude Code implementation. All changes are additive.

---

## Quick Context for New Agents

SuperAgent is a Claude Code orchestrator with 15 skills, a routing brain, and CLI tools. We're adding support for 7 more platforms (Codex, Gemini/Antigravity, Cursor, Windsurf, Copilot, Continue.dev, Aider) via an **adapter pattern**:

1. A **compiler** (`bin/superagent-compile`) reads all skills and produces platform-specific instruction files
2. **Adapters** (`adapters/<platform>/`) contain templates and install scripts for each platform
3. A **universal installer** (`install-universal.sh`) auto-detects platforms and runs the right adapters
4. **No existing files are modified** — everything is additive

### Key Files to Read First
- `docs/plans/universal-agent-plan.md` — full architecture
- `skills/superagent/brain/rules.yaml` — routing rules (14 rules, platform-agnostic)
- `skills/superagent/SKILL.md` — main router skill
- `bin/superagent-classify` — classifier (bash+Python, already portable)
- `install.sh` — current Claude-only installer (DO NOT MODIFY)
- `ETHOS.md` — guiding principles all skills reference

### Skill Inventory (15 skills)
| Skill | Directory | Description |
|-------|-----------|-------------|
| superagent | `skills/superagent/` | Master router (SKILL.md + brain/rules.yaml + chains/) |
| webgl-craft | `skills/webgl-craft/` | Premium WebGL/3D (SKILL.md + references/ + recipes/) |
| plan-ceo-review | `skills/plan-ceo-review/` | CEO-lens plan pressure test |
| plan-eng-review | `skills/plan-eng-review/` | Eng-manager plan review |
| plan-design-review | `skills/plan-design-review/` | Designer 10-dimension rating |
| autoplan | `skills/autoplan/` | Auto-pipeline through all reviews |
| review | `skills/review/` | 6-point pre-merge diff gate |
| investigate | `skills/investigate/` | Iron Law root-cause analysis |
| ship | `skills/ship/` | 20-step ship pipeline |
| office-hours | `skills/office-hours/` | YC-style product intake |
| cso | `skills/cso/` | OWASP/STRIDE security audit |
| learn | `skills/learn/` | Per-project learnings JSONL |
| bench | `skills/bench/` | Classifier benchmark runner |
| fanout | `skills/fanout/` | Parallel skill execution |
| token-stats | `skills/token-stats/` | Token savings tracker |

### Tools Inventory (5 CLIs)
| Tool | Location | Description |
|------|----------|-------------|
| superagent-classify | `bin/superagent-classify` | Task → {chain, hint} JSON |
| superagent-chain | `bin/superagent-chain` | Run YAML skill chain |
| superagent-cost | `bin/superagent-cost` | Token cost by model |
| superagent-learn | `bin/superagent-learn` | Learnings manager |
| superagent-ship | `bin/superagent-ship` | Ship orchestrator |

### Hook Scripts (4 hooks)
| Hook | Location | Description |
|------|----------|-------------|
| superagent-tracker.sh | `hooks/superagent-tracker.sh` | PostToolUse token counter |
| superagent-statusline.sh | `hooks/superagent-statusline.sh` | Statusline badge |
| superagent-distill.sh | `hooks/superagent-distill.sh` | Stop hook auto-distill |
| superagent-state-init.sh | `hooks/superagent-state-init.sh` | State root initializer |

---

## Phase Status

### Phase 1: Compiler + Codex Adapter
- [x] Create `bin/superagent-compile` — skill-to-platform compiler
- [x] Implement `--platform codex` — full AGENTS.md compilation
- [x] Implement `--platform cursor` — compact .mdc compilation
- [x] Implement `--platform gemini` — modular SKILL.md compilation
- [x] Implement `--platform copilot` — single-file compilation
- [x] Implement `--platform windsurf` — AGENTS.md + rules/ compilation
- [x] Implement `--platform continue` — numbered rule files compilation
- [x] Implement `--platform aider` — CONVENTIONS.md compilation
- [x] Create `adapters/codex/templates/AGENTS.md` — compiled output
- [x] Create `adapters/codex/install.sh` — Codex-specific installer

### Phase 2: Gemini/Antigravity Adapter
- [x] Create `adapters/gemini/templates/GEMINI.md` — global instructions
- [x] Create `adapters/gemini/templates/skills/` — per-skill SKILL.md files
- [x] Create `adapters/gemini/install.sh`

### Phase 3: Cursor Adapter
- [x] Create `adapters/cursor/templates/superagent-core.mdc` — always-apply (<200 words)
- [x] Create `adapters/cursor/templates/superagent-*.mdc` — glob-based skills
- [x] Create `adapters/cursor/install.sh`
- [x] Verify total chars < 12,000

### Phase 4: Remaining Adapters
- [x] Windsurf adapter (`adapters/windsurf/`)
- [x] Copilot adapter (`adapters/copilot/`)
- [x] Continue.dev adapter (`adapters/continue/`)
- [x] Aider adapter (`adapters/aider/`)

### Phase 5: Universal Installer
- [x] Create `install-universal.sh` — platform detection + selection
- [x] Detect Claude Code, Codex, Cursor, Gemini, Windsurf, Copilot, Continue, Aider
- [x] Run per-platform install scripts
- [x] Install Python tools (graphify + mempalace) — shared across platforms

### Phase 6: Documentation
- [x] Update README.md with multi-platform section + roadmap
- [ ] Create `docs/platforms/codex.md`
- [ ] Create `docs/platforms/gemini.md`
- [ ] Create `docs/platforms/cursor.md`
- [ ] Create `docs/platforms/windsurf.md`
- [ ] Create `docs/platforms/copilot.md`
- [ ] Create `docs/platforms/continue.md`
- [ ] Create `docs/platforms/aider.md`

---

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-25 | Additive-only (no file moves) | Protects existing Claude Code users, avoids breaking install.sh |
| 2026-04-25 | Separate `install-universal.sh` | Original `install.sh` remains the Claude-only installer |
| 2026-04-25 | Compiler approach | One source of truth (skills/), compiled to each platform format |
| 2026-04-25 | Prompt-based routing for Cursor/Copilot | These platforms can't execute arbitrary tools |

---

## Verification Results (2026-04-25)

| Check | Result |
|-------|--------|
| `test/test-classify.sh` | ✅ 18/18 PASS — zero regressions |
| `git status` — no modified files | ✅ Only new files (adapters/, bin/superagent-compile, docs/plans/, install-universal.sh) |
| Original `install.sh` MD5 unchanged | ✅ `bbb1ebc22cecf60106e33a25b001f130` |
| Original `CLAUDE.md` unchanged | ✅ `14485d2a80d452445c1f68e0b188254c` |
| `superagent-compile --platform all` | ✅ 66 adapter files generated across 7 platforms |
| Cursor total chars | ✅ 4,724 chars (under 12,000 limit) |
| `install-universal.sh --list` | ✅ Detected 6/8 platforms (claude, codex, gemini, copilot, continue, aider) |

---

## How to Resume Work

If you're picking this up in a new session:

1. Read `docs/plans/universal-agent-plan.md` for the full architecture
2. Check the Phase Status above for what's done vs pending
3. Start from the first unchecked item (Phase 6: Documentation)
4. After completing items, update this file's checkboxes
5. Run `test/test-classify.sh` to verify no regressions
6. Run `python3 bin/superagent-compile --platform all` to regenerate adapter templates
7. Run `bash install-universal.sh --list` to verify platform detection
8. **Never modify existing files** — `install.sh`, `CLAUDE.md`, `skills/`, `agents/`, `hooks/`, `bin/superagent-classify`, etc.
