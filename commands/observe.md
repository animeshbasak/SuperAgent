---
name: observe
description: Slash dispatcher for the observability bins. Forwards subcommands to superagent-trace, superagent-metrics, superagent-obs-rotate.
---

# /observe

Routes the user's request to the right observability bin. See [observability](../skills/observability/SKILL.md) for the full procedure.

## Usage

```
/observe trace <traceId>            # ASCII parent-child tree + bottleneck flag
/observe metrics today              # aggregate by name, with p50/p95/p99 + anomalies
/observe metrics week --json        # machine-readable
/observe rotate                     # force a manual rotation (Stop hook already runs daily)
```

## Procedure

- `trace <id>` → run `bin/superagent-trace <id>` and print stdout verbatim.
- `metrics <range>` → run `bin/superagent-metrics <range>` and print stdout verbatim.
- `rotate` → run `bin/superagent-obs-rotate` (no output on success).

If no traceId is given for `trace`, suggest:
```bash
tail -n 1 ~/.superagent/obs/spans.jsonl | jq -r .traceId
```
