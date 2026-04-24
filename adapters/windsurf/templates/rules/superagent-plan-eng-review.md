# plan-eng-review

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
