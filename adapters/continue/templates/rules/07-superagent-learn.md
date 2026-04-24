---
name: learn
---
# learn

> Persistent per-project learnings. Add a learning, list all learnings, or search. Backed by ~/.superagent/learnings/<project-hash>.jsonl.

# Learn

> **Ethos:** Memory compounds.

## When to use
- User says "remember that we decided X" or "learn this for next time".
- After a correction that future-you should not repeat.
- Before a retro — list learnings for review.

## Inputs
- `$ARGUMENTS` — `add "<text>"`, `list`, or `search "<query>"`.

## Procedure

Shell out to the helper:
```bash
superagent-learn $ARGUMENTS
```

## Output
- `add` → prints `recorded`.
- `list` → prints all learnings (latest first).
- `search` → prints matching lines.

## Verification
Learnings file exists at `~/.superagent/learnings/<sha256-12-of-cwd>.jsonl` after add.
