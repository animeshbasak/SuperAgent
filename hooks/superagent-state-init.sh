#!/usr/bin/env bash
# Idempotent: creates ~/.superagent/ and subdirs, migrates legacy paths.
set -euo pipefail
ROOT="${HOME}/.superagent"
mkdir -p "$ROOT"/{brain,bench,learnings,chains,cost,logs}

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

echo "superagent state root ready: $ROOT"
