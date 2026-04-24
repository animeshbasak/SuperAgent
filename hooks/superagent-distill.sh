#!/usr/bin/env bash
# Stop hook: distills correction signals from transcript into CLAUDE.md.superagent-proposed
#   AND appends to ~/.superagent/learnings/<project-hash>.jsonl.
#
# SAFETY: never mutates CLAUDE.md directly. v2.0 writes proposals only.
# Exit 0 always — never block the session.

set -eu

PAYLOAD=$(cat 2>/dev/null || echo '{}')
TRANSCRIPT=$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
[[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]] || exit 0

CORRECTIONS=$(tail -n 400 "$TRANSCRIPT" 2>/dev/null \
  | jq -r 'select(.role=="user") | .content // empty' 2>/dev/null \
  | grep -iE "^(no[,. ]|don't|stop|never|actually|wrong|not like that|do not )" \
  | head -5 || true)

[[ -z "$CORRECTIONS" ]] && exit 0

DATE=$(date -I 2>/dev/null || date +%Y-%m-%d)

# Write 1: proposed additions (never mutate CLAUDE.md directly)
PROPOSAL_FILE="$PWD/CLAUDE.md.superagent-proposed"
MARK="<!-- superagent:auto-learnings -->"

if [[ ! -f "$PROPOSAL_FILE" ]]; then
  printf '# Proposed CLAUDE.md additions from SuperAgent distill hook\n\n' > "$PROPOSAL_FILE"
  printf '%s\n## Auto-distilled learnings\n\n' "$MARK" >> "$PROPOSAL_FILE"
fi

while IFS= read -r c; do
  [[ -z "$c" ]] && continue
  FIRST40=$(printf '%s' "$c" | head -c 40)
  if ! grep -qF "$FIRST40" "$PROPOSAL_FILE" 2>/dev/null; then
    printf -- '- (%s) %s\n' "$DATE" "$(printf '%s' "$c" | head -c 200)" >> "$PROPOSAL_FILE"
  fi
done <<< "$CORRECTIONS"

# Write 2: structured jsonl to ~/.superagent/learnings/<project-hash>.jsonl
LEARN_ROOT="$HOME/.superagent/learnings"
mkdir -p "$LEARN_ROOT"
PROJECT_HASH=$( (printf '%s' "$PWD" | shasum -a 256 2>/dev/null) || (printf '%s' "$PWD" | sha256sum 2>/dev/null) )
PROJECT_HASH=$(printf '%s' "$PROJECT_HASH" | cut -c1-12)
LEARN_FILE="$LEARN_ROOT/$PROJECT_HASH.jsonl"

while IFS= read -r c; do
  [[ -z "$c" ]] && continue
  TS=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
  printf '%s' "$c" | jq -Rs --arg ts "$TS" --arg proj "$PWD" --arg src "auto-distill" \
    '{ts: $ts, project: $proj, source: $src, text: .}' >> "$LEARN_FILE" 2>/dev/null || true
done <<< "$CORRECTIONS"

exit 0
