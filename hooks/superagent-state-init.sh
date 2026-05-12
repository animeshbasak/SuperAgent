#!/usr/bin/env bash
# Idempotent: creates ~/.superagent/ and subdirs, migrates legacy paths.
set -euo pipefail
ROOT="${HOME}/.superagent"
mkdir -p "$ROOT"/{brain,bench,learnings,chains,cost,logs,agent-memory,safety,aidefence,autopilot,obs,sparc,testgen,diff,.backups}

# Migrate legacy stats file if present
LEGACY="${HOME}/.claude/superagent-stats.json"
NEW="$ROOT/stats.json"
if [[ -f "$LEGACY" && ! -f "$NEW" ]]; then
  cp "$LEGACY" "$NEW"
  echo "migrated: $LEGACY -> $NEW"
fi

# Seed empty files (idempotent — touch only if missing)
[[ -f "$ROOT/brain/routes.jsonl" ]]              || : > "$ROOT/brain/routes.jsonl"
[[ -f "$ROOT/brain/patterns.jsonl" ]]            || : > "$ROOT/brain/patterns.jsonl"
[[ -f "$ROOT/brain/protected-patterns.jsonl" ]]  || : > "$ROOT/brain/protected-patterns.jsonl"
[[ -f "$ROOT/learnings/global.jsonl" ]]          || : > "$ROOT/learnings/global.jsonl"
[[ -f "$ROOT/cost/calls.jsonl" ]]                || : > "$ROOT/cost/calls.jsonl"
[[ -f "$ROOT/cost/alerts.jsonl" ]]               || : > "$ROOT/cost/alerts.jsonl"

# Default budget.json — conservative
if [[ ! -f "$ROOT/cost/budget.json" ]]; then
  cat > "$ROOT/cost/budget.json" <<'JSON'
{
  "daily_usd": 20,
  "monthly_usd": 400,
  "alert_thresholds": [0.5, 0.75, 0.9, 1.0],
  "auto_downgrade": {"at": 0.9, "target": "sonnet"},
  "hard_stop": {"at": 1.0, "mode": "prompt"}
}
JSON
fi

# Default pricing.json — empty placeholder; bin/superagent-cost falls back to hardcoded table
[[ -f "$ROOT/cost/pricing.json" ]] || echo '{}' > "$ROOT/cost/pricing.json"

# Defaults.toml — single source of truth for magic numbers
if [[ ! -f "$ROOT/defaults.toml" ]]; then
  cat > "$ROOT/defaults.toml" <<'TOML'
# SuperAgent defaults — env vars override (e.g. SUPERAGENT_LEARNING_DECAY_RATE_PER_HOUR)
[learning]
decay_rate_per_hour = 0.005
boost_per_access = 0.03
min_confidence = 0.1
protected_floor = 0.3
promote_min_uses = 3
classifier_gate_success_rate = 0.6
classifier_gate_use_count = 5

[cost]
pricing_version = "2026-Q2"
alert_thresholds = [0.5, 0.75, 0.9, 1.0]
hard_stop_mode = "prompt"
TOML
fi

# Safety allow-list seed
if [[ ! -f "$ROOT/safety/allow.txt" ]]; then
  cat > "$ROOT/safety/allow.txt" <<'ALLOWEOF'
# superagent-safety pre-approved patterns. One regex per line.
# Examples (commented out — uncomment if you want them allowed silently):
# ^git push --force-with-lease\b
# ^rm -rf /tmp/superagent-bench-
ALLOWEOF
fi

echo "superagent state root ready: $ROOT"
