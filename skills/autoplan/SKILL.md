---
name: autoplan
description: Auto-pipeline a plan through product, design, and eng review sequentially, then synthesize into a single plan artifact. Use when you want the full review stack without invoking skills manually one at a time.
argument-hint: "<plan text or path>"
---

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
