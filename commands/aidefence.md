---
name: aidefence
description: Slash dispatcher for the AIDefence prompt scanner. Forwards args to bin/superagent-aidefence.
---

# /aidefence

Forwards your subcommand to `bin/superagent-aidefence`. Use the [aidefence](../skills/aidefence/SKILL.md) skill for the full procedure.

## Usage

```
/aidefence status                          # show enabled/disabled, pattern count
/aidefence enable                          # drop the enabled flag
/aidefence disable                         # clear the enabled flag
/aidefence scan "<text>"                   # one-off scan
/aidefence list                            # table of all 58 patterns
/aidefence feedback <pattern-id> inaccurate   # decay confidence via EMA
```

## Procedure

Run the user's subcommand with `bin/superagent-aidefence`. Surface the JSON output for `scan` so the user can see threats / piiFound / detectionTimeMs. For `status` / `list`, print the bin's stdout verbatim.

Do not enable AIDefence automatically — the user opts in.
