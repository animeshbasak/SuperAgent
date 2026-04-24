---
name: token-stats
description: Show superagent token savings stats for the current project — lifetime totals, last 5 sessions, compression ratio. Use when user asks about token savings, how many tokens saved, superagent stats, or runs /token-stats.
argument-hint: "[--test]"
---

# SuperAgent Token Stats

Show token savings for the current project.

## Steps

1. Check if `--test` flag was passed in arguments. If yes, skip to **Test Mode** below.

2. Run this command and display the output:

```bash
bash -c '
STATS="$HOME/.claude/superagent-stats.json"
PROJECT="$PWD"

if [[ ! -f "$STATS" ]]; then
  echo "No stats found. Run: graphify update <your-project-dir>"
  exit 0
fi

PROJECT_DATA=$(jq --arg p "$PROJECT" ".projects[\$p] // empty" "$STATS" 2>/dev/null)

if [[ -z "$PROJECT_DATA" ]]; then
  echo "No stats for: $PROJECT"
  echo "Run: graphify update $PROJECT"
  exit 0
fi

RATIO=$(echo "$PROJECT_DATA"  | jq -r ".compression_ratio // 0")
CAL_DATE=$(echo "$PROJECT_DATA" | jq -r ".calibrated_at // \"never\"")
GQ=$(echo "$PROJECT_DATA"  | jq -r ".lifetime.graphify_queries // 0")
GS=$(echo "$PROJECT_DATA"  | jq -r ".lifetime.graphify_tokens_saved // 0")
MH=$(echo "$PROJECT_DATA"  | jq -r ".lifetime.mempalace_hits // 0")
MS=$(echo "$PROJECT_DATA"  | jq -r ".lifetime.mempalace_tokens_saved // 0")
TOT=$(echo "$PROJECT_DATA" | jq -r ".lifetime.total_saved // 0")

fmt() {
  local n=$1
  if   [[ "$n" -ge 1000000 ]]; then echo "$(echo "scale=1; $n/1000000" | bc)M"
  elif [[ "$n" -ge 1000 ]];    then echo "$(echo "scale=0; $n/1000" | bc)k"
  else echo "$n"; fi
}

echo ""
echo "SuperAgent Token Stats — $PROJECT"
echo "──────────────────────────────────────────────"
printf "Compression ratio : %sx  (your codebase, measured %s)\n" "$RATIO" "$CAL_DATE"
echo "──────────────────────────────────────────────"
echo "Lifetime"
printf "  Graphify queries  : %s\n" "$GQ"
printf "    → %s tokens saved\n" "$(fmt $GS)"
printf "  Mempalace hits    : %s\n" "$MH"
printf "    → ~%s tokens saved (estimate)\n" "$(fmt $MS)"
printf "  Total saved       : ~%s tokens\n" "$(fmt $TOT)"
echo ""
echo "Last 5 sessions"
printf "  %-12s  %-10s  %-10s  %s\n" "Date" "Graphify" "Mempalace" "Saved"
echo "$PROJECT_DATA" | jq -r "
  .sessions[:5][] |
  [.date, (.graphify_queries|tostring), (.mempalace_hits|tostring), (.saved|tostring)] |
  @tsv" | while IFS=$'"'"'\t'"'"' read -r d g m s; do
    printf "  %-12s  %-10s  %-10s  ~%s\n" "$d" "$g" "$m" "$s"
  done
echo "──────────────────────────────────────────────"
echo "Tip: re-run graphify update <dir> after large codebase changes."
echo ""
'
```

## Cost report

Also run and include dollar-cost breakdown:

```bash
superagent-cost today
superagent-cost week
```

Shows cost grouped by model (opus / sonnet / haiku) and a model-mix coach note.

## Test Mode

When `--test` argument is passed, display this hardcoded sample output:

```
SuperAgent Token Stats — /your/project (SAMPLE DATA)
──────────────────────────────────────────────
Compression ratio : 48.3x  (your codebase, measured 2026-04-17)
──────────────────────────────────────────────
Lifetime
  Graphify queries  : 47
    → 198k tokens saved
  Mempalace hits    : 23
    → ~31k tokens saved (estimate)
  Total saved       : ~229k tokens

Last 5 sessions
  Date          Graphify    Mempalace   Saved
  2026-04-17    12          4           ~58k
  2026-04-16    8           2           ~38k
  2026-04-15    15          6           ~71k
  2026-04-14    5           3           ~22k
  2026-04-13    7           8           ~40k
──────────────────────────────────────────────
Tip: re-run graphify update <dir> after large codebase changes.
```
