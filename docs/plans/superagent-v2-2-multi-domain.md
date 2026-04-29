# SuperAgent v2.2 — Multi-Domain Expansion + Cost-Aware Routing

> **Status:** APPROVED — locked 2026-04-29 17:04 IST
> **Decisions locked:** C.1=α (full A+B+C+D) · B.1=b (vendor git-clone) · D.1=a (v2.1 hero + new subhead) · D.2=local-only default · B.2=cross-platform · Tier 3 = recommendations
> **Date:** 2026-04-29
> **Source plan:** [docs/plans/2026-04-29-multi-domain-superagent.md](2026-04-29-multi-domain-superagent.md)
> **Review:** 4 parallel engineer-specialists (skills, install, routing, marketing) — sequential autoplan deviation logged.

---

## Product Thesis

SuperAgent v2.1 shipped a token-aware routing brain across 8 AI coding platforms. v2.2 expands the value prop in two dimensions: **(1) cost resilience** — when Anthropic limits hit, auto-fail-over to free/local LLMs with full memory continuity; **(2) multi-domain** — same router, same savings, but now also for video generation (hyperframes). The unifying narrative emerging from the marketing review is *"the cost layer for AI development"* — SuperAgent sits underneath every IDE, every model, and every domain, optimizing tokens, dollars, and quality.

The CEO-lens scope mode is **Selective Expansion**: keep the v2.1 token-savings wedge as the spine, add resilience (free-LLM fallback) as the killer reliability story, and add video-craft as a halo product that proves the thesis generalizes beyond code. The risk the engineer reviews surfaced is **scope creep at the architecture layer** (Phase C is genuinely the load-bearing weak link) and **brand fragmentation at the marketing layer** (3 stacked pitches = no pitch). Both are addressable, but neither is auto-decidable — they require user direction.

## Design Brief

The marketing review (Engineer D) recommends a major rewrite reframing all three pitches under one unifying line: **"The cost layer for AI development."** Hero stays as the v2.1 token-savings opener ("Stop paying for tokens your AI burned re-reading your codebase") with a new subhead — *"Across 8 AI tools, 4 domains, and any LLM — paid or free."* Free-LLM fallback gets repositioned as *resilience* ("Your AI never runs out") not as *cheapness*. Video-craft is treated as a halo product BELOW THE FOLD — it proves the thesis generalizes, but does not lead. A new competitive positioning table makes the wedge explicit: Cursor/Cline/Aider/Continue are clients; Copilot is a model; SuperAgent is the router beneath all of them.

New conversion hooks: extend the existing `/token-stats --badge` viral primitive with **`/render-stats --badge`** for video-craft (renders auto-stamped with `Rendered by SuperAgent · 4.2 min · $0.83`) and a **"0 rate-limits hit"** flex line for free-LLM (reframes "I'm on free tier" as reliability brag, not bargain-bin admission). New FAQ section is mandatory — 5 specific objections must be addressed (data leakage to free providers, context preservation across switches, local LLM quality, multi-platform support, mid-task crash handling). The CLI UX (`superagent-switch list/to/back/status`) needs a clean menu pattern; user pick + canary preflight + confirmation are the three explicit checkpoints.

## Eng Spec

### Architecture diagram

```
                                ┌──────────────────────────────────┐
                                │  superagent-classify             │
                                │   ├─ rules.yaml (+ meta.complexity)
                                │   └─ emits {chain, hint, meta:{complexity}}
                                └──────────────────────────────────┘
                                              │
                ┌─────────────────────────────┼─────────────────────────────┐
                ▼                             ▼                             ▼
     ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
     │  /superagent    │         │  auto-fallback  │         │  limit-watch    │
     │  (router)       │         │  (skill)        │         │  (hook)         │
     └─────────────────┘         └─────────────────┘         └─────────────────┘
                                          │                             │
                                          ▼                             ▼
                                ┌─────────────────────────────────────────┐
                                │  superagent-switch CLI                  │
                                │  ├─ list (read local-models.json)       │
                                │  ├─ to <model> [--hot]                  │
                                │  ├─ back                                │
                                │  ├─ canary <model> --depth=3            │
                                │  └─ status                              │
                                └─────────────────────────────────────────┘
                                          │ (writes ANTHROPIC_BASE_URL)
                                          ▼
                                ┌─────────────────────────────────────────┐
                                │  free-claude-code proxy (port :8082)    │
                                │  ├─ provider routing                    │
                                │  ├─ Anthropic ↔ OpenAI translation      │
                                │  └─ rate-limit handling                 │
                                └─────────────────────────────────────────┘
                                          │
              ┌───────────────────────────┼───────────────────────────┐
              ▼                           ▼                           ▼
       Anthropic API           Local: Ollama / llama.cpp         Cloud free-tier:
       (default)               (qwen2.5-coder:7b,                NIM / OpenRouter
                                qwen3-coder:next,                / DeepSeek
                                qwen3.6-27b)
```

### Test map

| Code path | Test |
|---|---|
| `superagent-classify` adds `meta.complexity` field | `test/test-classify.sh` (existing 18 + 4 new for complexity) |
| `superagent-switch list` reads local-models.json | `test/test-switch-list.sh` (new) |
| `superagent-switch to <model>` flock + atomic write | `test/test-switch-race.sh` (new, concurrency test) |
| `superagent-switch canary <model> --depth=3` | `test/test-canary.sh` (new, mock proxy fixture) |
| `auto-fallback` skill complexity gate | `bench/run.sh` (new prompts for trivial-routing) |
| `limit-watch` hook trigger on UserPromptSubmit | `test/test-limit-watch.sh` (new, hook simulation) |
| `install.sh --with-free-llm` idempotency | `test/test-install-flags.sh` (new) |
| `video-craft` skill render | `test/test-video-render.sh` (new, render hello-world.html → MP4) |
| `free-llm` skill bring-up + canary | `test/test-free-llm-bringup.sh` (new) |
| Claude Code surface untouched | `test/test-md5-pin.sh` (existing) |

### Failure modes

1. **Cost-meter flatline post-switch (CRITICAL).** Engineer C found that `superagent-tracker.sh:76` filters to `Bash` tool only, and `superagent-cost` line 32-33 buckets unknown-model spend at $10/M (Opus rate, fictional). Result: switch to local → cost reads $0 → limit-watch never re-evaluates → deadlock. **Fix:** widen tracker to Read/Edit/Write/Grep + add `local:<model>` price tier of $0 + recalc limit threshold from observed rate, not absolute spend.

2. **Switch mid-tool-call race.** No mutex defined. **Fix:** `~/.superagent/switch.lock` (flock); switch refuses if N in-flight; OR drains for 5s then aborts.

3. **Canary insufficient for tool-use coherence.** Single call validates JSON shape, not multi-step. **Fix:** 3-step canary (Read → Edit → Bash) with known-good fixture under `test/canary-fixtures/`.

4. **`limit-watch` PreToolUse causes mid-session switch.** **Fix:** trigger on `UserPromptSubmit` only — quiesce point between user turns.

5. **`local-models.json` torn write under concurrent sessions.** **Fix:** flock + atomic temp-rename (copy `superagent-tracker.sh:113` pattern).

6. **`complexity` top-level key breaks downstream consumers.** **Fix:** namespace under `meta.complexity` to keep top-level shape backward-compatible.

7. **Wrong model IDs in tier mapping.** Engineer A found planned IDs (`qwen3.6-27b`, `qwen3-coder:next`, `deepseek-v4-pro`) don't appear in `free-claude-code/nvidia_nim_models.json` or its README examples. **Fix:** use real IDs (`nvidia_nim/qwen/qwen3.5-397b-a17b`, `nvidia_nim/moonshotai/kimi-k2.5`, `unsloth/MiniMax-M2.5-GGUF` for Opus tier; `ollama/qwen2.5-coder:7b` for Sonnet/Haiku tier).

8. **`pipx install free-claude-code` 404s.** Verified: not on PyPI. Requires Python 3.14+. **Fix:** vendor via `git clone + uv venv --python 3.14 && uv sync`. OR publish to PyPI first as v2.2 prereq.

9. **`brew install ollama` / `brew install llama.cpp` macOS-only.** **Fix:** OS-detection block; Linux uses `curl -fsSL https://ollama.com/install.sh | sh` and source-build llama.cpp.

10. **16 GB Qwen3.6-27B download has no disk check, no resume.** **Fix:** `df -h` precheck (need 21 GB free), `curl -L -C - --output ~/.cache/llama.cpp/models/...`.

11. **`adapters/hyperframes/templates/` empty by spec.** Wrong directory. **Fix:** rename to `bundles/hyperframes/install.sh` + `bundles/free-claude-code/install.sh` — these install runtime deps, not platform instruction templates.

### Migration plan

- New files only. No existing files renamed or moved. No DB migrations.
- Existing 18 classifier tests must continue to pass — `meta.complexity` is additive (top-level shape unchanged).
- `install.sh` MD5 (`bbb1ebc22cecf60106e33a25b001f130`) and `CLAUDE.md` MD5 (`14485d2a80d452445c1f68e0b188254c`) verified pre-merge.

---

## Risks

### Risk 1: Phase C cost-meter deadlock (HIGH)
*Source:* Engineer C critical risk #1. *Mitigation:* widen tracker to all tool types + add `local:` price tier (covered in Failure Mode 1). *If unmitigated:* auto-fallback ships broken — user switches to local once, never returns.

### Risk 2: free-claude-code not on PyPI (HIGH)
*Source:* Engineer B hard blocker #1. *Mitigation:* either publish PyPI package as v2.2 prereq (~1 day) OR vendor via git clone (~3 hr extra work). *If unmitigated:* `--with-free-llm` fails on every install.

### Risk 3: Linux install path undefined (MEDIUM)
*Source:* Engineer B blockers #2 + #3. *Mitigation:* OS-detection block in all heavy-flag installers. *If unmitigated:* v2.2 ships macOS-only despite README claiming cross-platform.

### Risk 4: Brand fragmentation across 3 pitches (MEDIUM)
*Source:* Engineer D major-rewrite finding. *Mitigation:* unify under "The cost layer for AI development" + put video-craft below-fold. *If unmitigated:* feature-list README, no clear positioning, weak conversion.

### Risk 5: 18-test classifier regression (MEDIUM)
*Source:* Engineer C race issue #6. *Mitigation:* namespace `complexity` under `meta`. *If unmitigated:* breaks downstream JSON consumers, fails CI.

### Risk 6: Local-LLM tool-use breakage (MEDIUM)
*Source:* Engineer C critical risk #3. *Mitigation:* 3-step canary preflight before any switch. *If unmitigated:* user switches to local, model corrupts files in production.

### Risk 7: Footprint shock (LOW)
*Source:* Engineer B issue #8. `--full` install = ~21.5 GB disk + bandwidth. *Mitigation:* document upfront; require explicit confirmation prompts before each heavy download. *If unmitigated:* user trust erodes.

### Risk 8: Plan complexity → ship slip (MEDIUM)
*Original plan estimate 8.5 hr; engineer reviews surface ~3 hr of additional fix work in Phase B + C. New estimate: 11.5 hr. *Mitigation:* hard-cut option (A+B+D ships v2.2; C in v2.3 with all Engineer C fixes integrated cleanly).

---

## Decision

**Status: `PAUSED_FOR_BUBBLE_UPS`**

### Auto-decided (mechanical, applied)

- Skill structural conventions (frontmatter, `references/`, `recipes/`, "When to use", "Procedure", "Verification") — apply `cso/SKILL.md` template to both new skills (P5 Explicit).
- `meta.complexity` namespacing — namespace under existing structure, do not break top-level JSON shape (P5 Explicit + P6 Bias-toward-action).
- Limit-watch trigger = `UserPromptSubmit` (P3 Pragmatic — only safe quiesce point; PreToolUse rejected as mid-session).
- Disk pre-flight check + `curl -C -` resume on Qwen3.6-27B download (P1 Completeness — covers the failure case).
- 3-step canary (Read → Edit → Bash) over single-step (P1 Completeness — single canary insufficient per Engineer C #3).
- Move heavy-bundle installers from `adapters/` to `bundles/` directory (P5 Explicit — adapters are instruction-template installers, not dependency installers).
- Cost-meter widening to Read/Edit/Write/Grep + `local:<model>` $0 tier (P1 Completeness — fixes deadlock Risk 1).
- README hero stays as v2.1 opener "Stop paying for tokens..." with a new subhead unifying all three pitches (P3 Pragmatic — works, don't break).
- Video-craft positioned below-fold as halo product (P5 Explicit + Engineer D recommendation; preserves brand focus).
- Real model IDs in tier mapping replaces fictional ones (P3 Pragmatic — fictional IDs fail at runtime, this is mechanical).
- Real install command for free-claude-code (`uv tool install` from git, not pipx) — mechanical, the alternative doesn't work.
- Real install command for hyperframes (`npm i -g hyperframes` or `npx`, not `bun install -g`) — mechanical.

### Bubble-ups (require user input — none auto-decidable)

#### A — Skills design

**A.1 — Default proxy port collision.**
- *Question:* keep `:8082` (free-claude-code default) or namespace to `:18082` to avoid clashing with users who run free-claude-code standalone?
- *Recommendation:* `:18082` for SuperAgent-managed proxy. Lets users keep their existing proxy on `:8082`.

**A.2 — Recipe authorship.**
- *Question:* author the 4 video-craft recipes fresh (we own them, no network dep at install) OR wrap upstream `npx skills add heygen-com/hyperframes` (less maintenance)?
- *Recommendation:* author fresh for v2.2; revisit in v2.3 if upstream skill set proves stable.

**A.3 — Trigger ownership ambiguity.**
- *Question:* "save tokens" — route to existing `token-stats` skill (current behavior) OR new `free-llm` skill?
- *Recommendation:* keep with `token-stats` (existing); add `free-llm` triggers like "switch to free", "use local model", "no Anthropic key".

#### B — Install/bundling

**B.1 — free-claude-code distribution.** ⚠ HARD BLOCKER
- *Question:* Publish free-claude-code to PyPI as v2.2 prerequisite (~1 day external work, not in v2.2 scope) OR vendor via git clone with Python 3.14 venv (~3 hr extra in v2.2)?
- *Recommendation:* vendor via git clone for v2.2; publish to PyPI as v2.3 polish item.

**B.2 — Linux support.**
- *Question:* drop heavy install flags on Linux for v2.2 (macOS-only) OR budget ~2 hr for cross-platform OS-detection blocks?
- *Recommendation:* cross-platform support; the brand promise is "works everywhere".

**B.3 — llama.cpp wiring for `--with-near-opus`.**
- *Question:* run llama.cpp as HTTP server (so free-claude-code proxy routes to it) OR CLI invocation per-call?
- *Recommendation:* HTTP server (llama-server) so free-claude-code can route uniformly; matches Ollama/LM Studio architecture.

#### C — Routing brain

**C.1 — Hard-cut decision.** ⚠ USER CHALLENGE
- *Question:* user explicitly requested A+B+C+D+verify in this turn. Engineer C found Phase C is the load-bearing weak link with 6 specific issues requiring rework. Two paths:
  - **Option α (user direction):** Ship A+B+C+D in v2.2. Adds ~3 hr to fix Engineer C's findings cleanly. Total ~11.5 hr.
  - **Option β (engineer challenge):** Hard-cut to A+B+D in v2.2. Phase C ships in v2.3 with all C fixes integrated. v2.2 ships in ~5 hr. Same total work, just split.
- *Why surface this:* Both Engineer C and the autoplan principles (P3 Pragmatic, P6 Bias-toward-action) suggest β. But user said "I want A+B+C+D" — premise confirmation required.
- *What's missing:* user's actual deadline. If shipping v2.2 today matters, β. If quality > speed, α.
- *Cost if wrong:* α with bugs = broken auto-fallback in production = user-visible regression. β = no v2.2 free-LLM auto-switch (manual `superagent-switch` only) until v2.3.

**C.2 — Auto-fallback policy when canary fails.**
- *Question:* if local canary fails after limit-triggered switch, what's the policy — auto-revert to Anthropic (and accept the rate-limit hit) OR freeze and prompt user?
- *Recommendation:* freeze + prompt. Silent revert hides limit-state from user.

**C.3 — Complex tasks over budget threshold.**
- *Question:* if `complexity: complex` AND budget > 80% — keep Anthropic anyway, force-switch to local, OR hard-stop with "limits hit" message?
- *Recommendation:* keep Anthropic; warn user; let them manually `superagent-switch` if they accept the quality drop.

**C.4 — Limit-watch unattended switching.**
- *Question:* allow `limit-watch` to switch silently during active session (between turns) OR require user confirmation every time?
- *Recommendation:* default require confirmation; opt-in `superagent-switch auto on` for unattended.

#### D — README/marketing

**D.1 — Hero positioning.** ⚠ USER CHALLENGE
- *Question:* keep v2.1 hero "Stop paying for tokens..." with new subhead (recommended), OR adopt Engineer D's stronger reframe to category-creating *"The cost layer for AI development"*?
- *Why surface this:* Engineer D made a strong case for the category framing. v2.1 hero works but is feature-level; "cost layer" is positioning-level. Affects narrative spine and the competitive table.
- *Cost if wrong:* feature-level hero loses to better-positioned competitors over time; category framing is a riskier bet but bigger long-term moat.

**D.2 — Privacy guarantee.**
- *Question:* Free-LLM mode — is it strictly local (Ollama/llama.cpp only, never cloud free-tier) OR does it include third-party providers (NIM/OpenRouter/DeepSeek)?
- *Why surface this:* this is brand-defining. Privacy-first vs cost-first are different products. FAQ answer + opt-in flags depend on this.
- *Recommendation:* default local-only with explicit opt-in flag for cloud free-tier; FAQ leads with "your code stays on your machine by default".

**D.3 — Competitive positioning table.**
- *Question:* include explicit competitive table comparing SuperAgent to Cursor/Cline/Aider/Continue/Copilot in v2.2 README?
- *Recommendation:* yes — Engineer D specifically called out the wedge. One table, four rows (cost-aware routing / multi-tool / multi-domain / free-LLM fallback). Don't trash competitors; position above them.

**D.4 — Audience segmentation.**
- *Question:* lead v2.2 hero copy targeting indie devs (cost-sensitive, free-LLM-first) OR enterprise (compliance-sensitive, never-free-LLM)?
- *Recommendation:* indie devs above-fold; enterprise below-fold. Indie crowd is the natural acquisition path; enterprise can't deploy until they have indie-side validation anyway.

---

### Recommended next step

**Resolve bubble-ups in this priority order:**

1. **C.1 (Hard-cut decision)** — biggest scope impact. Choose α or β.
2. **B.1 (free-claude-code distribution)** — hard blocker; choose PyPI prereq or git-clone vendoring.
3. **D.1 (Hero positioning)** — narrative spine; choose v2.1-style or "cost layer" reframe.
4. **D.2 (Privacy guarantee)** — brand-defining; choose local-only-by-default or include cloud free-tier.
5. **B.2 (Linux support)** — scope decision; cross-platform vs macOS-only.
6. **A/B/C/D minor bubble-ups** — single-line answers each (A.1, A.2, A.3, B.3, C.2, C.3, C.4, D.3, D.4).

After bubble-ups resolved, I will:
- Update this plan doc with locked decisions
- Re-emit phase order + final effort estimate
- Execute via parallel subagent dispatch for independent phases (A.1+A.2 parallel; B/C/D sequential per dep ordering)
- Run full verification gate (existing tests + 9 new tests)
- Push commit + tag v2.2.0

---

## Verification gate (locked, will run pre-merge)

- [ ] `bash test/test-classify.sh` — 22/22 PASS (18 existing + 4 new for `meta.complexity`)
- [ ] `bash bench/run.sh` — 24/24 PASS (20 existing + 4 new trivial-routing prompts), HARD GATE ≥ 0.90
- [ ] `bash test/test-switch-list.sh` — switch CLI subcommands
- [ ] `bash test/test-switch-race.sh` — concurrent flock test
- [ ] `bash test/test-canary.sh` — 3-step canary with fixture
- [ ] `bash test/test-limit-watch.sh` — UserPromptSubmit trigger
- [ ] `bash test/test-install-flags.sh` — `--with-*` idempotency
- [ ] `bash test/test-video-render.sh` — hello-world.html → MP4 + ffprobe duration check
- [ ] `bash test/test-free-llm-bringup.sh` — proxy bring-up + canary pass
- [ ] `python3 bin/superagent-compile --platform all` — all adapters regenerated
- [ ] `md5 install.sh` matches `bbb1ebc22cecf60106e33a25b001f130`
- [ ] `md5 CLAUDE.md` matches `14485d2a80d452445c1f68e0b188254c`
- [ ] All new install.sh files: `bash -n` clean
- [ ] Cursor templates ≤ 12k char total

---

## Approval checkboxes

- [ ] C.1 resolved (α full A+B+C+D or β hard-cut to A+B+D)-> full A+B+C+D
- [ ] B.1 resolved (PyPI prereq or git-clone vendor) -> choose the best
- [ ] D.1 resolved (v2.1 hero or "cost layer" reframe) -> hero
- [ ] D.2 resolved (privacy default) -> privacy default
- [ ] B.2 resolved (Linux support) -> linux
- [ ] All minor bubble-ups answered (or "use recommendation")-> use recommendation
- [ ] Ready to execute -> Yes
