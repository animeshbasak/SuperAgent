#!/usr/bin/env bash
# Idempotent: creates ~/.superagent/ and subdirs, migrates legacy paths.
set -euo pipefail
ROOT="${HOME}/.superagent"
mkdir -p "$ROOT"/{brain,bench,learnings,chains,cost,logs,agent-memory,safety}

# Migrate legacy stats file if present
LEGACY="${HOME}/.claude/superagent-stats.json"
NEW="$ROOT/stats.json"
if [[ -f "$LEGACY" && ! -f "$NEW" ]]; then
  cp "$LEGACY" "$NEW"   # intentional cp: legacy removal deferred to Phase 6.2
  echo "migrated: $LEGACY -> $NEW"
fi

# Seed empty files
[[ -f "$ROOT/brain/routes.jsonl" ]] || : > "$ROOT/brain/routes.jsonl"
[[ -f "$ROOT/learnings/global.jsonl" ]] || : > "$ROOT/learnings/global.jsonl"

# Safety allow-list seed (one regex per line; comments with #)
if [[ ! -f "$ROOT/safety/allow.txt" ]]; then
  cat > "$ROOT/safety/allow.txt" <<'ALLOWEOF'
# superagent-safety pre-approved patterns. One regex per line.
# Matches against the bash command, file path, etc. — not the risky-pattern label.
# Examples (commented out — uncomment if you want them allowed silently):
# ^git push --force-with-lease\b
# ^rm -rf /tmp/superagent-bench-
ALLOWEOF
fi

echo "superagent state root ready: $ROOT"
