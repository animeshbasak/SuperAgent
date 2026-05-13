---
name: diff-risk
description: Slash dispatcher for diff-risk. Routes args to bin/superagent-diff-risk.
---

# /diff-risk

Routes the user's subcommand to `bin/superagent-diff-risk`. See [diff-risk](../skills/diff-risk/SKILL.md) for the full procedure.

## Usage

```
/diff-risk report [--base <ref>] [--json]        # composite report (most common)
/diff-risk classify [--commit-msg <m>] [--files <csv>]
/diff-risk impact [--files <csv>] [--branch <name>] [--diff-lines <n>]
/diff-risk reviewers [--files <csv>] [--codeowners <path>]
```

## Procedure

- `report` is the default verb most users want. Surface the markdown output verbatim.
- For high/critical impact, recommend running `review` next.
- When CODEOWNERS suggests reviewers, surface them — do not @-mention them in PR descriptions automatically; let the user decide.

Do not call `git push` from this skill. Diff-risk inspects; `ship` is the verb that pushes.
