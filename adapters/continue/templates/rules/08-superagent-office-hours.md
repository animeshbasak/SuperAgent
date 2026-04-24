---
name: office-hours
---
# office-hours

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
