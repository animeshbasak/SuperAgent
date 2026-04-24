---
name: investigate
description: Root-cause investigation. Enforces the Iron Law — no fixes without investigation first. 4 phases: Reproduce → Isolate → Explain → Verify. Upgrade over systematic-debugging when the bug is worth understanding, not just patching.
---

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
