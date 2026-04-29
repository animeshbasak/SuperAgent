# SuperAgent v2.2 — Multi-Domain Expansion + Cost-Aware Routing

> **Date:** 2026-04-29
> **Status:** Draft — awaiting approval
> **Goal:** Expand SuperAgent beyond Claude Code orchestration into video generation (hyperframes) and free/local LLM routing (free-claude-code), with a cost-aware fallback brain that auto-routes trivial tasks to local models when limits approach.

---

## Constraint: Zero Impact on Existing Behavior

- All current 15 skills, hooks, plugins, agents, and adapters remain untouched.
- New skills + CLIs + bundling are additive only.
- `install.sh` and `install-universal.sh` get new optional flags — default behavior unchanged.
- MD5 lock on `install.sh` + `CLAUDE.md` re-verified pre-merge.

---

## Phase A — Two New Skills

### A.1 `skills/video-craft/SKILL.md`

Teaches the agent to author HTML-based video compositions and render them to MP4 using hyperframes.

**Triggers:** "make a video", "render animation", "MP4", "video ad", "GSAP timeline", "hyperframes", "HTML video", "frame-accurate render"

**Skill structure:**
```
skills/video-craft/
├── SKILL.md                     # router + procedure
├── references/
│   ├── architecture.md          # composition / scene / block taxonomy
│   ├── animations.md            # GSAP timelines, easing, deterministic seeking
│   ├── catalog.md               # 50+ block types from hyperframes
│   └── pipeline.md              # CLI usage, render flags, golden tests
└── recipes/
    ├── hello-world.html         # minimal composition
    ├── product-ad-30s.html      # standard product video template
    ├── data-driven-chart.html   # animated chart from JSON
    └── lower-third-overlay.html # title bar with motion
```

**Procedure:**
1. Detect intent → which recipe.
2. Verify hyperframes CLI installed (`hyperframes --version`); if not, run `bash adapters/hyperframes/install.sh`.
3. Author HTML composition.
4. Render via `hyperframes render --input <file> --output <out.mp4>`.
5. Verify output exists and length > 0.

### A.2 `skills/free-llm/SKILL.md`

Teaches the agent to set up free-claude-code as a transparent proxy and route Claude Code through free/local LLMs.

**Triggers:** "free LLM", "local LLM", "ollama", "no Anthropic key", "save tokens", "switch to free", "deepseek free"

**Skill structure:**
```
skills/free-llm/
├── SKILL.md
└── references/
    ├── providers.md             # NIM / OpenRouter / Ollama / LM Studio matrix
    ├── routing.md               # which model maps to Opus/Sonnet/Haiku tier
    └── troubleshooting.md       # 429s, tool-call failures, context truncation
```

**Procedure:**
1. Detect or install free-claude-code (`pipx install free-claude-code` or local clone).
2. Detect available providers (`ollama list`, `curl localhost:1234/v1/models` for LM Studio).
3. Show user the per-tier mapping recommendation (default below).
4. Write `.env` with `ANTHROPIC_BASE_URL=http://localhost:8000`.
5. Start proxy in background; verify with canary tool-call test.
6. Tell user to restart Claude Code session.

**Default tier mapping (April 2026):**
| Anthropic tier | Free local default | Free cloud default |
|---|---|---|
| Opus | qwen3.6-27b (llama.cpp) | deepseek-v4-pro (OpenRouter) |
| Sonnet | qwen3-coder:next (Ollama) | deepseek-v4-flash (OpenRouter) |
| Haiku | qwen2.5-coder:7b (Ollama) | qwen3-coder:next (OpenRouter) |

---

## Phase B — Install.sh Bundling

### B.1 `install.sh` — Add 4 new optional flags

| Flag | What it does |
|---|---|
| `--with-video` | Installs Bun + hyperframes CLI globally (`bun install -g hyperframes`) |
| `--with-free-llm` | Installs Ollama + pulls qwen2.5-coder:7b · installs free-claude-code via pipx |
| `--with-near-opus` | Installs llama.cpp + downloads Qwen3.6-27B Q4_K_M (~16 GB, prompts confirm) |
| `--full` | All of the above |

Default install behavior unchanged. Each flag is opt-in.

### B.2 `install-universal.sh` — Same flags

Mirror flags above so they work across all 8 platforms.

### B.3 New adapter directories

```
adapters/
├── hyperframes/
│   ├── install.sh         # Bun + hyperframes global install
│   └── templates/         # (none needed — uses hyperframes catalog)
└── free-claude-code/
    ├── install.sh         # pipx install + provider detection + proxy bring-up
    └── templates/
        └── .env.example   # ANTHROPIC_BASE_URL + provider keys
```

---

## Phase C — Cost-Aware Routing Brain

### C.1 `bin/superagent-switch` (new CLI)

```
superagent-switch list                    # show installed local models + cloud free options
superagent-switch to <model>              # switch Claude Code to model via free-claude-code proxy
superagent-switch back                    # restore Anthropic API
superagent-switch auto on|off             # enable/disable auto-fallback on limit threshold
superagent-switch status                  # show current proxy state + active model
```

### C.2 `skills/auto-fallback/SKILL.md` (new skill)

Routing logic:
```
classifier output:
  complexity=trivial     → suggest qwen2.5-coder:7b (Ollama)
  complexity=moderate    → suggest qwen3-coder:next (Ollama or OpenRouter)
  complexity=complex     → keep Anthropic UNLESS over budget threshold
  
budget signal:
  spend > 80% of plan    → force-suggest local for moderate/trivial
  5h-limit < 30 min      → force-suggest local for moderate/trivial
  429 burst (>=3 in 60s) → switch immediately, prompt confirm
```

### C.3 `hooks/superagent-limit-watch.sh` (new hook)

PreToolUse hook. Reads from existing `superagent-cost today` output. Writes warning to statusline when threshold hit. Triggers `superagent-switch auto` if enabled.

### C.4 Classifier `complexity` field

Update `skills/superagent/brain/rules.yaml` — add `complexity: trivial|moderate|complex` to each rule.

Update `bin/superagent-classify` to emit:
```json
{"chain": [...], "complexity": "trivial|moderate|complex", "hint": [...]}
```

### C.5 Local model registry

`~/.superagent/local-models.json` — cache of `ollama list` + LM Studio probe + llama.cpp scan. Refreshed hourly. Used by `superagent-switch list`.

---

## Phase D — README v2.2

Reposition README around three pitches stacked:

1. **"Token-aware routing across 8 AI tools"** (existing v2.1 pitch)
2. **"Free LLM fallback — your AI never runs out"** (new — Phase A.2 + C)
3. **"Multi-domain — code, video, design, security"** (new — Phase A.1 video-craft + existing skills)

Add new sections:
- "Closest to Opus on local hardware" (Qwen3.6-27B)
- "Auto-fallback when limits hit" (with screenshot)
- "Make videos with hyperframes" (one-paragraph teaser)

Keep existing technical depth below the fold.

---

## Phase Order + Estimated Effort

| Order | Phase | Subphases | Effort | Parallelizable? |
|---|---|---|---|---|
| 1 | A.1 + A.2 | Two skill files + reference docs | 2 hr | Yes (parallel subagents) |
| 2 | B.1 + B.2 + B.3 | Install flags + 2 new adapters | 1.5 hr | Partial (B.3 parallel) |
| 3 | C.4 (classifier) | Add complexity field + tests | 1 hr | No (gates C.1–C.3) |
| 4 | C.1 + C.2 + C.3 + C.5 | switch CLI + skill + hook + registry | 3 hr | Yes (parallel subagents) |
| 5 | D | README rewrite | 30 min | No |
| 6 | Verification | bench + test-classify + smoke | 30 min | Run all in parallel |

**Total: ~8.5 hr.** Ship as v2.2.0. Tag and push.

---

## Verification Plan

### Automated gates (must pass pre-merge)
- `bash test/test-classify.sh` — 18/18 PASS, plus new tests for `complexity` field
- `bash bench/run.sh` — 20/20 PASS, HARD GATE ≥ 0.90
- `python3 bin/superagent-compile --platform all` — all adapters regenerated, no drift
- `md5 install.sh` matches `bbb1ebc22cecf60106e33a25b001f130` (Claude untouched)
- `md5 CLAUDE.md` matches `14485d2a80d452445c1f68e0b188254c`
- `bash -n` clean on all new install.sh files
- New tests: `test/test-switch.sh` (CLI), `test/test-auto-fallback.sh` (skill simulation)

### Manual smoke tests
- `bash install.sh --with-free-llm` on fresh project → verifies Ollama + free-claude-code installed
- `superagent-switch list` → shows real installed models
- `superagent-switch to qwen2.5-coder:7b` → proxy starts, canary tool-call passes
- `superagent-switch back` → Anthropic restored
- `bash install.sh --with-video` → hyperframes CLI installed, sample render produces MP4

### Regression gate
- All 15 existing skills must remain functional
- `install-universal.sh --list` still detects 6/8 platforms
- Cursor templates still under 12k char cap

---

## Open Questions (need user input before execution)

1. **Bundle Qwen3.6-27B by default in `--with-near-opus`?** It's a 16 GB download. User must confirm.
   - Default: prompt user `"Download Qwen3.6-27B (16 GB)? [y/N]"` before starting.

2. **OpenRouter API key handling.** Cloud free tier requires account. Should we provision automatically, or just doc the steps?
   - Recommend: doc only. Don't auto-provision third-party accounts.

3. **Hyperframes is Apache 2.0 but big monorepo.** Bundle the CLI package only (`@hyperframes/cli`) or full `bun install -g hyperframes`?
   - Recommend: CLI only via npm/bun global. Smaller footprint.

4. **Where does the auto-fallback hook live for non-Claude platforms?** Cursor/Copilot can't run hooks.
   - Recommend: Phase C is Claude Code only for v2.2. Other platforms can run `superagent-switch` manually as a CLI. Note this limitation in README.

5. **Quality preflight test before switching.** Ship in v2.2 or punt to v2.3?
   - Recommend: ship a basic `superagent-switch canary <model>` command that sends one tool-call request and validates response shape. Refuse switch if it fails.

---

## Risk Register

| Risk | Severity | Mitigation |
|---|---|---|
| Qwen3.6-27B not in Ollama yet (needs llama.cpp) | Medium | Use llama.cpp backend in `--with-near-opus`; document explicitly |
| Tool-use failures on local LLMs | High | Canary preflight before switch (Open Question 5) |
| Anthropic limit detection inaccurate | Medium | Use own spend tracking; document ±5% accuracy |
| free-claude-code provider rate limits hit fast | Medium | Built-in throttling already in free-claude-code; document |
| install.sh footprint blows up | Low | All new deps are flag-gated; default install unchanged |
| Plan complexity → ship slips | Medium | Phase A + B alone ships in 3.5 hr — hard cut to v2.2 if C overruns |

---

## Hard Cut for v2.2 (if time-boxed)

Ship Phase A + B + D only. Phase C (auto-fallback brain) becomes v2.3.

This still delivers:
- 2 new skills (`video-craft`, `free-llm`)
- Bundled installers for hyperframes + free-claude-code + local LLMs
- Repositioned README

User can manually run `superagent-switch` (which would still ship in v2.3) for the smart fallback.

---

## Approval Checkboxes

- [ ] Plan scope approved
- [ ] Open Questions 1–5 answered
- [ ] Hard-cut policy agreed (full A+B+C+D vs A+B+D)
- [ ] Ready to execute
