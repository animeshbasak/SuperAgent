# SuperAgent — AI Coding Agent Enhancement System

> One install turns any AI coding agent into a senior engineer who knows your codebase,
> remembers every decision, never skips tests, and ships premium UIs.

# SuperAgent Ethos

Every skill in this repo opens by acknowledging these five principles.

1. **Verify or die.** No task is done until the work has been run, tested, or observed. Typecheck and test pass ≠ feature works.
2. **Rewind, don't correct.** When a path goes wrong, rewind the session. Corrections leave failed attempts in context and degrade future decisions.
3. **Memory is compounding interest.** MemPalace and the learnings diary exist so next session is cheaper than this one. Write what you learn.
4. **Leverage over toil.** If an action will be done more than once, make it a skill or a chain. Code three times → abstract. Prompt three times → skill.
5. **Local first.** Prefer local memory, local search, local models when adequate. Network calls are a cost, not a default.


## Task Routing

When a task matches these patterns, follow the corresponding skill chain:

| Pattern Keywords | Skill Chain |
|-----------------|-------------|
| bug, fix, broken, error, crash, stack trace, traceback, debug | systematic-debugging → test-driven-development |
| bug, fix, broken, error, crash, stack trace, traceback, debug | systematic-debugging → test-driven-development |

## Tools

SuperAgent includes these CLI tools. Run them when indicated by the routing table:

| Tool | Command | Purpose |
|------|---------|---------|
| Classifier | `superagent-classify "<task>"` | Route task to skill chain (JSON output) |
| Chain Runner | `superagent-chain <chain-name>` | Execute a YAML skill chain |
| Cost Tracker | `superagent-cost today` | Token cost by model + coach notes |
| Learnings | `superagent-learn add "<text>"` | Save per-project learnings |
| Knowledge Graph | `graphify query "<question>"` | Query codebase knowledge graph |
| Memory | `mempalace search "<query>"` | Cross-session memory search |

---

## Skills Reference

### auto-fallback
> Cost-aware routing brain — switch from Anthropic API to a free local model when the user is approaching plan limits, hitting 429 bursts, or asks to "save anthropic" / "switch local" / "rate limit" / "approaching limit". Auto-fires on complexity=trivial when budget is tight. Picks the right Ollama / LM Studio / llama.cpp model for the task complexity, runs a 3-step canary first, and switches via `superagent-switch`. State lives in `~/.superagent/`.

# auto-fallback

The cost-aware routing brain. Decides when to flip Claude Code from Anthropic API to a local model running behind the free-claude-code proxy on `http://localhost:18082`.

## Inputs

1. **Latest classifier output** — `meta.complexity` ∈ {trivial, moderate, complex}
   from `superagent-classify <task>`.
2. **Budget signal** — `superagent-cost today --json`
   - `pct_of_plan` — fraction of plan limit consumed (0..1)
   - `time_to_5h_reset_minutes` — minutes until rolling 5h limit resets
   - `recent_429_count_60s` — number of 429s in the last 60 seconds
3. **Available local models** — `superagent-switch list` (auto-refreshes if stale)
4. **Auto flag** — `~/.superagent/auto-fallback.flag` ("on" or "off")

## Decision Tree

```
complexity == "trivial"
  → suggest qwen2.5-coder:7b (Ollama)

complexity == "moderate"
  → suggest qwen3-coder:next

complexity == "complex" AND pct_of_plan > 0.80
  → KEEP Anthropic, warn user
    "complexity=complex; local models will degrade quality. burning Anthropic budget instead."
    Offer manual switch.

time_to_5h_reset_minutes < 30  AND complexity != "complex"
  → suggest local for moderate/trivial

recent_429_count_60s >= 3
  → switch immediately, prompt user to confirm
    (NOT auto unless `auto on`)
```

## Procedure

1. Read latest classifier output — pull `meta.complexity`.
2. Run `superagent-cost today --json` — parse budget signals.
3. Apply the decision tree above to pick a candidate model (or NONE).
4. If a local model is suggested:
   a. Show menu of available models from `superagent-switch list`.
   b. User picks one (or accepts the suggested default).
   c. Run `superagent-switch canary <model> --depth=3`.
   d. **On canary pass** → `superagent-switch to <model>`; tell user to restart Claude Code.
   e. **On canary fail** → freeze. Prompt:
      - "try a different model"
      - "wait — keep Anthropic, retry in N minutes"
      - "accept Anthropic limits — proceed at reduced rate"
      Do NOT auto-revert.
5. If `auto-fallback.flag == on` AND no in-flight tool calls, the limit-watch hook
   may invoke this skill non-interactively; in that mode it must still confirm
   before flipping (pre-canary). Default behavior: require confirmation.

## Costs locked in

| complexity  | budget | action                                        |
|-------------|--------|-----------------------------------------------|
| trivial     | any    | local (`qwen2.5-coder:7b`)                    |
| moderate    | <80%   | Anthropic (Sonnet/Haiku)                      |
| moderate    | >80%   | local (`qwen3-coder:next`)                    |
| complex     | <80%   | Anthropic (Opus/Sonnet)                       |
| complex     | >80%   | KEEP Anthropic + warn — let user override     |
| any         | 429×3  | switch immediately + confirm                  |

## Recovery

- If switching breaks Claude Code → `superagent-switch back` restores Anthropic.
- Backed-up `ANTHROPIC_API_KEY` lives at `~/.superagent/anthropic-key.bak`.

## Notes

- All state under `~/.superagent/`, never `~/.claude/`.
- Free-claude-code proxy port is **18082** (not 8082).
- Auto-switch defaults OFF; opt-in for unattended use only.
- Canary is mandatory before any switch — never skip.

---

### autoplan
> Auto-pipeline a plan through product, design, and eng review sequentially, then synthesize into a single plan artifact. Use when you want the full review stack without invoking skills manually one at a time.

# Autoplan

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

Auto-review pipeline. Sequentially runs the full product (CEO), design, and engineering review skills over a single plan input, auto-deciding intermediate questions using the 6 decision principles, and synthesizing the results into one plan artifact at `docs/plans/<slug>.md`. Taste decisions and user challenges are surfaced at a final approval gate — everything else is decided for you.

## When to use

- New feature and you want the full review stack in one pass.
- User asks "give me a reviewed plan for X" or "run all reviews on this plan".
- Before any multi-week engineering commitment — you want product, design, and eng eyes on the plan before you touch code.
- You have a plan file and don't want to answer 15–30 intermediate questions across three separate skills.

Skip it when: the plan is a one-hour change, the plan is purely exploratory, or the user wants only one dimension reviewed (invoke that review skill directly instead).

## The 6 Decision Principles

These rules auto-answer every intermediate question across all three review phases. Preserve the ordering — the tiebreaker rules below depend on it.

1. **Choose completeness** — Ship the whole thing. Pick the approach that covers more edge cases.
2. **Boil lakes** — Fix everything in the blast radius (files modified by this plan + direct importers). Auto-approve expansions that are in blast radius AND < 1 day of effort (< 5 files, no new infra).
3. **Pragmatic** — If two options fix the same thing, pick the cleaner one. 5 seconds choosing, not 5 minutes.
4. **DRY** — Duplicates existing functionality? Reject. Reuse what exists.
5. **Explicit over clever** — 10-line obvious fix > 200-line abstraction. Pick what a new contributor reads in 30 seconds.
6. **Bias toward action** — Merge > review cycles > stale deliberation. Flag concerns but don't block.

**Conflict resolution (context-dependent tiebreakers):**

- **CEO phase:** P1 (completeness) + P2 (boil lakes) dominate.
- **Eng phase:** P5 (explicit) + P3 (pragmatic) dominate.
- **Design phase:** P5 (explicit) + P1 (completeness) dominate.

### Per-principle auto-decide vs bubble-up examples

- **P1 Choose completeness** — *Auto-decide:* two options cover the same cases, pick whichever is simpler (also P5). *Bubble-up:* only if "more complete" means doubling scope or cost.
- **P2 Boil lakes** — *Auto-decide:* a 3-file cleanup in the blast radius with no new infra. *Bubble-up:* borderline radius (3–5 files, or importers in a separate module).
- **P3 Pragmatic** — *Auto-decide:* two fixes differ only in style — pick the cleaner one silently. *Bubble-up:* the cleaner fix requires a new dependency.
- **P4 DRY** — *Auto-decide:* the helper already exists — reject the re-implementation. *Bubble-up:* existing helper almost fits but needs a 2-line extension someone may object to.
- **P5 Explicit over clever** — *Auto-decide:* drop a clever abstraction in favor of an obvious inline. *Bubble-up:* explicit version requires duplicating logic across 3+ files.
- **P6 Bias toward action** — *Auto-decide:* concern noted, doesn't block, log and move on. *Bubble-up:* concern might block — surface at the gate.

## Auto-decide vs Bubble-up

An **auto-decide** is a call the skill makes without waiting for user input — using the 6 principles in place of the user's judgment. A **bubble-up** is a call that pauses for explicit user approval at the Phase 4 gate.

Every auto-decision is classified:

- **Mechanical** — one clearly right answer. Auto-decide silently.
- **Taste** — reasonable people could disagree. Auto-decide with a recommendation, but surface at the Phase 4 gate. Three natural sources: (1) close approaches where top two are both viable, (2) borderline scope (3–5 files, ambiguous blast radius), (3) reviewer-disagreement where the design or eng reviewer disagrees and has a valid point.
- **User Challenge** — both reviewers (or the combined product + eng analysis) agree the user's stated direction should change. NEVER auto-decided. Surfaced at the gate with richer context: what the user said, what the reviews recommend, why, what context might be missing, cost if we're wrong.

### Auto-decide when

- Decision is Mechanical per the 6 principles (one clearly right answer).
- Decision is Taste but low-blast-radius and the recommended option aligns with the phase's dominant principles.
- Reviewers agree with each other and the recommendation aligns with user's stated direction.
- Deferral: the issue is outside the blast radius and can go to a TODO file (P6).

### Bubble-up when

- User Challenge: both reviews independently recommend changing the user's stated scope, features, or workflow.
- Close approaches where top two options have substantively different downstream impact.
- Borderline scope expansion (3–5 files, or ambiguous blast radius per P2).
- Security or feasibility flag (not a preference) — framing explicitly warns the user.
- Premise confirmation in Phase 1 — premises always require human judgment.

The user's original direction is the default. The reviews must make the case for change, not the other way around.

## Filesystem boundary

This skill **READS** the plan input (text or file path) and the three review skill files it invokes. It **WRITES** only to:

- `docs/plans/<slug>.md` — the synthesized plan artifact.
- `~/.superagent/brain/routes.jsonl` — routing log (via the `/superagent` router).

It never modifies source code. Implementation happens after approval, via separate skills (`/superagent executing-plans`, or direct edits you drive). If a review phase wants to surface a fix to source, it goes into the Eng Spec section of the synthesized plan — not into the code itself.

## Sequential orchestration — MANDATORY

Phases MUST execute in strict order: **CEO → Design → Eng**. Each phase MUST complete fully before the next begins. NEVER run phases in parallel — each builds on the previous:

- CEO locks in scope, forcing answers, and strategic framing. Design and Eng read from that frame.
- Design review refines the user-facing contract the Eng review will implement against.
- Eng review grounds the plan in real architecture and failure modes, producing the final spec.

Between each phase, emit a one-line phase-transition summary and verify that the prior phase's notes are saved before starting the next.

## Procedure

### Phase 0 — Intake

- Parse `$ARGUMENTS` as either plan text or a file path. If a path, read it; if text, treat it verbatim.
- Generate a slug: lowercase + kebab-case, max 40 chars, derived from the plan's title or one-line summary.
- Check for prior autoplan runs for this slug at `docs/plans/<slug>.md`. If present, ask the user: **continue** (pick up where the last run left off), **regenerate** (overwrite), or **diff** (show what changed since last run, then choose).
- Detect scope signals: does the plan have a user-facing surface (UI, flows, screens, visual design)? If no, Phase 2 (Design Review) is skipped with a note.
- Output: one line — "Plan: [title]. Slug: [slug]. UI scope: [yes/no]. Running full review pipeline with auto-decisions."

### Phase 1 — CEO Review

- Invoke the `plan-ceo-review` skill with the plan as input.
- Let it run its full methodology — premises, forcing answers, scope rubric, scope variants, alternatives, and recommendation.
- Override: every intermediate AskUserQuestion is auto-decided using the 6 principles. **Exception:** premise confirmation is the one non-auto-decided question — surface it to the user before proceeding.
- Capture into `ceo_notes`:
  - Scope mode (selective expansion, reduce, reframe, etc.).
  - The 6 forcing answers.
  - Rubric and scope variants.
  - Recommendation with classification (Mechanical / Taste / User Challenge).
  - Any taste decisions or user challenges flagged for the gate.

Phase transition: "Phase 1 complete. CEO recommendation: [X]. Taste decisions: [N]. User challenges: [N]. Proceeding to Phase 2."

### Phase 2 — Design Review

- If the plan has **no** user-facing surface (pure backend, infra, CLI-only change), skip and set `design_notes = "N/A backend only — no user-facing surface detected in Phase 0"`.
- Otherwise, invoke the `plan-design-review` skill with the plan + `ceo_notes` as context.
- Override: every intermediate AskUserQuestion is auto-decided using the 6 principles (dominant: P5 explicit, P1 completeness).
- Capture into `design_notes`:
  - Rating table across the review's dimensions.
  - Fixes and rewrites proposed.
  - Top-3 leverage moves.
  - Revised brief reflecting the review's changes.
  - Any taste decisions or user challenges flagged for the gate.

Phase transition: "Phase 2 complete. Design overall: [N]/10. Taste decisions: [N]. User challenges: [N]. Proceeding to Phase 3."

### Phase 3 — Eng Review

- Invoke the `plan-eng-review` skill with the plan + `ceo_notes` + `design_notes` as context.
- Override: every intermediate AskUserQuestion is auto-decided using the 6 principles (dominant: P5 explicit, P3 pragmatic).
- Capture into `eng_notes`:
  - Architecture (ASCII diagram or equivalent, data flow).
  - Edge cases enumerated.
  - Test map (codepath → test coverage).
  - Failure modes + critical-gap assessment.
  - Migration plan (if applicable).
  - Any taste decisions or user challenges flagged for the gate.

Phase transition: "Phase 3 complete. Eng recommendation: [X]. Critical gaps: [N]. Taste decisions: [N]. User challenges: [N]. Proceeding to synthesis."

### Phase 4 — Synthesis + Approval Gate

Write the synthesized plan to `docs/plans/<slug>.md` with these sections (each ≥ 2 paragraphs of substantive content — no placeholder text):

```markdown
# <Plan Title>

## Product Thesis
<from ceo_notes: problem, premises, scope mode, forcing answers, recommendation, why-now>

## Design Brief
<from design_notes: user contract, key surfaces, top fixes, revised brief.
If skipped: "N/A backend only — no user-facing surface in this plan.">

## Eng Spec
<from eng_notes: architecture, data flow, test map, failure modes, migration>

## Risks
<rolled up from all three phases — one subsection per risk with mitigation>

## Decision
<status: APPROVED | PAUSED_FOR_BUBBLE_UPS | BLOCKED
— list auto-decided items with classifications,
— list bubble-ups still open (taste decisions + user challenges),
— recommended next step>
```

Then:

- Print the synthesized plan's absolute path.
- If any bubble-ups remain unresolved, list them grouped by phase and **pause for user input** (Status: `PAUSED_FOR_BUBBLE_UPS`). Present taste decisions as a recommendation with rationale; present user challenges with the full context (what user said, what reviews recommend, why, what's potentially missing, cost if wrong).
- If all decisions were auto-decided and nothing needs user input, declare **`APPROVED: ready to execute via /superagent executing-plans`** and suggest the next command.
- If a phase produced a critical gap that can't be auto-decided away, emit `BLOCKED` with the specific gap and what the user needs to resolve before re-running.

## Output

- **File:** `docs/plans/<slug>.md` — synthesized plan with Product Thesis / Design Brief / Eng Spec / Risks / Decision sections. Each section has ≥ 2 paragraphs of substantive content.
- **Status:** `APPROVED` | `PAUSED_FOR_BUBBLE_UPS` | `BLOCKED`.
- **Console summary:** slug, phase scores (CEO / Design / Eng), count of auto-decided vs bubbled-up decisions, path to the synthesized plan, recommended next command.

## Verification

Before returning, verify:

- File exists at `docs/plans/<slug>.md`.
- Contains all 5 required sections: **Product Thesis**, **Design Brief** (or explicit N/A note), **Eng Spec**, **Risks**, **Decision**.
- Each section has ≥ 2 paragraphs of substantive content (read the file back and confirm — not placeholder text like "TBD" or "see notes").
- If status is `PAUSED_FOR_BUBBLE_UPS`, the specific bubble-ups are listed in the Decision section and also surfaced in the console output so the user can act on them.
- If status is `APPROVED`, the Decision section names the next step (`/superagent executing-plans <slug>`).
- No source files were modified — `git status` should show only `docs/plans/<slug>.md` as new/changed.

---

### bench
> Run the 20-prompt classifier bench and print the score. Use after editing rules.yaml or after adding a new skill that affects routing.

# Bench

> **Ethos:** Verify or die.

## When to use
- After any change to `skills/superagent/brain/rules.yaml`.
- After adding a new skill that should route via a new regex.
- As a pre-merge gate — the CI workflow runs this automatically.

## Procedure

1. Detect the repo root (the directory that contains `bench/run.sh`).
2. Run:
   ```bash
   bash bench/run.sh
   ```
3. Capture output and exit code.
4. If exit code == 0: report `PASS` + the avg score.
5. If non-zero: print the per-prompt misses. Suggest which `rules.yaml` regex to tune by correlating misses with rule names.

## Output

```
Bench: PASS=N FAIL=M AVG=X.XX
```

If FAIL > 0: per-prompt diagnostics + a ranked list of rules to tune.

## Verification

Exit non-zero if avg < 0.90 OR fails > 2 (hard gate thresholds from Task 1.3).

---

### cso
> Security audit — OWASP top-10 scan, STRIDE threat model, secrets grep, supply-chain check. Output is a severity-ranked findings report.

# Chief Security Officer

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Before launching to public / external users.
- Quarterly audit.
- When user asks "is this secure?"
- Any handling of auth, PII, payment, or LLM-driven code execution.

## Procedure

### 1. OWASP Top-10 scan
For each of: Broken Access Control, Cryptographic Failures, Injection, Insecure Design, Security Misconfiguration, Vulnerable/Outdated Components, Auth Failures, Software Integrity, Logging/Monitoring Failures, SSRF — scan the codebase. Report findings per category.

### 2. STRIDE threat model
For the main data flows: Spoofing / Tampering / Repudiation / Information Disclosure / Denial of Service / Elevation of Privilege. One paragraph per.

### 3. Secrets scan
Run in order of preference:
- `gitleaks detect --no-git` if installed
- Else: `grep -rE 'API_KEY|SECRET_KEY|PRIVATE_KEY|BEARER|AWS_SECRET' --include='*' --exclude-dir=node_modules --exclude-dir=.git`.

### 4. Supply-chain audit
- `npm audit --production` if `package.json` present.
- `pip-audit` if `pyproject.toml` or `requirements.txt`.
- `cargo audit` if `Cargo.toml`.
- Report high/critical only.

## Output
Markdown report ranked by severity (Critical / High / Medium / Low):
```
# Security Audit — <date>

## Critical
- <finding>

## High
- <finding>

## Medium
- <finding>

## Low
- <finding>

## Verdict
<Safe to ship | Needs fixes before ship | Block>
```

## Verification
- All 4 sections executed (OWASP / STRIDE / secrets / supply-chain).
- At minimum: "no findings" for clean categories (not silent).
- Verdict is one of the three values.

---

### fanout
> Run 2+ skills in parallel via dispatching-parallel-agents and merge their reports. Use when subtasks are independent (no shared state).

# Fanout

> **Ethos:** Leverage over toil.

## When to use
- Two or more skills or tasks with NO shared state.
- User asked "review this AND also investigate AND also write docs".
- Research questions across independent domains.

## Inputs
- `$ARGUMENTS` — whitespace-separated list of skill names.

## Procedure

1. Parse `$ARGUMENTS` into a skill list. Reject if fewer than 2 entries.
2. Invoke `superpowers:dispatching-parallel-agents` — one agent per skill in the list.
3. Each sub-agent runs its named skill in isolation on the same input context.
4. Collect each sub-agent's final report.
5. Merge into a single document, one H2 section per skill, skill name as heading.

## Output

```
# Fanout Report

## <skill-a>
<summary from agent-a>

## <skill-b>
<summary from agent-b>
```

## Verification
- Each invoked skill name appears as an H2 heading in the output.
- Each section has non-empty body (agent actually returned something).
- If any sub-agent failed: call out which one + the error, do not swallow.

---

### framer-motion
> Build production-grade React animation with framer-motion (`motion` API). Triggers on "framer motion", "animate this component", "animate presence", "page transition", "layout animation", "spring animation", "drag/gesture", "scroll-linked animation", "stagger children", "exit animation", "shared layout". Use for component-level motion in a React/Next.js codebase. Routes alongside `ui-ux-pro-max` for design coherence and `webgl-craft` only when the motion is cinematic / 3D.

# framer-motion

Component-level motion intelligence for React. Covers the seven primitives
that ship most of the value in real apps:

1. **`<motion.*>` primitive** — declarative animate / initial / exit.
2. **`AnimatePresence`** — exit animations for unmounting components.
3. **Variants** — orchestrated animation states with `staggerChildren`.
4. **Layout animations** — `layout` / `layoutId` for shared element transitions.
5. **Gestures** — `whileHover`, `whileTap`, `drag`, `dragConstraints`.
6. **Scroll-linked motion** — `useScroll`, `useTransform`, `useMotionValue`.
7. **Springs vs tweens** — when to use which transition shape.

## When to use

- User types "use framer-motion to …", "animate this", "add a page transition",
  "stagger these list items", "when the modal closes …", "make this draggable".
- User asks for **named patterns**: shared layout animation, hero image
  morphing into a card, scroll-driven parallax, swipeable carousel,
  orchestrated reveal, micro-interaction on hover/tap.
- Codebase already imports `framer-motion` or `motion/react` (check
  `package.json`).

**Do NOT use for:**
- 3D / WebGL / shader-based motion → `webgl-craft`.
- Static layout / typography / color decisions → `ui-ux-pro-max`.
- Rendered video output (HTML → MP4) → `video-craft`.
- CSS-only transitions / Tailwind `transition-*` utilities — those don't
  need framer-motion.

## Procedure

### 1. Confirm the dependency

```bash
grep -E '"(framer-motion|motion)":' package.json || true
```

- Already installed → continue.
- Missing → install with the project's package manager:
  - `pnpm add framer-motion` (or `motion` for v12+)
  - `npm i framer-motion`
  - `yarn add framer-motion`
- App Router projects: most motion components must run client-side. Add
  `'use client'` at the top of any file using `motion.*`, `AnimatePresence`,
  `useScroll`, etc.

### 2. Pick the primitive — decision table

| User intent                                    | Primitive                                         |
| ---------------------------------------------- | ------------------------------------------------- |
| Fade / slide on mount                          | `<motion.div initial animate transition>`         |
| Fade / slide on unmount                        | wrap in `<AnimatePresence>` + `exit={...}`        |
| Modal / drawer open ↔ close                    | `AnimatePresence` + `exit` + `mode="wait"` if needed |
| Route / page transition (App Router)           | `template.tsx` + `AnimatePresence` (`mode="wait"`) wrapping `{children}` keyed by pathname |
| List reveal one-by-one                         | parent variants + `staggerChildren` + child variants |
| Hero image morphs into a detail card           | `layoutId="hero"` on both elements                |
| Reorder grid / list smoothly                   | `layout` prop on each item                        |
| Hover / tap micro-interaction                  | `whileHover` / `whileTap`                         |
| Draggable card, swipeable                      | `drag` / `dragConstraints` / `dragElastic`        |
| Scroll progress bar                            | `useScroll().scrollYProgress` → `motion.div` width |
| Parallax / pin-on-scroll                       | `useScroll({ target, offset })` + `useTransform`  |
| Spring-feel (squishy)                          | `transition={{ type: "spring", stiffness, damping }}` |
| Smooth ease (no bounce)                        | `transition={{ duration, ease: [0.16, 1, 0.3, 1] }}` |

### 3. Lock the timing language

Use **one** of these three transition presets across the codebase. Don't
invent new easings ad-hoc — it produces an inconsistent feel.

```ts
// utils/motion.ts
export const easeOut: Transition  = { duration: 0.4, ease: [0.16, 1, 0.3, 1] };
export const easeOutSlow: Transition = { duration: 0.7, ease: [0.16, 1, 0.3, 1] };
export const spring: Transition   = { type: "spring", stiffness: 380, damping: 32, mass: 0.7 };
```

Reach for `spring` when the element responds to user input (drag, hover,
tap). Reach for `easeOut` for entry/exit. Reach for `easeOutSlow` for hero
or page-level reveals.

### 4. Variants — only when there's orchestration

Variants pay off when:

- A parent triggers child animations (`staggerChildren`, `delayChildren`).
- The same element animates through three or more named states.

For two-state component-level animation, inline `initial / animate /
transition` props are simpler and easier to read.

```tsx
const list = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.06, delayChildren: 0.1 } }
};
const item = {
  hidden: { opacity: 0, y: 16 },
  show:   { opacity: 1, y: 0, transition: easeOut }
};
```

### 5. AnimatePresence — exact rules

- Direct children of `<AnimatePresence>` MUST have a unique, stable `key`
  prop — otherwise exit animations don't fire.
- Use `mode="wait"` when the new element should mount only after the old
  one finishes exiting (page transitions).
- Use `mode="popLayout"` when items leave inside a flex/grid layout — it
  briefly removes them from layout flow so siblings don't jump.
- `initial={false}` on the parent skips the very-first mount animation
  (avoids a flash on hydration).

### 6. Layout animations — gotchas

- `layout` works on properties FLIP can interpolate (transform/opacity).
  It does NOT work on `width: auto` → `width: 200px` directly. Wrap the
  changing element or animate explicit numeric values.
- `layoutId` requires the same string on the source and target. They must
  exist in the same `<LayoutGroup>` (or globally if not nested).
- Layout animation respects `transition`. Pair with a spring for tactile
  feel.

### 7. Performance — only animate cheap properties

Animate `transform` (`x`, `y`, `scale`, `rotate`) and `opacity`. Avoid
animating `width`, `height`, `top`, `left`, `box-shadow`, `filter` in hot
paths — they trigger layout / paint and tank framerate on lower-end
devices. When you must animate a non-transform property, use `layout` and
let framer-motion FLIP the change.

For lists with many animated children, set `style={{ willChange: "transform, opacity" }}`
on items only while they're animating, not permanently — `willChange`
forces a compositor layer and over-using it costs memory.

### 8. App Router page transitions — minimal recipe

```tsx
// app/template.tsx
'use client';
import { motion, AnimatePresence } from "framer-motion";
import { usePathname } from "next/navigation";

export default function Template({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <AnimatePresence mode="wait" initial={false}>
      <motion.div
        key={pathname}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -8 }}
        transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
      >
        {children}
      </motion.div>
    </AnimatePresence>
  );
}
```

`template.tsx` (not `layout.tsx`) is the right file — Next remounts
templates on every navigation, which is what makes the exit animation
fire.

### 9. Accessibility — never ignore

Every animation must respect `prefers-reduced-motion`. framer-motion gives
you `useReducedMotion()`:

```tsx
const reduce = useReducedMotion();
<motion.div animate={{ y: reduce ? 0 : 16 }} />
```

Or globally cap durations to 0 with a `MotionConfig` wrapper. Bouncy
springs and large translations are the worst offenders for vestibular
sensitivity — disable them under reduced-motion, don't just shorten them.

## Verification

Before claiming a framer-motion task complete:

- [ ] Component file starts with `'use client'` if it uses motion APIs in
      App Router.
- [ ] Exit animation lives inside `<AnimatePresence>` with a stable `key`.
- [ ] Animated properties are transform / opacity (or `layout` is used).
- [ ] `useReducedMotion` is honored — no large unguarded translations.
- [ ] Transition shape matches the codebase preset (don't invent easings).
- [ ] `npm run typecheck` passes (framer-motion has strict variant types).

## Edge cases

- **Hydration mismatch** — `initial={false}` on the outermost
  `AnimatePresence` skips the SSR-vs-client first-render diff.
- **Items pop out of layout on exit** — switch `mode="wait"` →
  `mode="popLayout"`.
- **`layoutId` morph jumps** — both elements must mount within the same
  layout group, and the morph properties must be transform-compatible.
- **Drag against scroll** — set `dragDirectionLock` and constrain on the
  axis you want; otherwise touch users can't scroll past the draggable.
- **Hover stuck on touch devices** — `whileHover` fires on touch-down on
  some browsers. Pair with `whileTap` and add a media-query guard.
- **Bundle size concern** — import from `framer-motion/dom` for
  non-React-DOM use (rare); for React, the v11+ tree-shaking is good
  enough that explicit dynamic imports usually aren't needed.

## References

- Official: https://www.framer.com/motion/
- v12 (rebranded to `motion`): https://motion.dev/
- App Router patterns: see `template.tsx` recipe above.

---

### free-llm
> Route Claude Code through free or local LLMs via the free-claude-code transparent proxy on :18082. Triggers on "switch to free", "use local model", "no Anthropic key", "ollama", "deepseek", "use local llm", "free LLM". Privacy default is local-only (Ollama / LM Studio / llama.cpp); cloud free-tier (NIM / OpenRouter / DeepSeek) is opt-in. Token-savings questions stay with token-stats.

# free-llm

Wire Claude Code's outbound API calls through the `free-claude-code` proxy so the session runs on local or free-tier models instead of paid Anthropic. Default is **local-only** for privacy; cloud free-tier is opt-in.

## When to use

- User says "switch to free", "use local model", "no Anthropic key", "use local llm", "free LLM", "use ollama", "use deepseek".
- User has hit Anthropic rate limits or quota and wants to keep working.
- User wants offline / air-gapped operation.
- User explicitly opts into cloud free tier (NIM, OpenRouter, DeepSeek).

**Do NOT use for:**
- "How many tokens did I save?" → that is `token-stats`.
- "Save tokens" / "compress context" → that is `token-stats` + caveman.
- Choosing a *paid* Anthropic model — that is regular Claude Code.

## Procedure

### 0. Parse the argument

- `setup` (default if no arg) → run full install + start flow.
- `switch <model>` → re-route to a specific tier model, restart proxy.
- `back` → unset `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`, restore prior `ANTHROPIC_API_KEY`.
- `status` → curl `/health`, show current routing, exit.

### 1. Check if proxy is already running

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:18082/health
```

- `200` → proxy live; skip start (step 7). Jump to canary if `setup`/`switch`.
- non-200 / curl error → continue to install/start.

### 2. Verify `superagent-switch` CLI is available

```bash
command -v superagent-switch
```

If missing, point user to `bundles/free-claude-code/install.sh` and stop. Do not attempt manual install — installation is delegated.

### 3. Verify `free-claude-code` is installed

Check `~/.superagent/free-claude-code/.venv/bin/free-cc` exists. If not:

```
SuperAgent has not installed free-claude-code yet.
Run: bash bundles/free-claude-code/install.sh
That will: git clone repo, uv venv --python 3.14, uv sync.
```

Stop and surface this to the user. Do not pipx — package is not on PyPI.

### 4. Probe local providers (privacy default)

```bash
ollama list 2>/dev/null
curl -sf http://localhost:1234/v1/models 2>/dev/null   # LM Studio
curl -sf http://localhost:8080/v1/models 2>/dev/null   # llama.cpp server
```

Record which providers responded. If none are up, surface:

```
No local LLM provider detected. Start one of:
  - ollama serve  (then: ollama pull qwen2.5-coder:7b)
  - LM Studio (load a model, start server on :1234)
  - llama.cpp server on :8080
Or pass --cloud to opt into free cloud tier (NIM / OpenRouter / DeepSeek).
```

### 5. Show tier mapping recommendation

Default (local-only):

| Claude tier | Routed to | Provider |
|---|---|---|
| Opus | `lmstudio/unsloth/MiniMax-M2.5-GGUF` | LM Studio |
| Sonnet | `ollama/qwen2.5-coder:7b` | Ollama |
| Haiku | `ollama/qwen2.5-coder:7b` | Ollama |

Cloud opt-in (only if user passes `--cloud` or local probe failed and user confirms):

| Claude tier | Routed to | Provider |
|---|---|---|
| Opus | `nvidia_nim/qwen/qwen3.5-397b-a17b` | NVIDIA NIM |
| Sonnet | `nvidia_nim/moonshotai/kimi-k2.5` | NVIDIA NIM |
| Haiku | `open_router/stepfun/step-3.5-flash:free` | OpenRouter |

See `references/routing.md` for the complete table and fallback chains.

### 6. Write `~/.superagent/free-llm.env`

If `~/.superagent/free-llm.env` exists, back it up to `free-llm.env.bak.<timestamp>` then overwrite. Always emit BOTH variables — `free-claude-code` rejects requests missing either:

```
ANTHROPIC_BASE_URL=http://localhost:18082
ANTHROPIC_AUTH_TOKEN=freecc
SUPERAGENT_FREE_LLM_TIER=local
SUPERAGENT_FREE_LLM_OPUS=lmstudio/unsloth/MiniMax-M2.5-GGUF
SUPERAGENT_FREE_LLM_SONNET=ollama/qwen2.5-coder:7b
SUPERAGENT_FREE_LLM_HAIKU=ollama/qwen2.5-coder:7b
```

If user already has `ANTHROPIC_API_KEY` in env, write it to `~/.superagent/free-llm.env.prev` so `back` can restore it.

### 7. Start the proxy in background

```bash
superagent-switch start --port 18082 --env ~/.superagent/free-llm.env
```

Wait up to 5s, then verify:

```bash
curl -s http://localhost:18082/health
```

If port 18082 is already bound by a non-superagent process, fall back to 18083 (rewrite the env file accordingly) and emit a warning. Never silently use a different port — the user's `ANTHROPIC_BASE_URL` must match.

### 8. Run canary tool-call

Delegate to `superagent-switch`:

```bash
superagent-switch canary <opus-model> --depth=3
```

A depth-3 canary exercises a real tool-calling loop — it is the only reliable check that an open-weights model can survive Claude Code's tool-call schema. If it fails, **do not switch**. Surface the error and tell the user to either pick a different model (`switch <model>`) or stay on Anthropic.

### 9. Tell the user to restart Claude Code

```
free-llm proxy live on :18082, canary passed.
Routing: Opus→<x>  Sonnet→<y>  Haiku→<z>
RESTART your Claude Code session for ANTHROPIC_BASE_URL to take effect.
Run `free-llm back` to revert.
```

## Verification

Before declaring success, ALL of:

1. `curl -s http://localhost:18082/health` returns 200.
2. `superagent-switch canary` exited 0 with depth ≥ 3.
3. Both `ANTHROPIC_BASE_URL=http://localhost:18082` and `ANTHROPIC_AUTH_TOKEN=freecc` are present in `~/.superagent/free-llm.env`.
4. `~/.superagent/free-llm.env.prev` exists if the user previously had `ANTHROPIC_API_KEY` set.

If any check fails, do not claim the switch worked.

## Edge cases

- **Proxy already running on :18082** — reuse existing process; do not double-start. Confirm it is the SuperAgent-namespaced instance (probe `/superagent` endpoint or check pidfile at `~/.superagent/free-claude-code.pid`); if a foreign process holds the port, fall back to 18083.
- **Port collision (:18082 bound by foreign process)** — fall back to :18083, rewrite env file, log a warning. Never silently ignore.
- **Stale `~/.superagent/free-llm.env` from a previous session** — back up to `free-llm.env.bak.<unix-ts>` then overwrite.
- **Existing `ANTHROPIC_API_KEY` in user env** — back up to `~/.superagent/free-llm.env.prev` BEFORE writing the new env. `free-llm back` restores it.
- **Canary fails** — abort. Do not write env. Surface the model-id and the failing tool-call. Suggest a smaller-tier fallback from `references/routing.md`.
- **Context window truncation** — local models with smaller contexts (8k–32k) silently drop turns. Detect via canary depth-3; document in `references/troubleshooting.md`.
- **Tool-call schema mismatch** — many open-weights models malform tool-call JSON. The canary catches this. See `references/troubleshooting.md`.
- **429 from cloud free tier** — auto-fall to next provider in chain (`references/routing.md`); surface persistent 429s.
- **`back` with no prior key** — just unset `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`. Note Claude Code will fail until user supplies a key.

## References

- `references/providers.md` — provider matrix (NIM, OpenRouter, Ollama, LM Studio, llama.cpp, DeepSeek): endpoints, auth, free-tier limits, install.
- `references/routing.md` — tier → model mapping with real model IDs and fallback chains.
- `references/troubleshooting.md` — 429s, tool-call failures, port conflicts, context truncation, canary diagnostics.

---

### investigate
> Root-cause investigation. Enforces the Iron Law — no fixes without investigation first. 4 phases: Reproduce → Isolate → Explain → Verify. Upgrade over systematic-debugging when the bug is worth understanding, not just patching.

# Investigate

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Recurring bugs — same symptom, different patches.
- Any issue where "it fixed itself" was ever said.
- Flaky tests, race conditions, state corruption.
- Anywhere the fix would be guesswork without more data.

## The Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

If you don't know WHY the bug happens, your fix is guesswork. Guesswork fixes create whack-a-mole. Investigate first.

## Procedure

### Phase 1 — Reproduce

**Goal**: a deterministic command or test that triggers the bug every time.

- Write the command / test now.
- Run it 3 times. All 3 must fail the same way.
- If intermittent: loop it 100× and measure the failure rate.
- **Gate**: do not proceed until reproducible.

### Phase 2 — Isolate

**Goal**: smallest changing surface that causes the bug.

Tools:
- `git bisect` on the commit range where it started failing.
- `graphify query` or `claude-mem:smart-explore` to narrow the code surface.
- Disable features / modules one at a time until the bug disappears.

Output: the exact commit / file / line / flag that triggers the bug.

### Phase 3 — Explain

**Goal**: a paragraph that PREDICTS the fix.

- State the mechanism: "X happens, Y follows, Z breaks because W invariant was violated".
- If your explanation doesn't predict the fix, you haven't explained it yet. Iterate.
- Sanity check the explanation against the isolated surface from Phase 2.

### Phase 4 — Verify

**Goal**: fix applied, repro command now passes, regression test locked in.

- Apply the minimum fix that addresses the root cause (not a symptom patch).
- Re-run the Phase 1 repro. It must now pass.
- Add a regression test that would have caught the bug. Commit it alongside the fix.

## Output

1. Repro command (copy-paste shell line).
2. Isolated surface (commit SHA, or file:line).
3. Explanation paragraph.
4. Fix diff + regression test code.

## Verification
- Repro command exists and is deterministic.
- Explanation paragraph is present and predicts the fix.
- Regression test is named + green.
- No skipping phases — the Iron Law demands all 4.

---

### learn
> Persistent per-project learnings. Add a learning, list all learnings, or search. Backed by ~/.superagent/learnings/<project-hash>.jsonl.

# Learn

> **Ethos:** Memory compounds.

## When to use
- User says "remember that we decided X" or "learn this for next time".
- After a correction that future-you should not repeat.
- Before a retro — list learnings for review.

## Inputs
- `$ARGUMENTS` — `add "<text>"`, `list`, or `search "<query>"`.

## Procedure

Shell out to the helper:
```bash
superagent-learn $ARGUMENTS
```

## Output
- `add` → prints `recorded`.
- `list` → prints all learnings (latest first).
- `search` → prints matching lines.

## Verification
Learnings file exists at `~/.superagent/learnings/<sha256-12-of-cwd>.jsonl` after add.

---

### office-hours
> YC-style office hours intake. Six forcing product questions — customer, wedge, why-now, 10x, evidence, kill-switch. Output is a filled answer doc saved to docs/office-hours/.

# Office Hours

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Brand new feature idea, no plan yet.
- Scope feels soft / ambitious / maybe-everything.
- Before autoplan / plan-ceo-review.

## Inputs
- `$ARGUMENTS` — free-text description of the idea.

## Procedure

Answer all six verbatim. Don't skip. If you can't answer → that's the signal.

**1. Customer.** Who specifically is the customer? What is their current workaround? What pain does that workaround cost them?

**2. Narrowest wedge.** What could we ship in 48 hours that would prove the demand?

**3. Why now.** What changed recently — in tech, market, regulation, cost, behavior — that makes this viable today but not 12 months ago?

**4. 10× version.** If we weren't constrained, what's the 10× bigger version of this? Why aren't we doing that?

**5. Evidence.** What do we know (not guess) about customer willingness to pay or switch? Any live signal?

**6. Kill-switch.** What would make us stop? Name the number, the date, or the absence we'd walk away from.

## Output
Save to `docs/office-hours/<slug>.md`:
```markdown
# Office Hours: <title> (<date>)

## 1. Customer
...

## 2. Narrowest wedge
...

## 3. Why now
...

## 4. 10× version
...

## 5. Evidence
...

## 6. Kill-switch
...

## Recommendation
<Go / Not yet / Kill>
```

## Verification
All 6 questions answered (no "TBD"). Recommendation explicit.

---

### plan-ceo-review
> Pressure-test a plan with the CEO lens. Challenges scope via the four-mode framework (EXPANSION / SELECTIVE EXPANSION / HOLD / REDUCTION), rethinks the problem, asks the six forcing product questions, and recommends which mode to execute. Use before committing engineering resources.

# CEO Plan Review

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

Pressure-test a plan through the CEO lens before a single engineer-hour is spent. Rethink the problem, challenge the scope, rate the opportunity, and recommend which scope variant to actually execute. You are not here to rubber-stamp. You are here to make the plan extraordinary — or to kill it.

See `~/.superagent/ETHOS.md` for shared SuperAgent principles (verify or die, rewind don't correct, memory compounds, leverage over toil, local first). This skill assumes those are in effect.

## When to use

- Before committing engineering resources to a plan, spec, or PRD.
- When the user has a draft plan (`plan.md`, a design doc, a pasted outline) and wants a CEO-mindset pressure test, not a code review.
- When scope feels ambiguous — it may be too small, too big, or aimed at the wrong outcome.
- When the team is about to start building but nobody has asked "is this the right thing to build?"
- After `/brainstorm` or an office-hours session, as a last-mile gate before `/plan-eng-review`.

Do NOT use this skill for:

- Pure code review (use `superpowers:requesting-code-review`).
- Implementation execution (use `superpowers:executing-plans`).
- Bug triage (this is for forward-looking plans, not incident response).

## Inputs

Accepts either:

- **Inline plan text** — paste the plan body into the invocation.
- **Path to a plan file** — e.g. `plan.md`, `docs/designs/<feature>.md`, or any markdown/text file.

If no input is supplied, ask the user to paste the plan or provide a path before proceeding. Do not attempt to review a plan you have not read.

Before starting Step 0, read the plan end-to-end. Take no shortcuts — the whole point of this skill is rigor.

## Procedure

### Step 0: Scope Mode Selection

State the four modes to the user verbatim and ask which applies. Do not proceed until the user picks one (or you pick the default with explicit justification).

**SCOPE EXPANSION** — You are building a cathedral. Envision the platonic ideal. Push scope UP. Ask "what would make this 10x better for 2x the effort?" You have permission to dream — and to recommend enthusiastically. But every expansion is the user's decision. Present each scope-expanding idea as an AskUserQuestion. The user opts in or out.

**SELECTIVE EXPANSION** — You are a rigorous reviewer who also has taste. Hold the current scope as your baseline — make it bulletproof. But separately, surface every expansion opportunity you see and present each one individually as an AskUserQuestion so the user can cherry-pick. Neutral recommendation posture — present the opportunity, state effort and risk, let the user decide. Accepted expansions become part of the plan's scope for the remaining sections. Rejected ones go to "NOT in scope."

**HOLD SCOPE** — You are a rigorous reviewer. The plan's scope is accepted. Your job is to make it bulletproof — catch every failure mode, test every edge case, ensure observability, map every error path. Do not silently reduce OR expand.

**SCOPE REDUCTION** — You are a surgeon. Find the minimum viable version that achieves the core outcome. Cut everything else. Be ruthless.

**Critical rule.** In all modes, the user is 100% in control. Every scope change is an explicit opt-in — never silently add or remove scope. Once the user selects a mode, COMMIT to it. Do not silently drift toward a different mode. If EXPANSION is selected, do not argue for less work later. If SELECTIVE EXPANSION is selected, surface expansions as individual decisions. If REDUCTION is selected, do not sneak scope back in. Raise concerns once here — after that, execute the chosen mode faithfully.

**Context-dependent defaults** (use when the user is uncertain):

- Greenfield feature → default SCOPE EXPANSION.
- Feature enhancement or iteration on an existing system → default SELECTIVE EXPANSION.
- Bug fix or hotfix → default HOLD SCOPE.
- Refactor → default HOLD SCOPE.
- Plan touching >15 files → suggest SCOPE REDUCTION unless user pushes back.
- User says "go big" / "ambitious" / "cathedral" → SCOPE EXPANSION, no question.
- User says "hold scope but tempt me" / "show me options" / "cherry-pick" → SELECTIVE EXPANSION, no question.

**Default if still uncertain:** SELECTIVE EXPANSION. It is the lowest-regret posture — you get rigor on the baseline plus cherry-pickable upside.

### Step 1: Six Forcing Questions

Answer all six in the output. Every one. No skipping, no merging, no "covered above." Each answer is a short paragraph (2–5 sentences) with concrete specifics — no platitudes, no "it depends."

**a. Who is the customer and what is their current workaround?**
Name a person, role, or tight ICP segment. Describe what they do today instead of using this — spreadsheet, manual process, competing tool, nothing. If you can't name the workaround, you don't understand the customer.

**b. What is the narrowest wedge we could ship in 48 hours?**
The smallest slice that a real user would pay for, switch to, or measurably benefit from. Not an MVP — a wedge. One surface, one workflow, one outcome. If the plan as written can't be compressed into 48 hours of work, describe the narrowest subset that can.

**c. Why now? What changed that makes this viable?**
Technology shift, market shift, cost curve, regulatory change, distribution unlock, user-behavior change. If "why now" is "because we thought of it," the plan has no timing moat. Say so.

**d. What is the 10× version of this, and why aren't we doing that?**
Describe the version that is 10× more ambitious and delivers 10× more value for 2× the effort. Then answer the second half honestly: risk, capacity, sequencing, or lack of conviction. Name the reason. "Scope" is not a reason — it is a decision.

**e. What evidence do we have that the customer will pay / switch?**
Signals: prior user interviews, waitlist signups, paid pilots, observed workarounds they already hack together, churn from a competitor. Rank the evidence honestly — conviction-from-a-hunch is not evidence. If evidence is thin, flag it and recommend a cheap validation before building.

**f. What's the kill-switch — what would make us stop?**
A specific, pre-committed tripwire: "if after 30 days of pilot we have <N active users / <M% retention / <X revenue, we kill this." If you cannot name the kill-switch, you will never stop, and sunk-cost will compound. Every plan needs one.

### Step 2: Rating Rubric

Fill every row. Score each dimension 0–10 with a single-sentence justification. Be harsh — a default-6 grade inflation makes this worthless. If a row is a 3, write 3 and explain.

| Dimension         | Score (0–10) | Why (one sentence) |
|-------------------|--------------|--------------------|
| Customer demand   |              |                    |
| Status-quo gap    |              |                    |
| Wedge narrowness  |              |                    |
| ICP fit           |              |                    |
| Moat potential    |              |                    |
| Timing            |              |                    |

Rubric glossary:

- **Customer demand** — How strong is the pull? Are customers asking for this, or are we pushing it at them?
- **Status-quo gap** — How painful is the current workaround? Is the gap a splinter or a broken leg?
- **Wedge narrowness** — Is there a clean, small, shippable wedge, or is the plan a 10-surface mega-launch?
- **ICP fit** — Does the target customer actually match the team's distribution, positioning, and existing relationships?
- **Moat potential** — If we win this wedge, does it compound — data, network, switching costs, brand — or is it a feature a competitor copies in a weekend?
- **Timing** — Why now vs. 2 years ago vs. 2 years from now?

Sum the score at the bottom: `Total: X/60`. Anything below 30 should trigger a hard reconsider — say so explicitly.

### Step 3: Three Scope Variants

Propose three scope variants. Each gets at least one paragraph (3–6 sentences). Be concrete — describe surfaces, features, and user workflows, not abstractions.

**(a) Narrowest wedge.** The 48-hour version from Step 1b. What ships, what is cut, which single user benefits, which single metric moves. Include effort estimate (human days vs. Claude Code hours — the implementation speed delta is 10–20×; present both scales).

**(b) Plan as given.** The plan as the user wrote it, faithfully summarized. Flag any internal contradictions or scope creep already baked in. Include effort estimate.

**(c) 10× version.** The ambitious version from Step 1d. What would make this a category-defining move rather than a feature? Include effort estimate, and explicitly name the risk(s) that make this scary.

### Step 4: Recommendation

State explicitly which variant to execute: **(a) narrowest wedge**, **(b) plan as given**, or **(c) 10× version**. No hedging, no "it depends."

Give the reasoning in 2 sentences. The first sentence names the decisive factor (evidence strength, timing, team capacity, kill-switch credibility, moat shape). The second sentence names the principal risk of the chosen variant and how to mitigate it in the first week of execution.

If the recommendation differs from the selected scope mode in Step 0, flag the mismatch and ask the user whether to revise the mode or override the recommendation.

## Output

The user should see, in order:

1. **Mode selected** — one of the four, with a one-line justification.
2. **Six forcing questions** — each answered in its own labeled paragraph (a–f).
3. **Rating rubric** — full table filled, total score at the bottom.
4. **Three scope variants** — (a), (b), (c), each with ≥1 paragraph and an effort estimate.
5. **Recommendation** — one variant named explicitly, 2-sentence reasoning, principal risk + week-1 mitigation.
6. **Next steps** — one-line pointer to `/plan-eng-review` (or equivalent) if the user approves the recommendation, or to a cheap validation experiment if evidence is thin.

Format as a single markdown document the user can save alongside the plan.

## Verification

Before declaring done, the output MUST include:

- [ ] All 4 scope modes named in Step 0 (SCOPE EXPANSION, SELECTIVE EXPANSION, HOLD SCOPE, SCOPE REDUCTION).
- [ ] All 6 forcing questions answered (a–f), each with a substantive paragraph — not a single sentence.
- [ ] Full rubric filled — every row has a 0–10 score and a justification, total computed.
- [ ] 3 scope variants, each with at least one paragraph and an effort estimate.
- [ ] Explicit recommendation — one of (a), (b), (c), stated by name.
- [ ] Kill-switch named (question f) with a specific, pre-committed tripwire.

If any item is missing, the review is incomplete. Do NOT declare done. Fill the gap and re-check the list.

Remember the ethos: verify or die. A plan review that skipped the rubric is not a plan review — it's an opinion.

---

### plan-design-review
> Designer's pressure-test — rate 10 design dimensions 0–10, identify fixes for anything under 7, propose top-3 highest-leverage changes. Iterative: rate → gap → fix → re-rate.

# Design Plan Review

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Before shipping any frontend change.
- When a design feels "off" but can't name why.
- When ui-ux-pro-max output needs critique before implementation.

## Inputs
- `$ARGUMENTS` — screenshot path, live URL, or plain-text description.

## The 0-10 Rating Method

For each dimension: **Rate 0-10. If not 10, state what a 10 would look like, then do the work.** Iterate: rate → gap → fix → re-rate until the user says stop or it's a 10.

## Procedure

### Step 1: Rate all 10 dimensions

| Dimension | Score | What a 10 looks like |
|---|---|---|
| Visual hierarchy | /10 | Eye knows where to go first in <1s |
| Rhythm & spacing | /10 | Vertical rhythm consistent, 8pt grid respected |
| Color | /10 | Palette cohesive, contrast ratios ≥4.5 |
| Typography | /10 | ≤2 families, scale clear, line-height correct |
| Density | /10 | Information-per-pixel tuned to use case |
| Motion | /10 | Purposeful, <300ms, eased, respects reduced-motion |
| Accessibility | /10 | Keyboard nav, aria labels, contrast, focus rings |
| Consistency | /10 | Patterns reused, no one-off components |
| Delight | /10 | 1+ micro-moment that earns a smile |
| Responsiveness | /10 | Breaks at no viewport; touch targets ≥44px |

### Step 2: Identify gaps
For every dimension under 7, write a one-line concrete fix referencing a named pattern (e.g. "use `ui-ux-pro-max` bento-grid with shadcn Card").

### Step 3: Top 3 highest-leverage fixes
Pick the 3 fixes that if applied would lift the most dimensions at once.

### Step 4: Revised design brief
One paragraph describing the revised design that would hit all 10/10.

### Step 5: Iterate
Ask: "Shall I regenerate the mockup with these fixes?" If yes → loop to Step 1.

## Output
- Filled rating table
- Prioritized fix list
- Top-3 leverage fixes
- Revised brief

## Verification
- All 10 dimensions scored.
- ≥3 fixes cited for any dim <7.
- Explicit top-3 named.

---

### plan-eng-review
> Eng-manager pressure-test of a plan. Locks architecture, data flow, edge cases, test coverage, failure modes, migration safety. Use after plan-ceo-review and before execution.

# Eng Plan Review

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- After product/scope is locked (post plan-ceo-review).
- Before any implementation code is written.
- When a plan feels hand-wavy on how it actually works.

## Inputs
- `$ARGUMENTS` — plan text or path to plan markdown.

## Procedure

### 1. Architecture fit
- Does this fit existing patterns in the codebase? Use `graphify query` or `claude-mem:smart-explore` to verify.
- What gets reused vs built new? List both.
- Any dependency on unstable / deprecated APIs?

### 2. Data flow diagram
Describe the end-to-end path in text. Example: `User click → POST /api/x → validate → DB write → return 201 → re-fetch`.

### 3. Edge case table
| What if | Handling |
|---|---|
| Network dies mid-operation | |
| DB write succeeds but response lost | |
| Concurrent writers | |
| Auth expires mid-flow | |
| Input at limit / beyond limit | |
| Empty / null / NaN input | |
| Malformed / hostile input | |

### 4. Test coverage map
For each new behavior, name the test that proves it. No test name → gap.

### 5. Failure modes
List 3+: what breaks, how we detect, how we recover.

### 6. Migration safety
If schema/API changes: is it reversible? Is there a rollback? Any risk to running traffic?

## Output
Filled-in versions of the 6 sections above, as a markdown doc.

## Verification
- Edge case table has ≥6 rows filled.
- Every new behavior in the plan has a named test.
- Failure modes section has ≥3 entries.
- Migration safety section is explicit (not "N/A" unless truly N/A).

---

### review
> Pre-merge diff review gate. 6-point checklist covers scope drift, implementation fidelity, tests, migrations, TODOs, docs. Flags SQL safety / trust boundary / side-effect bugs. Rates LGTM / Needs Changes / Block.

# Review

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Before merging a PR.
- After `/ship` rebases and before it pushes.
- When a plan claims done and you want a second opinion.

## Inputs
- `$ARGUMENTS` — optional base branch name (default: `main`).

## The 6-Point Checklist

For each bullet, produce explicit findings with file:line references.

### 1. Scope Drift
- Compare diff against the plan. Anything here NOT in the plan?
- Anything in the plan NOT in the diff?

### 2. Implementation Fidelity
- Does each change match its spec?
- Any naming, signature, or behavior divergence?
- **SQL safety**: parameterized? Any string concat in queries?
- **LLM trust boundary**: any LLM output fed directly to `eval`, shell, or DB?
- **Conditional side effects**: branches that mutate shared state?

### 3. Tests
- New behavior → new test? Named + green?
- Test hits real db / integration, not just mock when required?
- Coverage of the edge-case table from plan-eng-review?

### 4. Migrations
- Reversible?
- Safe under concurrent writes / reads?
- Data loss risk?

### 5. TODOs Cross-Ref
- Any new TODO without owner / issue link?
- Any removed TODO that was actually completed (good) vs deferred (flag)?

### 6. Docs Staleness
- README / CHANGELOG / CLAUDE.md updated where touched code is documented?
- API docs regenerated if public surface changed?

## Output

Produce markdown report:
```
## Review verdict: LGTM | Needs Changes | BLOCK

### Findings

#### Critical
- <finding> @ file.ts:42

#### Important
- <finding> @ file.ts:78

#### Minor
- <finding> @ file.ts:100

### Fix-First pipeline
- FIXABLE: <list> — suggest calling `/investigate` or fixing inline
- INVESTIGATE: <list> — root cause unclear, escalate
```

## Verification
- Every finding has a file:line reference.
- Verdict is one of the three explicit values.
- Fix-First pipeline section present.

---

### ship
> Full ship pipeline — detect platform, rebase on base, run tests, audit coverage + scope drift, pre-landing review, bump version, update CHANGELOG, commit in bisectable chunks, verification gate, push, open PR. Refuses to ship main/master.

# Ship

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Feature branch is complete.
- Tests are green locally.
- You want one command to take it from "done locally" to "PR open + verified".

## Pre-flight refusals
- Refuse if current branch is `main` or `master`.
- Refuse if `git status` shows uncommitted changes that aren't part of this ship.
- Refuse if no test command can be detected.

## The 20 Steps

### 1. Detect platform
- Read `package.json`, `pyproject.toml`, `Cargo.toml`, or `Makefile` to decide test command.
- Priority order:
  - `package.json` → `npm test` / `pnpm test` / `bun test` (honor the `scripts.test` field).
  - `pyproject.toml` → `pytest` (or the configured `[tool.pytest.ini_options]` runner).
  - `Cargo.toml` → `cargo test`.
  - `Makefile` with a `test` target → `make test`.
- If ambiguous: ask user which command to run; remember the answer in `~/.superagent/ship/test-cmd.<project-hash>`.

### 2. Pre-flight check
- Run `bin/superagent-ship` (the helper) — it refuses to ship main and does the rebase.
- Confirm current branch is not main/master.
- Confirm no uncommitted changes outside the ship scope (`git status --porcelain` must be clean, or only contain files the ship intends to commit).

### 3. Rebase on base branch
- Via the helper: `git fetch origin && git rebase origin/<base>`.
- Default `<base>` is `main`; honor `$ARGUMENTS` if the user passed a base branch.
- Abort ship if rebase has conflicts — user must resolve first.
- Never run `git rebase --abort` silently; surface the conflict and stop.

### 4. Run tests
- Execute the test command detected in step 1.
- Capture stdout/stderr + duration; store summary for step 15.
- Abort ship if tests fail. Do not "fix and retry" silently — surface failure, let user triage.

### 5. Coverage audit
- If the project has a coverage tool (`jest --coverage`, `pytest --cov`, `cargo tarpaulin`, etc.): run it, record baseline + new number.
- Compare against the last stored coverage in `~/.superagent/ship/coverage.<project-hash>.json`.
- If coverage dropped >5% — flag to user, ask to proceed or abort.
- Update stored coverage on successful ship.

### 6. Plan completion audit
- If a plan file exists at `docs/plans/<slug>.md` (or `$ARGUMENTS` referenced a plan): read it.
- Check that every `- [ ]` task is now `- [x]`.
- If not all checked: list incomplete tasks, abort ship. User can either complete them or explicitly override.

### 7. Scope drift detection
- Run `git diff origin/<base>...HEAD --stat` — list files changed.
- Cross-reference against the plan's stated scope (the "Files touched" section, if present).
- If any files are outside scope: surface to user, show the drift, ask to confirm or abort.

### 8. Pre-landing review
- Invoke the `review` skill on the diff (`git diff origin/<base>...HEAD`).
- Parse the verdict:
  - `BLOCK`: abort ship, surface findings.
  - `Needs Changes`: surface findings, ask user to proceed anyway or fix first.
  - `LGTM` / `Approve`: continue.

### 9. Version bump
- Read current version from `package.json` / `pyproject.toml` / `Cargo.toml` / `VERSION` (first one found).
- Default: patch bump.
- If `$ARGUMENTS` contains `minor` or `major`: bump accordingly.
- Write the new version back to the same file. Keep formatting stable (don't rewrite the whole file).

### 10. CHANGELOG update
- Prepend a new section at the top of `CHANGELOG.md`: `## vX.Y.Z — <today>` (ISO date).
- Auto-generate bullets from commit messages since the merge base with `<base>`.
- Group by Conventional Commit type:
  - `feat:` → Added
  - `refactor:` / `perf:` / `style:` → Changed
  - `fix:` → Fixed
  - `revert:` / deletion commits → Removed
- Preserve the rest of the file verbatim below the new section.

### 11. Commit in bisectable chunks
- Group staged-but-uncommitted work by logical file-group (one concern per commit).
- For each group: `git add <files> && git commit -m "<caveman-commit-style message>"`.
- Invoke `caveman:caveman-commit` for message generation if available. Otherwise fall back to a short imperative subject ≤50 chars.
- Discipline: if one of these commits breaks the build, `git bisect` should surface exactly that one. Do not mash unrelated changes into a single "misc" commit.

### 12. Verification gate
- Re-run the test command from step 1 on the rebased HEAD. This catches the case where rebase merged cleanly but semantically broke something.
- Run `graphify update` if `graph.json` exists at the repo root (keeps knowledge graph fresh for downstream sessions).
- Invoke the `verification-before-completion` skill (superpowers:verification-before-completion). Require evidence of green tests before continuing.
- If verification fails: abort ship, do not push.

### 13. Push
- `git push -u origin <current-branch>`.
- If push fails (non-fast-forward, auth, hook rejection): surface remote error verbatim, do not retry with `--force`.
- If remote branch already exists and diverged from local: stop and ask the user — never force-push silently.

### 14. Open PR
- `gh pr create --base <base> --title "<caveman-style title>" --body "<body template below>"`.
- Title: use `caveman:caveman-commit` logic (≤70 chars, imperative).
- Capture the PR URL from `gh` output.

### 15. Ship metrics
- Append one JSON line to `~/.superagent/cost/ship.jsonl`:
  ```json
  {"ts":"<iso-8601>","branch":"<name>","base":"<base>","files_changed":<n>,"test_duration_s":<n>,"coverage_delta":<n>,"pr_url":"<url>","version":"<x.y.z>"}
  ```
- Create `~/.superagent/cost/` if it doesn't exist.

### 16. Status + summary
Print to user:

```
SHIPPED
Branch: <b>
Version: <v>
PR: <url>
Tests: <n>/<n> pass
Coverage: <pct> (<delta>)
Files: <n> changed
```

## PR body template

```markdown
## Summary
- <bullet 1>
- <bullet 2>

## Test plan
- [x] <test you ran>
- [x] Tests pass locally
- [x] Rebased on latest <base>

## Linked plan
[<slug>](docs/plans/<slug>.md)
```

## Output
- Committed chain of bisectable commits on the feature branch.
- Updated `CHANGELOG.md` + bumped version file.
- Open PR URL printed to stdout.
- One-line entry in `~/.superagent/cost/ship.jsonl`.

## Verification
- PR URL printed (not empty).
- All tests green on the rebased HEAD (verified in step 12, not just step 4).
- CHANGELOG entry present for the bumped version.
- No commits directly to `main` or `master`.
- `git log --oneline origin/<base>..HEAD` shows the bisectable chain — each commit scoped to one concern.

## Abort conditions — summary
Ship refuses (or aborts mid-flight) when any of the following hold:

1. Current branch is `main` / `master`.
2. No test command can be detected and user declines to specify one.
3. Rebase produces conflicts.
4. Tests fail (step 4 or step 12).
5. Coverage drops >5% and user declines to proceed.
6. Plan has unchecked tasks and user declines to override.
7. Review skill returns `BLOCK`.
8. Push fails with non-fast-forward (no silent force-push).
9. `verification-before-completion` refuses to confirm.

In every abort case: leave the repo in a clean state (no half-written CHANGELOG, no partial commits of ship machinery), surface the exact reason, and exit non-zero.

---

### superagent
> Master entrypoint. Takes a task, classifies it, composes a skill chain, announces the plan, executes. Use whenever the user types /superagent <task> or says "use superagent for X".

# SuperAgent Router

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- User invokes `/superagent <task>`.
- User says "superagent this", "full power mode", "activate all agents".
- Any complex task where you're unsure which skills to chain.

## Procedure

**1. Load context (always).** Run once per session only:
```bash
mempalace wake-up 2>/dev/null | head -60 || true
```

**2. Classify.** Run the classifier on `$ARGUMENTS`:
```bash
superagent-classify "$ARGUMENTS"
```
The output is JSON `{chain: [...], hint: [...|null]}`. `chain` is the proposed sequence. `hint` is a prior successful chain for similar tasks — use as a tiebreaker.

**3. Announce.** Print to the user:
```
SuperAgent routing plan for: "<task>"
Chain: skill1 → skill2 → skill3
Rationale: <one line why each skill was selected>
Estimated effort: <rough>
Proceed? (yes / edit / skip N / run-only N)
```

**4. Confirm.** Wait for user reply unless the task is trivially small (single-skill chain) — then proceed.

**5. Execute.** For each skill in the chain, invoke via the Skill tool in order. Between skills, summarize the artifact produced in one sentence. If a skill fails or user says "stop", halt and report.

**6. Log.** After completion (or halt), append to `~/.superagent/brain/routes.jsonl`:
```json
{"ts": "<iso>", "task_hash": "<sha256-12>", "task": "<first 120 chars>", "chain": [...], "outcome": "done|halt|fail", "user_override": "yes|no"}
```

## Fallback — classifier uncertain
If the chain contains only `mempalace-wake` (no rule matched), show the top-3 candidate single skills based on description-keyword overlap and ask the user to pick.

## What stays manual
- Plan Mode (Shift+Tab twice) — user's call.
- Rewind (Esc Esc) — user's call.
- Permission grants — `/permissions`.

## Verification
After each skill runs, require the skill's own output. For build/fix chains, the final `verification-before-completion` must pass before declaring done.

---

### superagent-switch
> Drive the `superagent-switch` CLI to inspect, swap, or restore the active LLM backend. Triggers on "list local models", "switch to <model>", "switch back", "restore anthropic", "canary <model>", "what model am i on", "auto fallback on/off", "/superagent-switch <op>". Use when the user wants direct, surgical control over the model swap — not when they're asking *whether* to switch (that is `auto-fallback`) or *how to set up* the proxy (that is `free-llm`).

# superagent-switch

Surgical operator for the cost-aware proxy / model switcher. Wraps the
`superagent-switch` CLI in a thin, deterministic skill so the agent always
runs the *right* subcommand, parses output the same way, and reports state
back to the user in a consistent shape.

## When to use

- User typed `/superagent-switch <op>` (one of: `list`, `to`, `back`,
  `canary`, `status`, `auto`).
- User said "list local models", "switch to qwen3", "switch back to
  Anthropic", "what backend am I on", "run a canary on …", "turn auto-fallback
  on/off".
- A peer skill (`auto-fallback`, `free-llm`) needs to perform the actual
  switch — it dispatches here.

**Do NOT use for:**
- Deciding *whether* to switch — that is `auto-fallback`.
- First-time proxy install / setup — that is `free-llm`.
- Token-savings questions — that is `token-stats`.

## Subcommand routing

| Op                          | What it does                                            | When |
| --------------------------- | ------------------------------------------------------- | ---- |
| `list`                      | Enumerate detected local models (Ollama / LM Studio / llama.cpp). Always safe; no state change. | First call when the user asks "what's available" or before `to`. |
| `to <model>`                | Set `ANTHROPIC_BASE_URL` → `http://localhost:18082`, set token, route Claude Code through the free-claude-code proxy with the given local model. | After `canary` passes, or when user explicitly demands the swap. |
| `back`                      | Unset proxy env, restore the prior `ANTHROPIC_API_KEY`. | User says "switch back", "restore anthropic", "kill local". |
| `canary <model> --depth=N`  | Run an N-step Read → Edit → Bash sanity probe against the model. Default N=3. | Always before `to <model>` unless user explicitly skips. |
| `status`                    | Show current backend, model, auto-flag, last canary. No state change. | Health check, "what am I on". |
| `auto on` / `auto off`      | Toggle `~/.superagent/auto-fallback.flag`.              | User says "turn auto on/off". |
| `help`                      | Print CLI help.                                         | Unknown op. |

## Procedure

### 0. Parse the argument

If invoked via `/superagent-switch <args>`, the first token is the
subcommand. Default to `status` if no subcommand is given (safest read-only
op). If `args` look like a bare model name (e.g. `qwen2.5-coder:7b`), treat
as `to <model>` and **require** a `canary` first — never bypass the canary
unless the user explicitly types `--no-canary`.

### 1. Verify the CLI exists

```bash
command -v superagent-switch
```

If missing, point user to `bundles/free-claude-code/install.sh` and stop.
Do not attempt to install via `npm` / `pip` / `brew` directly.

### 2. Run the subcommand

| User intent                                      | Exact command                                  |
| ------------------------------------------------ | ---------------------------------------------- |
| "what's available"                               | `superagent-switch list`                       |
| "what am I on right now"                         | `superagent-switch status`                     |
| "switch to qwen3-coder:next" (first time)        | `superagent-switch canary qwen3-coder:next --depth=3` then on pass `superagent-switch to qwen3-coder:next` |
| "switch back to anthropic"                       | `superagent-switch back`                       |
| "test if qwen2.5 works without switching"        | `superagent-switch canary qwen2.5-coder:7b --depth=3` |
| "auto-fallback on" / "off"                       | `superagent-switch auto on` / `auto off`       |

### 3. Report the result back

After every op, print **three lines** to the user:

1. **What ran** — exact CLI command.
2. **What changed** — diff of state (backend / model / auto-flag).
3. **What's next** — restart Claude Code if the backend flipped, or "no
   action required" if it was a read-only op.

Example after a successful `to qwen3-coder:next`:

```
ran:    superagent-switch to qwen3-coder:next
state:  backend Anthropic → free-claude-code (localhost:18082) · model → qwen3-coder:next
next:   restart Claude Code so the new env is picked up
```

### 4. Failure handling

- **Canary fails** → DO NOT call `to`. Surface the canary log verbatim and
  ask the user: try a different model, wait, or stay on Anthropic.
- **`to` fails** (proxy down, port conflict) → run `superagent-switch
  status` to confirm current state, then prompt to run `free-llm setup`.
- **`back` fails** (env restore broken) → tell the user to manually
  `unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN` and restart their shell;
  do not silently retry.

### 5. Never

- Run `to <model>` without a passing canary (unless `--no-canary`).
- Edit `~/.superagent/state.json` by hand — always go through the CLI.
- Touch anything in `~/.claude/` — switcher state lives in `~/.superagent/`.
- Skip restart instructions after a backend flip.

## Verification

After the op, the skill is done iff:

- [ ] CLI exited 0.
- [ ] If state changed: `superagent-switch status` confirms the new state.
- [ ] User has been told whether they need to restart Claude Code.

## Slash command

A Claude Code slash command at `commands/superagent-switch.md` invokes this
skill with `$ARGUMENTS` so users can type:

```
/superagent-switch list
/superagent-switch to qwen3-coder:next
/superagent-switch back
/superagent-switch canary qwen2.5-coder:7b
/superagent-switch status
/superagent-switch auto on
```

---

### token-stats
> Show superagent token savings stats for the current project — lifetime totals, last 5 sessions, compression ratio. Also emits a pastable GitHub badge for sharing. Use when user asks about token savings, how many tokens saved, superagent stats, runs /token-stats, or asks for a savings badge.

# SuperAgent Token Stats

Show token savings for the current project. Supports a `--badge` mode that emits a shareable markdown badge for the user's own README.

## Steps

1. Check flags passed in arguments:
   - `--test` → skip to **Test Mode** below.
   - `--badge` → skip to **Badge Mode** below.

2. Default mode — run this command and display the output:

```bash
bash -c '
STATS="$HOME/.claude/superagent-stats.json"
PROJECT="$PWD"

if [[ ! -f "$STATS" ]]; then
  echo "No stats found. Run: graphify update <your-project-dir>"
  exit 0
fi

PROJECT_DATA=$(jq --arg p "$PROJECT" ".projects[\$p] // empty" "$STATS" 2>/dev/null)

if [[ -z "$PROJECT_DATA" ]]; then
  echo "No stats for: $PROJECT"
  echo "Run: graphify update $PROJECT"
  exit 0
fi

RATIO=$(echo "$PROJECT_DATA"  | jq -r ".compression_ratio // 0")
CAL_DATE=$(echo "$PROJECT_DATA" | jq -r ".calibrated_at // \"never\"")
GQ=$(echo "$PROJECT_DATA"  | jq -r ".lifetime.graphify_queries // 0")
GS=$(echo "$PROJECT_DATA"  | jq -r ".lifetime.graphify_tokens_saved // 0")
MH=$(echo "$PROJECT_DATA"  | jq -r ".lifetime.mempalace_hits // 0")
MS=$(echo "$PROJECT_DATA"  | jq -r ".lifetime.mempalace_tokens_saved // 0")
TOT=$(echo "$PROJECT_DATA" | jq -r ".lifetime.total_saved // 0")

fmt() {
  local n=$1
  if   [[ "$n" -ge 1000000 ]]; then echo "$(echo "scale=1; $n/1000000" | bc)M"
  elif [[ "$n" -ge 1000 ]];    then echo "$(echo "scale=0; $n/1000" | bc)k"
  else echo "$n"; fi
}

echo ""
echo "SuperAgent Token Stats — $PROJECT"
echo "──────────────────────────────────────────────"
printf "Compression ratio : %sx  (your codebase, measured %s)\n" "$RATIO" "$CAL_DATE"
echo "──────────────────────────────────────────────"
echo "Lifetime"
printf "  Graphify queries  : %s\n" "$GQ"
printf "    → %s tokens saved\n" "$(fmt $GS)"
printf "  Mempalace hits    : %s\n" "$MH"
printf "    → ~%s tokens saved (estimate)\n" "$(fmt $MS)"
printf "  Total saved       : ~%s tokens\n" "$(fmt $TOT)"
echo ""
echo "Last 5 sessions"
printf "  %-12s  %-10s  %-10s  %s\n" "Date" "Graphify" "Mempalace" "Saved"
echo "$PROJECT_DATA" | jq -r "
  .sessions[:5][] |
  [.date, (.graphify_queries|tostring), (.mempalace_hits|tostring), (.saved|tostring)] |
  @tsv" | while IFS=$'"'"'\t'"'"' read -r d g m s; do
    printf "  %-12s  %-10s  %-10s  ~%s\n" "$d" "$g" "$m" "$s"
  done
echo "──────────────────────────────────────────────"
echo "Tip: re-run graphify update <dir> after large codebase changes."
echo ""
'
```

## Cost report

Also run and include dollar-cost breakdown:

```bash
superagent-cost today
superagent-cost week
```

Shows cost grouped by model (opus / sonnet / haiku) and a model-mix coach note.

## Badge Mode

When `--badge` is passed, emit a pastable markdown badge that the user can drop into their own README to showcase their savings. Run:

```bash
bash -c '
STATS="$HOME/.claude/superagent-stats.json"
PROJECT="$PWD"
REPO_URL="https://github.com/animeshbasak/SuperAgent"

if [[ ! -f "$STATS" ]]; then
  TOT=0
else
  TOT=$(jq --arg p "$PROJECT" ".projects[\$p].lifetime.total_saved // 0" "$STATS" 2>/dev/null)
fi

if   [[ "$TOT" -ge 1000000 ]]; then LABEL="$(echo "scale=1; $TOT/1000000" | bc)M_tokens_saved"
elif [[ "$TOT" -ge 1000 ]];    then LABEL="$(echo "scale=0; $TOT/1000" | bc)k_tokens_saved"
else                                LABEL="${TOT}_tokens_saved"
fi

URL="https://img.shields.io/badge/SuperAgent-${LABEL}-brightgreen?style=flat-square"
MARKDOWN="[![SuperAgent: ${LABEL//_/ }](${URL})](${REPO_URL})"

echo ""
echo "Paste this into your README to show off your savings:"
echo ""
echo "$MARKDOWN"
echo ""
echo "Preview:"
echo "  $URL"
echo ""
'
```

After displaying, remind the user: "Drop that one line in your README. Every visitor sees your receipt — and a link back to SuperAgent. That's how we grow."

## Test Mode

When `--test` argument is passed, display this hardcoded sample output:

```
SuperAgent Token Stats — /your/project (SAMPLE DATA)
──────────────────────────────────────────────
Compression ratio : 48.3x  (your codebase, measured 2026-04-17)
──────────────────────────────────────────────
Lifetime
  Graphify queries  : 47
    → 198k tokens saved
  Mempalace hits    : 23
    → ~31k tokens saved (estimate)
  Total saved       : ~229k tokens

Last 5 sessions
  Date          Graphify    Mempalace   Saved
  2026-04-17    12          4           ~58k
  2026-04-16    8           2           ~38k
  2026-04-15    15          6           ~71k
  2026-04-14    5           3           ~22k
  2026-04-13    7           8           ~40k
──────────────────────────────────────────────
Tip: re-run graphify update <dir> after large codebase changes.
```

---

### video-craft
# Video Craft — HTML Compositions to MP4 via hyperframes

This skill teaches the agent to author hyperframes compositions (HTML + GSAP +
`data-*` timing attributes) and render them deterministically to MP4. The render
pipeline is seek-driven and frame-accurate — preview ≠ render performance, but
preview === render visual output. Treat the composition as the single source of
truth; never try to play media or hide clips in scripts.

---

## When to use

- User asks for a video, MP4, or rendered motion file (any aspect ratio).
- User wants a product ad, explainer, lower-third overlay, animated chart, logo
  sting, social cut, kinetic typography piece, or data-viz video.
- User has assets (images, video, audio, copy, data) and the deliverable is
  "ship me a video file".
- User mentions hyperframes, GSAP timeline, deterministic render, frame
  capture, or composition-to-MP4 pipeline.

**Do NOT use for:** live web pages with scroll animation (use `webgl-craft`),
realtime UI prototypes, or interactive motion. video-craft renders are
non-interactive video files.

---

## Procedure

### 1. Preflight (REQUIRED — never skip)

Both checks must pass before any author/render step. If either fails, stop and
direct the user to install before proceeding.

```bash
# Check hyperframes CLI
hyperframes --version || npx hyperframes --version

# Check FFmpeg (hard dependency — no MP4 without it)
ffmpeg -version | head -1
```

If `hyperframes` is missing:
```bash
npm i -g hyperframes
# or run the bundled installer:
bash bundles/hyperframes/install.sh
```

If `ffmpeg` is missing:
- macOS: `brew install ffmpeg`
- Ubuntu/Debian: `sudo apt install -y ffmpeg`
- Windows: `winget install ffmpeg`

Then run the deeper diagnostic:
```bash
npx hyperframes doctor
```
Expected: green checks for Node 22+, FFmpeg, FFprobe, Chrome.

### 2. Pick the entrypoint

Two paths:

**A. Recipe-first (recommended).** If the user's intent matches a recipe in
`recipes/`, copy it as the starting composition and edit. Recipes:

| Recipe                       | Use when                                                |
| ---------------------------- | ------------------------------------------------------- |
| `hello-world.html`           | Smallest possible composition; verifying the pipeline.  |
| `product-ad-30s.html`        | 30s product video — hero shot, three feature beats, CTA.|
| `data-driven-chart.html`     | Animated bar chart with staggered reveal + value labels.|
| `lower-third-overlay.html`   | Title bar / name plate that slides in over footage.     |

**B. From scratch.** Use `npx hyperframes init <name> --non-interactive --example blank`
and edit `index.html`. Read `references/architecture.md` first to understand the
composition / scene / block taxonomy.

### 3. Author the composition

Read these references before writing HTML:

1. `references/architecture.md` — composition root, nested compositions, tracks,
   z-ordering, `data-*` attributes.
2. `references/animations.md` — GSAP timeline rules (`{ paused: true }`,
   `window.__timelines`, position parameter, deterministic seeking).
3. `references/catalog.md` — the 39 hyperframes block types you can install
   with `npx hyperframes add <block>`.

The three non-negotiable rules:

- **Root** — every composition's outermost element has `data-composition-id`,
  `data-width`, `data-height`.
- **Clips** — every timed element has `class="clip"`, `data-start`,
  `data-duration`, `data-track-index`. Clips on the same track cannot overlap.
- **Timeline** — exactly one `gsap.timeline({ paused: true })` per composition,
  registered as `window.__timelines[<composition-id>] = tl`. The framework
  drives playback; never call `tl.play()`, `media.play()`, or seek manually.

### 4. Lint

```bash
npx hyperframes lint ./index.html
```

Fix all errors. Warnings are usually safe to ship but worth reading.

### 5. Preview before render (REQUIRED)

```bash
npx hyperframes preview
# Opens http://localhost:3002
```

Scrub the timeline. Verify:
- All clips appear at the right time.
- GSAP animations look correct at every keyframe.
- Audio is present where expected.
- No clip is cut off because the timeline is shorter than the longest clip
  (see `references/animations.md` § "Extending timeline duration").

Only proceed to render after preview looks correct. Renders take 30s–10min;
you do not want to discover a typo at frame 4500.

### 6. Render

For iteration:
```bash
npx hyperframes render --output out.mp4 --quality draft
```

For final delivery:
```bash
npx hyperframes render --output final.mp4 --quality high
```

For deterministic / CI / shareable output:
```bash
npx hyperframes render --docker --output final.mp4
```

See `references/pipeline.md` for the full flag matrix (CRF, bitrate, workers,
GPU encoding, HDR, format selection).

**Timeout policy.** Renders are bounded by composition duration × frame cost.
Estimate before launching:
- 5s composition, 30fps, standard quality: ~10–30s wall clock.
- 30s composition, 30fps, high quality: 1–4 minutes.
- 60s+ composition or 60fps or 4K: up to 10 minutes.

When invoking via Bash, set `timeout: 600000` (10 min) for any non-trivial
render. For quick iteration use `--quality draft` to keep wall clock under 60s.

### 7. Verify output

```bash
ffprobe -v error -show_entries stream=width,height,r_frame_rate,duration \
  -of default=nw=1 out.mp4
```

Confirm width/height match the composition root, fps matches `--fps`, and
duration matches the GSAP timeline duration. If duration is short, the
timeline did not extend to cover the longest clip — see
`references/animations.md` § "Extending timeline duration".

---

## Verification

Before claiming the task complete:

- [ ] `hyperframes --version` and `ffmpeg -version` both succeeded in preflight.
- [ ] `npx hyperframes lint` reported zero errors.
- [ ] Preview was opened and visually confirmed at least once.
- [ ] Render command exited 0; output file exists at the requested path.
- [ ] `ffprobe` confirms width × height × fps × duration are as intended.
- [ ] If the user requested a specific aspect ratio (9:16, 1:1, 16:9), the
      composition root's `data-width` and `data-height` reflect it.
- [ ] No script in the composition calls `.play()`, `.pause()`,
      `currentTime =`, or animates `width`/`height`/`top`/`left` directly on
      a `<video>` element. (These are the most common bugs — see
      `references/animations.md` § "What NOT to do".)

---

## Edge cases

- **Render hangs at 0%.** Almost always a missing asset or unresolved
  `data-composition-src`. Check preview console for 404s.
- **Final video is shorter than expected.** GSAP timeline ends before the
  longest media clip. Add `tl.set({}, {}, <duration-in-seconds>)` to extend.
- **Black frames at the end.** Last GSAP tween fades something to opacity 0
  but the timeline keeps going — either trim the timeline or remove the fade.
- **Audio out of sync.** You animated `currentTime` in a script. Remove it;
  the framework owns media playback.
- **Fonts look different in render vs. preview.** Use `--docker` for
  reproducible font rendering across machines.
- **Video element stops painting after animation.** You animated
  `width`/`height` directly on a `<video>`. Wrap in a `<div>` and animate
  the wrapper.
- **`Math.random()` produces different output each render.** It does — that
  breaks determinism. Use a seeded RNG or pre-compute random values.
- **Render uses 100% CPU and laptop fans spin up.** Lower `--workers` to 1
  or 2. Default is half your cores capped at 4; on a hot machine drop it.
- **Need transparent background.** Use `--format mov` or `--format webm`;
  MP4 does not support alpha.

When in doubt, run `npx hyperframes doctor` and `npx hyperframes lint`
before debugging anything else.

---

### webgl-craft
# WebGL Craft — Technique Library for Premium Creative Web

This skill is a router, not an implementation. It exists to answer one question:
**"What technique should I reach for, and what is its cost?"**

Do not try to implement anything from memory. Find the right reference file first,
read it, then build. Premium creative web rewards precision over breadth; the wrong
technique applied well still loses to the right technique applied simply.

---

## HOW TO USE THIS SKILL

1. Identify which of the five technique domains the user's need falls into (below).
2. Read the matching reference file in full before writing any code.
3. If the need spans multiple domains, read them in the order listed in § COMMON COMBINATIONS.
4. If the user is planning a full site, read `references/architecture.md` FIRST — the
   architectural decision (persistent canvas vs. hybrid vs. DOM-first) constrains
   every other choice.
5. Pull working code from `recipes/` only after the approach is settled. Recipes are
   starting points, not drop-ins; every one has edit notes at the top.

---

## THE FIVE TECHNIQUE DOMAINS

### 1. Architecture — `references/architecture.md`

The site-level decision: where does the canvas live, how do routes transition, what
is rendered in the DOM vs. the WebGL scene. Read this first for any new project.

**Read when the user says:** "I want to build a [site/portfolio/landing page]",
"how should I structure this", "Next.js or Svelte", "React Three Fiber vs. vanilla
Three.js", "single page or multi-page", "smooth scroll", "page transitions",
"persistent canvas".

### 2. Shaders & 3D — `references/shaders.md`

The WebGL scene itself. Material design, post-processing, lighting, SDF/MSDF text,
particle systems, GPGPU, shader-driven distortion, and the specific signature effects
(gravitational lensing, fluid distortion, volumetric clouds, photo-projection,
procedural geometry).

**Read when the user says:** "3D hero", "shader", "distortion", "particles",
"black hole", "refraction", "bloom", "chromatic aberration", "film grain",
"lensing", "liquid cursor", "fluid", "noise", "volumetric", "crystal", "ice",
"glass", "glow".

### 3. Motion & Scroll — `references/motion-scroll.md`

GSAP ScrollTrigger patterns, Lenis configuration, scroll-to-uniform binding,
horizontal scroll pinning, camera scrubbing, timeline choreography, split-text
reveals, DrawSVG signatures, and the two-track frame budget pattern.

**Read when the user says:** "scroll animation", "on scroll", "parallax", "pinned",
"horizontal scroll", "reveal", "sticky", "scrub", "timeline", "camera path",
"choreography", "cinematic scroll".

### 4. Interaction Surfaces — `references/interaction.md`

Custom cursors, hover state systems, magnetic effects, AI-terminal patterns,
keyboard navigation, audio that responds to state, `prefers-reduced-motion`
handling, and mobile interaction degradation.

**Read when the user says:** "custom cursor", "magnetic button", "hover effect",
"AI chat widget", "terminal", "command palette", "ambient audio", "sound design",
"accessibility", "reduced motion", "mobile interaction".

### 5. Pipeline & Performance — `references/pipeline.md`

Asset compression (Draco/Meshopt/KTX2/Basis), glTF workflow, loading strategy,
shader pre-warming, bundle splitting, WebGPU/WebGL2 fallback via TSL, device-tier
adaptation, Lighthouse survival, `prefers-reduced-motion` compliance, and the
two-track frame budget implementation details.

**Read when the user says:** "too slow", "janky", "performance", "mobile is broken",
"Lighthouse", "bundle size", "WebGPU", "load time", "asset optimization",
"compression", "cross-browser".

---

## COMMON COMBINATIONS

Certain user intents consistently require the same combination of references. When
you recognize one, read them all in order before proposing anything.

**"Build me a portfolio / agency / studio site"**
→ architecture.md → motion-scroll.md → shaders.md → interaction.md → pipeline.md

**"Make the hero 3D and cinematic"**
→ shaders.md → motion-scroll.md → pipeline.md

**"Add a custom cursor that does [X]"**
→ interaction.md → shaders.md (if the cursor renders WebGL content)

**"Fix the performance"**
→ pipeline.md → architecture.md (if the answer is architectural) → motion-scroll.md
(if the answer is scroll-handler related)

**"Make page transitions smooth"**
→ architecture.md → motion-scroll.md → interaction.md

**"The site feels flat / generic / AI-looking"**
→ This is almost never a technique gap. Read `references/signature-moves.md` first.
The problem is usually the absence of ONE memorable interaction that literalizes the
site's subject. Adding more effects makes it worse.

---

## THE NON-NEGOTIABLE PRINCIPLES

These hold across every decision in every reference file. If a proposed approach
violates one of these, stop and reconsider before writing code.

**Signature interactions beat signature stacks.** One memorable gesture that
literalizes the site's subject outperforms ten generic premium effects. Before
suggesting Three.js, GSAP, Lenis, and post-processing, ask: what is the ONE
interaction this site will be remembered for? Read `references/signature-moves.md`
for the framework.

**Canvas is never the whole page.** Even sites that feel canvas-dominant (Igloo,
Prometheus) keep critical text in the DOM for SEO, screen readers, and copy-paste.
The question is never "canvas vs. DOM" — it is "which specific elements justify
WebGL rendering and which do not."

**The frame budget is two-track, not one.** The hero runs at native refresh rate.
Secondary elements (background particles, ambient fog, instrument telemetry) run
at 12–15 fps via a render-on-tick gate. This is the single most under-used
technique in the reference set and the cheapest performance win available.

**Shaders are authored in TSL, not GLSL, when targeting 2026+.** Three.js Shading
Language compiles to both WebGL2 and WebGPU from one source. Writing raw GLSL
today is writing migration work for tomorrow. Exception: pre-existing GLSL from
reputable public sources (Shadertoy, glslSandbox) is fine to port as-is, but any
new shader work should be TSL.

**Accessibility is a gate, not a feature.** `prefers-reduced-motion` kills or
dampens EVERY motion primitive. Keyboard focus is reachable on every interactive
element. Canvas-rendered text has a DOM mirror with `aria-hidden` on the canvas.
Skip this and the portfolio fails the Lighthouse screen recruiters run.

**Loading is UX, not a waiting room.** A 3-second "Load [Name]" preloader is a
recruiter-time tax. The DOM hero and critical interactions should be responsive
within 1.5s on 4G; the WebGL scene streams in afterward with a graceful reveal.
Never block first interaction on a preload.

---

## WHEN NOT TO USE THIS SKILL

Do not use this skill for:

- Content websites where motion would be distracting (news, blogs, documentation,
  SaaS dashboards). Use a clean, boring build. This skill's techniques are
  inappropriate for reading-optimized UX.
- Internal tools, admin panels, developer dashboards. WebGL here is costume, not
  function. Stick to standard component libraries.
- Sites where the subject is a form or a table. No amount of shader work makes
  data entry more pleasant; it makes it worse.
- E-commerce purchase flows. Keep the narrative/experiential layer separate
  (see how Lando Norris decouples `landonorris.com` from `store.landonorris.com`).
- Accessibility-critical contexts (government, healthcare, education). The
  trade-offs premium creative web accepts are not acceptable here.

If the user wants "premium" feel on a site that falls in these categories, the
answer is typography, spacing, color discipline, and motion restraint — not WebGL.

---

## REFERENCE FILE STRUCTURE

```
webgl-craft/
├── SKILL.md                          ← you are here
├── references/
│   ├── architecture.md               ← site-level decisions
│   ├── shaders.md                    ← WebGL scene and materials
│   ├── motion-scroll.md              ← GSAP/Lenis/ScrollTrigger
│   ├── interaction.md                ← cursors, AI terminals, audio, a11y
│   ├── pipeline.md                   ← assets, perf, WebGPU/TSL
│   └── signature-moves.md            ← the "what is this site's one gesture" framework
└── recipes/
    ├── persistent-canvas-r3f.tsx     ← single canvas across routes (Next.js App Router)
    ├── lensing-shader.ts             ← Schwarzschild black hole approximation (TSL)
    ├── fluid-cursor-mask.ts          ← Lando-style liquid blob cursor (TSL)
    ├── msdf-text-hero.tsx            ← troika-three-text hero with shader distortion
    ├── scroll-uniform-bridge.ts      ← GSAP ScrollTrigger → shader uniform
    ├── two-track-frame-budget.ts     ← 60fps hero + 12fps secondary gate
    ├── barba-style-transitions.tsx   ← persistent canvas + DOM overlay swap
    ├── ai-terminal-widget.tsx        ← streaming LLM terminal with rate limit + reduced motion
    └── audio-reactive-gain.ts        ← Web Audio gain modulated by scroll velocity
```

Each recipe file begins with a header:
- **Source lineage:** what public technique it's derived from
- **When to use:** the conditions under which this recipe is appropriate
- **When NOT to use:** the conditions under which a different approach is correct
- **Edit points:** the parameters most likely to need tuning per project
- **Known trade-offs:** accessibility, performance, mobile cost

Treat recipes as starting scaffolds. Every one is written to be read and modified,
not copy-pasted.

---

## META: WHY THIS SKILL EXISTS

The default failure mode when building a premium creative site is:

1. Reaching for Three.js + GSAP + Lenis because they are "what everyone uses"
2. Adding effects (bloom, chromatic aberration, film grain) until the site "looks
   premium"
3. Shipping, getting a 7/10 Awwwards score, wondering why it didn't hit 9/10

The reason is always the same: the site has no signature move. It is a competent
assembly of techniques without a reason to exist. This skill's purpose is to route
every decision back to the question of signature — and to supply the technical
precision to execute that signature when identified.

The techniques in the reference files were distilled from deep teardowns of sites
that achieved 8.5+/10 Awwwards scores: Igloo Inc (Developer Site of the Year 2024),
Lando Norris (Site of the Day Nov 2025), Prometheus Fuels (Site of the Month May
2021), and Shopify Editions Winter '26 Renaissance (SOTD Winter 2025). These are
not the only good sites; they are the four that, between them, cover the full
space of modern creative-web patterns from persistent-world to hybrid to DOM-first.

Trust the routing. Read the reference. Then build.

---

## Non-Negotiables

- NEVER skip verification on build/fix tasks
- NEVER skip systematic debugging when a bug is mentioned
- NEVER start implementing without brainstorming or an existing plan
- ALWAYS verify your work before declaring done
- ALWAYS rewind/restart instead of correcting on failed paths
