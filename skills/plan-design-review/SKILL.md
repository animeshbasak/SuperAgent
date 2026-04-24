---
name: plan-design-review
description: "Designer's pressure-test — rate 10 design dimensions 0–10, identify fixes for anything under 7, propose top-3 highest-leverage changes. Iterative: rate → gap → fix → re-rate."
argument-hint: "<design artifact: screenshot path, URL, or description>"
---

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
