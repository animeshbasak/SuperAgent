---
name: observability
---
# observability

> JSONL spans + metrics for SuperAgent. Read the trace tree of any session, aggregate counter/gauge/histogram metrics with p50/p95/p99, and flag anomalies via rolling mean + 2σ. Triggers on "show the trace", "metrics for today", "what's slow", "anomaly", "p95 latency".

# observability

Wave 2 ships pure-JSONL observability — no OTel libraries, no remote backend. Hooks emit spans on every tool call and metrics on every token-bearing event. Files live under `~/.superagent/obs/` and rotate daily.

## When to use

- User asks "why is X slow" / "show me the trace for last route" / "what was the bottleneck".
- User asks "how many tokens did I burn today" / "are there any anomalies in latency".
- After a session you want to attribute timing across subagents.

## Procedure

1. **Inspect a single trace.** Pass the traceId you care about:
   ```bash
   superagent-trace t-abc12345
   ```
   Output is an ASCII parent-child tree with per-span duration. Bottlenecks (duration ≥ p95 of the op AND > 2× mean) are flagged `(bottleneck)`.
2. **Aggregate metrics over a range.**
   ```bash
   superagent-metrics today
   superagent-metrics week --json | jq .
   ```
   Counters → SUM, gauges → LAST value (insertion-order tiebreak), histograms → p50/p95/p99. Anomaly flag: rolling mean + 2σ over the last 100 samples.
3. **Find a traceId.** The latest span's traceId is the most recent route:
   ```bash
   tail -n 1 ~/.superagent/obs/spans.jsonl | jq -r .traceId
   ```
4. **Rotate manually if needed** (Stop hook does this daily already):
   ```bash
   superagent-obs-rotate
   ```

## Files

- Active: `~/.superagent/obs/spans.jsonl` and `metrics.jsonl`.
- Rotated: `spans.<YYYYMMDD>.jsonl` and `metrics.<YYYYMMDD>.jsonl` (>30 days = pruned).
- Marker: `~/.superagent/obs/.last-rotate-<YYYYMMDD>` (presence = already rotated today).

## Six canonical metric names

Lifted from the v3 design spec §7.3 — when emitting, prefer these names so dashboards stay consistent:

- `agent_task_duration_seconds` (histogram)
- `agent_token_usage` (histogram)
- `agent_active_count` (gauge)
- `agent_error_rate` (counter)
- `swarm_span_duration_ms` (histogram)
- `memory_operations_total` (counter)

## Trace ID propagation

The `superagent` skill sets `SA_TRACE_ID` at chain start. Downstream bins inherit it through the environment; if unset, the tracker.sh hook generates a fresh root span id. Cross-session boundary = new traceId. Don't try to span across SessionStart.

## Performance budget

Span/metric writes are append-only JSONL via `jq -nc`. Cost is ~1 ms per write; never on the user's critical path. Stop hook rotates once per day via the `.last-rotate-<YYYYMMDD>` marker so the active files stay small.

## Ethos

Verify or die. The trace tree is the receipt — every chain that ran left a structured record. Use it when a "fast" route felt slow; the bottleneck flag will name the offending op before you debug.
