# superagent

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
