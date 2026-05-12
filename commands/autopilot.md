---
name: autopilot
description: Slash dispatcher for unattended loop. Forwards args to bin/superagent-autopilot.
---

# /autopilot

Routes the user's subcommand to `bin/superagent-autopilot`. See [autopilot](../skills/autopilot/SKILL.md) for the full procedure.

## Usage

```
/autopilot status                            # show enabled, iterations, bounds, history
/autopilot enable                            # opt in
/autopilot disable                           # opt out
/autopilot config --max-iterations 100       # clamped to [1,1000]
/autopilot config --timeout-minutes 60       # clamped to [1,1440]
/autopilot tasks                             # discover pending (3 sources)
/autopilot predict                           # next action with confidence
/autopilot iter                              # one iteration + ScheduleWakeup directive
```

## Procedure

For `iter`, when the directive returns `delaySeconds=270`, call the harness `ScheduleWakeup` tool with that value and the emitted reason. Surface `paused:true` outputs verbatim so the user knows whether budget or disabled state stopped the loop.

Do not enable autopilot automatically — the user opts in.
