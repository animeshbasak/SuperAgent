# review

> Pre-merge diff review gate. 6-point checklist covers scope drift, implementation fidelity, tests, migrations, TODOs, docs. Flags SQL safety / trust boundary / side-effect bugs. Rates LGTM / Needs Changes / Block.

# Review

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- Before merging a PR.
- After `/ship` rebases and before it pushes.
- When a plan claims done and you want a second opinion.

## Inputs
- `$ARGUMENTS` — optional base branch name (default: `main`).

## Step 0 — diff-risk pre-check (Wave 3)

Before running the 6-point checklist, run `superagent-diff-risk` to ground the review in objective signal:

```bash
superagent-diff-risk report --base "${ARGUMENTS:-origin/main}" --json
```

Fold the output into the review verdict:

- `impact: critical | high` → call out blast radius in the verdict. Recommend additional reviewers from `reviewers.owners`. Surface every `risk_factors[]` flag in the review summary.
- `classification.primary: feature` and `impact: low` → standard review proceeds.
- `db_migration` or `security_paths` flag → escalate to `security-architect` agent before LGTM.

Also consult cached coverage (Wave 3):

```bash
superagent-testgen status --json
```

If `verdict: BELOW THRESHOLD`, include the coverage delta in the review output but do not gate-block on it (project teams own the threshold).

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
