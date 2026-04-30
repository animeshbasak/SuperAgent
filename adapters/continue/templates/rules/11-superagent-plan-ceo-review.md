---
name: plan-ceo-review
---
# plan-ceo-review

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
