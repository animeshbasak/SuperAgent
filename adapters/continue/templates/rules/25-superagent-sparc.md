---
name: sparc
---
# sparc

> 5-phase gate-enforced pipeline (Specification → Pseudocode → Architecture → Refinement → Completion). Boolean gates per phase; refuses to advance until the current gate passes. Use when complexity warrants methodology, when a feature needs an audit trail (ACs → tests → code), or when the user asks for a PRD/spec/RFC. Triggers on "sparc", "spec", "PRD", "methodology", "gate", "spike", "RFC", "traceability".

# sparc

Wave 3 adds a thin orchestrator that chains existing SuperAgent skills with hard boolean gate checks. SPARC is **opt-in per feature** — `/sparc init <slug>` starts a session; it never auto-fires.

## When to use

- The user describes a feature that needs an audit trail.
- A PR will touch security-sensitive or cross-module code.
- The user says "spec this", "write a PRD", "I want a methodology", "traceability matrix".
- You want a gate that refuses to ship before all ACs have passing tests.

## The 5 phases

| # | Phase | Output artifact | Gate (boolean) | SA skills used |
|---|---|---|---|---|
| 1 | Specification | `spec.md` | ≥3 ACs, ≥1 Constraint, ≥1 Edge case | `agent-skills:spec-driven-development`, `office-hours` |
| 2 | Pseudocode | `pseudo.md` | covers every AC, error paths explicit, complexity notes per algo | `agent-skills:planning-and-task-breakdown` |
| 3 | Architecture | `arch.md` | typed signatures, every Constraint addressed | `architect` agent (Wave 2), `plan-eng-review` |
| 4 | Refinement | `refine.md` | every AC has a passing test, coverage ≥ threshold | `agent-skills:test-driven-development`, `tester` agent, `review` |
| 5 | Completion | `complete.md` + ADRs | deploy checklist verified, traceability matrix complete | `agent-skills:documentation-and-adrs`, `verification-before-completion`, `ship` |

**Gates are boolean — pass or fail.** No 0.0-1.0 quality scores. Easier to verify objectively.

## Procedure

1. **Init the feature:**
   ```bash
   superagent-sparc init feat-darkmode-toggle
   ```
2. **Write the artifact for the current phase** into the printed directory (e.g. `~/.superagent/sparc/feat-darkmode-toggle/spec.md`). Use the AC format `- AC: <id> — <description>`; constraint lines start with `Constraint:`; edge case lines with `Edge case:`.
3. **Run the gate:**
   ```bash
   superagent-sparc gate
   ```
   On failure, the reason is appended to `gate_failures[]` in `state.json`. Fix and re-run.
4. **Advance only after gate passes:**
   ```bash
   superagent-sparc advance
   ```
5. **At any time, inspect state or matrix:**
   ```bash
   superagent-sparc status
   superagent-sparc report
   ```

## Files

- State: `~/.superagent/sparc/<slug>/state.json`
- Artifacts: `~/.superagent/sparc/<slug>/{spec,pseudo,arch,refine,complete}.md`
- Active slug: `SUPERAGENT_SPARC_SLUG` env var; else most-recently-updated dir.

## Hand-off rules

- Phase 3 dispatches to the `architect` agent (Wave 2 specialist).
- Phase 4 dispatches to the `tester` agent + runs `review` skill.
- Phase 5 dispatches to `ship` skill.
- Each phase's gate ensures the artifact exists in the expected shape before hand-off.

## Ethos

Verify or die. Boolean gates beat fake-precision scores because they force the LLM (and the user) to name a concrete failure mode rather than negotiate over a fuzzy number. The traceability matrix is the receipt — every AC links to a pseudo line, an arch entry, a test, and a code reference. If any column is empty, the feature isn't done.
