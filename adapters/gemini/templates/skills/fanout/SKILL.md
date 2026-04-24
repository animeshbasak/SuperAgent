---
name: fanout
description: Run 2+ skills in parallel via dispatching-parallel-agents and merge their reports. Use when subtasks are independent (no shared state).
---

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
