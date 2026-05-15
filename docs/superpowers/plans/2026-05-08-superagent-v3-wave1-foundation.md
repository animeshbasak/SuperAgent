# SuperAgent v3 — Wave 1 (Foundation, v2.4.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the three Wave 1 components from the v3 spec (hooks lifecycle, learning loop, cost-tracker schema bump) so the SuperAgent classifier becomes self-improving and budget enforcement works.

**Architecture:** Three concurrent threads of work (5 net-new hooks; learning-loop store + classifier wiring; cost-tracker 4-dim schema + budget alerts) all write into `~/.superagent/` subdirs. Each thread is independently testable. Spec source: `docs/superpowers/specs/2026-05-08-superagent-v3-upgrade-design.md` §6 + §9.

**Tech Stack:** bash 5+, python3 (inline via heredoc), jq, yq, git. No pytest, no sqlite, no ONNX. Tests are bash scripts under `test/` following the existing `test-classify.sh` style.

---

## File structure

### New files
- `bin/superagent-patterns` — pattern store CLI (list, promote, decay, protect, prune subcommands)
- `hooks/superagent-prompt-submit.py` — UserPromptSubmit hook (classify + announce)
- `hooks/superagent-subagent-stop.py` — SubagentStop hook (route log + cost attribution)
- `hooks/superagent-notification.py` — Notification hook (filter)
- `hooks/superagent-permission.py` — PermissionRequest hook (auto-allow from safety/allow.txt)
- `hooks/superagent-precompact.py` — PreCompact hook (export to claude-mem)
- `skills/superagent-learn-loop/SKILL.md` — learning loop user-facing skill
- `skills/cost-budget/SKILL.md` — budget alerts + downgrade skill
- `test/test-patterns.sh` — pattern store math + dedup
- `test/test-cost-v2.sh` — 4-dim pricing + budget alerts + flag drop
- `test/test-hooks-smoke.sh` — pipe stdin JSON, assert hook output shape
- `test/test-classify-patterns.sh` — classifier reads patterns.jsonl with gate

### Modified files
- `bin/superagent-cost` — 4-dim pricing, budget alerts, auto-downgrade.flag drop, v1 auto-detect
- `bin/superagent-classify` — read patterns.jsonl, gate at successRate≥0.6 + useCount≥5
- `hooks/superagent-tracker.sh` — write v2 records (4-dim tokens) to calls.jsonl
- `hooks/superagent-distill.sh` — call patterns promote+decay at Stop
- `hooks/superagent-state-init.sh` — scaffold new dirs + defaults.toml + budget.json
- `hooks/hooks.json` — 5 new event blocks (UserPromptSubmit, SubagentStop, Notification, PermissionRequest, PreCompact)
- `install.sh` — wire 5 new hooks idempotently, copy py scripts, drop `.wave-1.installed` marker
- `skills/auto-fallback/SKILL.md` — honor `~/.superagent/auto-downgrade.flag`
- `bench/prompts.jsonl` — +5 prompts for Wave 1 keywords
- `README.md` — feature row in capability table
- `CHANGELOG.md` — v2.4.0 entry
- `package.json` — version bump to 2.4.0

### Runtime state created at install
- `~/.superagent/defaults.toml` — magic-number config
- `~/.superagent/cost/budget.json` — budget config (conservative defaults)
- `~/.superagent/cost/pricing.json` — optional override (created empty)
- `~/.superagent/brain/patterns.jsonl` — empty file (touched at install)
- `~/.superagent/brain/protected-patterns.jsonl` — empty file
- `~/.superagent/cost/alerts.jsonl` — touched
- `~/.superagent/.wave-1.installed` — idempotency marker

---

## Task 1: Bootstrap state + defaults

**Files:**
- Modify: `hooks/superagent-state-init.sh` (add new dirs, defaults.toml seeding, budget.json default)
- Test: `test/test-state-init.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-state-init.sh`:

```bash
#!/usr/bin/env bash
# test/test-state-init.sh — verify state-init creates all Wave 1 paths
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SCRIPT="$SCRIPT_DIR/../hooks/superagent-state-init.sh"

TMPHOME=$(mktemp -d)
HOME="$TMPHOME" bash "$INIT_SCRIPT" > /dev/null

EXPECTED=(
  "$TMPHOME/.superagent/brain/patterns.jsonl"
  "$TMPHOME/.superagent/brain/protected-patterns.jsonl"
  "$TMPHOME/.superagent/cost/budget.json"
  "$TMPHOME/.superagent/cost/alerts.jsonl"
  "$TMPHOME/.superagent/defaults.toml"
)

fail=0
for path in "${EXPECTED[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "FAIL: missing $path"
    fail=1
  fi
done

# budget.json must be valid JSON with daily_usd
if ! jq -e '.daily_usd > 0' "$TMPHOME/.superagent/cost/budget.json" >/dev/null 2>&1; then
  echo "FAIL: budget.json missing daily_usd"
  fail=1
fi

# defaults.toml must contain [learning] section
if ! grep -q '^\[learning\]' "$TMPHOME/.superagent/defaults.toml"; then
  echo "FAIL: defaults.toml missing [learning] section"
  fail=1
fi

rm -rf "$TMPHOME"
[[ $fail -eq 0 ]] && echo "test-state-init: PASS" || { echo "test-state-init: FAIL"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x test/test-state-init.sh
test/test-state-init.sh
```

Expected: `FAIL: missing .../patterns.jsonl` (and several other missing files).

- [ ] **Step 3: Implement state-init extension**

Replace the body of `hooks/superagent-state-init.sh` with:

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-state-init.sh
```

Expected: `test-state-init: PASS`

- [ ] **Step 5: Commit**

```bash
git add hooks/superagent-state-init.sh test/test-state-init.sh
git commit -m "feat(state): scaffold Wave 1 dirs + defaults.toml + budget.json"
```

---

## Task 2: Cost-tracker — 4-dim pricing table + v1 auto-detect

**Files:**
- Modify: `bin/superagent-cost` (extend pricing table, support v2 records, fallback v1 detection)
- Test: `test/test-cost-v2.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-cost-v2.sh`:

```bash
#!/usr/bin/env bash
# test/test-cost-v2.sh — schema v2 pricing + v1 backcompat
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COST_BIN="$SCRIPT_DIR/../bin/superagent-cost"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/cost"

# Mixed v1 + v2 records
cat > "$TMPHOME/.superagent/cost/calls.jsonl" <<JSONL
{"ts":"$(date -u -v+0H -Iseconds 2>/dev/null || date -u -Iseconds)","project":"/x","tool":"Bash","tokens":500000,"model":"sonnet"}
{"ts":"$(date -u -v+0H -Iseconds 2>/dev/null || date -u -Iseconds)","project":"/x","tool":"Bash","model":"sonnet","input_tokens":100000,"output_tokens":400000,"cache_write_tokens":0,"cache_read_tokens":0,"task_id":"t-test","http_status":200,"pricing_version":"2026-Q2"}
JSONL

# Default budget so script doesn't 404
cat > "$TMPHOME/.superagent/cost/budget.json" <<'JSON'
{"daily_usd":20,"monthly_usd":400,"alert_thresholds":[0.5,0.75,0.9,1.0],
 "auto_downgrade":{"at":0.9,"target":"sonnet"},"hard_stop":{"at":1.0,"mode":"prompt"}}
JSON

OUT=$(HOME="$TMPHOME" "$COST_BIN" today --json)
echo "$OUT" | jq . >/dev/null || { echo "FAIL: invalid JSON"; rm -rf "$TMPHOME"; exit 1; }

# Both records should be summed; sonnet pricing under v2 = (100000*3 + 400000*15)/1M = 6.30
# v1 record: 500000 tokens treated as output_tokens only = 500000*15/1M = 7.50
# total = 6.30 + 7.50 = 13.80
TOTAL=$(echo "$OUT" | jq '.total_usd')
PASS=$(python3 -c "print(abs($TOTAL - 13.80) < 0.01)")
[[ "$PASS" == "True" ]] || { echo "FAIL: expected total~13.80, got $TOTAL"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-cost-v2: PASS"
```

```bash
chmod +x test/test-cost-v2.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-cost-v2.sh
```

Expected: `FAIL: expected total~13.80, got <some-other-number>` (current cost script uses `tokens*PRICE['sonnet']/1M = 0.5M*6/1M = 3.00` for both records, so total = 6.00).

- [ ] **Step 3: Implement v2 pricing in superagent-cost**

Replace the python heredoc inside `bin/superagent-cost`. The full new file:

```bash
#!/usr/bin/env bash
# Usage: superagent-cost [today|week|all] [--json]
# Reads ~/.superagent/cost/calls.jsonl (mixed v1/v2 records), groups by model, prints $ cost table + coach note.
# --json emits machine-readable output (used by superagent-limit-watch.sh hook).
set -euo pipefail
RANGE="today"
JSON_MODE=0
for arg in "$@"; do
  case "$arg" in
    --json)            JSON_MODE=1 ;;
    today|week|all)    RANGE="$arg" ;;
    *)                 RANGE="$arg" ;;
  esac
done
FILE="$HOME/.superagent/cost/calls.jsonl"

if [[ ! -f "$FILE" ]]; then
  if [[ "$JSON_MODE" -eq 1 ]]; then
    echo '{"range":"'"$RANGE"'","total_usd":0,"by_model":{},"pct_of_plan":0,"time_to_5h_reset_minutes":300,"recent_429_count_60s":0}'
  else
    echo "no cost data yet (file not found: $FILE)"
  fi
  exit 0
fi

python3 - "$FILE" "$RANGE" "$JSON_MODE" "$HOME" <<'PY'
import json, sys, datetime, collections, os
path, rng, json_mode, home = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4]
now = datetime.datetime.now(datetime.timezone.utc)
cutoff = {
  'today': now.replace(hour=0, minute=0, second=0, microsecond=0),
  'week':  now - datetime.timedelta(days=7),
  'all':   datetime.datetime.min.replace(tzinfo=datetime.timezone.utc),
}.get(rng)
if cutoff is None:
  print(f"unknown range: {rng}. use today|week|all", file=sys.stderr)
  sys.exit(2)

# 4-dim pricing per 1M tokens (Anthropic 2026-Q2). Override at ~/.superagent/cost/pricing.json
DEFAULT_PRICING = {
  "haiku":   {"input": 0.25, "output": 1.25,  "cache_write": 0.30,  "cache_read": 0.03},
  "sonnet":  {"input": 3.00, "output": 15.00, "cache_write": 3.75,  "cache_read": 0.30},
  "opus":    {"input": 15.0, "output": 75.00, "cache_write": 18.75, "cache_read": 1.50},
  "local":   {"input": 0,    "output": 0,     "cache_write": 0,     "cache_read": 0},
  "unknown": {"input": 5.0,  "output": 25.00, "cache_write": 6.25,  "cache_read": 0.50},
}
PRICING = DEFAULT_PRICING
override_path = os.path.join(home, ".superagent", "cost", "pricing.json")
if os.path.exists(override_path):
  try:
    with open(override_path) as f:
      override = json.load(f)
    if isinstance(override, dict) and override:
      for tier, dims in override.items():
        if tier in PRICING and isinstance(dims, dict):
          PRICING[tier].update(dims)
  except Exception:
    pass

LOCAL_MARKERS = ('local', 'ollama', 'llamacpp', 'lmstudio', 'qwen', 'deepseek', 'minimax')

def bucket(model_str: str) -> str:
    m = (model_str or '').lower()
    if any(marker in m for marker in LOCAL_MARKERS):
        return 'local'
    for k in ('opus', 'sonnet', 'haiku'):
        if k in m:
            return k
    return 'unknown'

def record_usd(rec) -> float:
    tier = bucket(rec.get('model', ''))
    p = PRICING.get(tier, PRICING['unknown'])
    if 'input_tokens' in rec:
      # v2 schema
      i = int(rec.get('input_tokens', 0) or 0)
      o = int(rec.get('output_tokens', 0) or 0)
      cw = int(rec.get('cache_write_tokens', 0) or 0)
      cr = int(rec.get('cache_read_tokens', 0) or 0)
      return (i*p['input'] + o*p['output'] + cw*p['cache_write'] + cr*p['cache_read']) / 1_000_000
    # v1 schema — treat `tokens` as output_tokens only (conservative; SDK historically reported completion tokens here)
    t = int(rec.get('tokens', 0) or 0)
    return t * p['output'] / 1_000_000

agg_tokens = collections.Counter()  # by tier (for table)
agg_usd = collections.defaultdict(float)
recent_429_count = 0
for line in open(path):
    line = line.strip()
    if not line:
        continue
    try:
        r = json.loads(line)
        t = datetime.datetime.fromisoformat(r['ts'])
        if t < cutoff:
            continue
        tier = bucket(r.get('model', ''))
        # token sum: prefer v2 fields, fall back to v1
        if 'input_tokens' in r:
          tot = sum(int(r.get(k, 0) or 0) for k in ('input_tokens','output_tokens','cache_write_tokens','cache_read_tokens'))
        else:
          tot = int(r.get('tokens', 0) or 0)
        agg_tokens[tier] += tot
        agg_usd[tier] += record_usd(r)
        if r.get('http_status') == 429 and (now - t).total_seconds() <= 60:
            recent_429_count += 1
    except Exception:
        continue

total = sum(agg_usd.values())
by_model = {tier: {"tokens": agg_tokens[tier], "usd": round(agg_usd[tier], 4)} for tier in agg_tokens}

plan_limit = float(os.environ.get('SUPERAGENT_PLAN_LIMIT_USD', '20'))
pct_of_plan = (total / plan_limit) if plan_limit > 0 else 0

# 5h-reset estimate (unchanged from v1)
time_to_5h_reset = 300
try:
    five_h_ago = now - datetime.timedelta(hours=5)
    oldest_in_window = None
    for line in open(path):
        try:
            r = json.loads(line)
            t = datetime.datetime.fromisoformat(r['ts'])
            if t >= five_h_ago and (oldest_in_window is None or t < oldest_in_window):
                oldest_in_window = t
        except Exception:
            continue
    if oldest_in_window is not None:
        delta = (oldest_in_window + datetime.timedelta(hours=5) - now).total_seconds() / 60
        time_to_5h_reset = max(0, int(delta))
except Exception:
    pass

if json_mode:
    out = {
        "range": rng,
        "total_usd": round(total, 4),
        "by_model": by_model,
        "pct_of_plan": round(pct_of_plan, 4),
        "time_to_5h_reset_minutes": time_to_5h_reset,
        "recent_429_count_60s": recent_429_count,
        "plan_limit_usd": plan_limit,
        "pricing_version": "2026-Q2",
    }
    print(json.dumps(out))
    sys.exit(0)

if sum(agg_tokens.values()) == 0:
    print(f"no records in range: {rng}")
    sys.exit(0)

print(f"{'model':8} {'tokens':>12}  {'$':>8}")
print('-' * 32)
for m in ('opus', 'sonnet', 'haiku', 'local', 'unknown'):
    tok = agg_tokens.get(m, 0)
    if tok == 0:
        continue
    print(f"{m:8} {tok:>12,}  ${agg_usd[m]:>7.2f}")
print('-' * 32)
print(f"{'TOTAL':8} {sum(agg_tokens.values()):>12,}  ${total:>7.2f}")

opus = agg_tokens.get('opus', 0)
haiku = agg_tokens.get('haiku', 0)
local = agg_tokens.get('local', 0)
if opus > 500_000 and haiku < 100_000 and local < 100_000:
    print()
    print("Coach: heavy Opus use — try /effort low, Haiku, or local model for simple tasks.")
elif opus == 0 and haiku > 1_000_000:
    print()
    print("Coach: all-Haiku — try Sonnet for non-trivial reasoning.")
PY
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-cost-v2.sh
```

Expected: `test-cost-v2: PASS`

- [ ] **Step 5: Commit**

```bash
git add bin/superagent-cost test/test-cost-v2.sh
git commit -m "feat(cost): 4-dim pricing schema (input/output/cache_write/cache_read) + v1 auto-detect"
```

---

## Task 3: Tracker.sh — write v2 records

**Files:**
- Modify: `hooks/superagent-tracker.sh` (extract 4-dim usage from PostToolUse stdin, write v2 record)
- Test: `test/test-tracker-v2.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-tracker-v2.sh`:

```bash
#!/usr/bin/env bash
# test/test-tracker-v2.sh — tracker.sh writes v2 schema record from a Bash payload with usage info
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRACKER="$SCRIPT_DIR/../hooks/superagent-tracker.sh"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/cost" "$TMPHOME/.claude"

PAYLOAD='{
  "tool_name":"Bash",
  "tool_input":{"command":"graphify path A B"},
  "tool_response":{
    "output":"hello world",
    "usage":{
      "input_tokens":12000,
      "output_tokens":4500,
      "cache_creation_input_tokens":2000,
      "cache_read_input_tokens":8000
    }
  }
}'

HOME="$TMPHOME" CLAUDE_MODEL="claude-sonnet-4-5" bash "$TRACKER" <<<"$PAYLOAD" || true

CALLS="$TMPHOME/.superagent/cost/calls.jsonl"
[[ -s "$CALLS" ]] || { echo "FAIL: calls.jsonl empty"; rm -rf "$TMPHOME"; exit 1; }

LAST=$(tail -n1 "$CALLS")
echo "$LAST" | jq -e '.input_tokens == 12000 and .output_tokens == 4500 and .cache_write_tokens == 2000 and .cache_read_tokens == 8000 and .pricing_version == "2026-Q2"' >/dev/null \
  || { echo "FAIL: v2 fields not present in $LAST"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-tracker-v2: PASS"
```

```bash
chmod +x test/test-tracker-v2.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-tracker-v2.sh
```

Expected: `FAIL: v2 fields not present` (current tracker writes only `tokens`).

- [ ] **Step 3: Modify tracker.sh — write v2 records**

In `hooks/superagent-tracker.sh`, find both cost-log emission blocks (one in the non-Bash branch, one at the bottom of the Bash branch — search for `"# Per-call cost log"` and `"Non-Bash tools: estimate tokens"`).

Replace **both** emission blocks with this shared body. Define this helper near the top of the file (after `log()`):

```bash
# Extract 4-dim usage from a tool_response.usage subobject. Falls back to v1 estimate.
emit_cost_record() {
  local payload="$1"   # full PostToolUse JSON payload
  local tool_name="$2"
  local project="$3"
  local fallback_estimate="$4"  # v1 token estimate to use if usage absent

  local usage in_t out_t cw_t cr_t
  usage=$(echo "$payload" | jq -c '.tool_response.usage // null' 2>/dev/null || echo "null")

  if [[ "$usage" != "null" && -n "$usage" ]]; then
    in_t=$(echo "$usage" | jq -r '.input_tokens // 0')
    out_t=$(echo "$usage" | jq -r '.output_tokens // 0')
    cw_t=$(echo "$usage" | jq -r '.cache_creation_input_tokens // 0')
    cr_t=$(echo "$usage" | jq -r '.cache_read_input_tokens // 0')
  else
    # v1 fallback: treat the response-size estimate as output_tokens
    in_t=0
    out_t="${fallback_estimate:-0}"
    cw_t=0
    cr_t=0
  fi

  local task_id
  task_id="${SA_TRACE_ID:-}"
  if [[ -z "$task_id" ]]; then
    task_id=$(printf '%s%s' "$(date +%s%N 2>/dev/null || date +%s)" "$tool_name" \
      | (shasum -a 256 2>/dev/null || sha256sum 2>/dev/null) | cut -c1-8)
  fi

  local cost_file="$HOME/.superagent/cost/calls.jsonl"
  mkdir -p "$(dirname "$cost_file")" 2>/dev/null || true
  {
    printf '%s' "{"
    printf '"ts":"%s",' "$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)"
    printf '"project":"%s",' "${project:-unknown}"
    printf '"tool":"%s",' "$tool_name"
    printf '"model":"%s",' "${CLAUDE_MODEL:-unknown}"
    printf '"input_tokens":%s,' "${in_t:-0}"
    printf '"output_tokens":%s,' "${out_t:-0}"
    printf '"cache_write_tokens":%s,' "${cw_t:-0}"
    printf '"cache_read_tokens":%s,' "${cr_t:-0}"
    printf '"task_id":"%s",' "$task_id"
    printf '"http_status":200,'
    printf '"pricing_version":"2026-Q2"'
    printf '}\n'
  } >> "$cost_file" 2>/dev/null || true
}
```

Then update the two existing emission sites:

**Non-Bash branch** — replace the existing `# Non-Bash tools: estimate tokens from response size...` block (the inline `printf` cost-log emission) with:

```bash
if [[ "$TOOL_NAME" != "Bash" ]]; then
  RESP_BYTES=$(echo "$PAYLOAD" | jq -r '(.tool_response | tostring) | length' 2>/dev/null || echo 0)
  SYN_TOKENS=$(( ${RESP_BYTES:-0} / 4 ))
  emit_cost_record "$PAYLOAD" "$TOOL_NAME" "${PWD:-unknown}" "$SYN_TOKENS"
  exit 0
fi
```

**Bash branch (bottom of file)** — replace the existing `# Per-call cost log (Task 5.3)` block:

```bash
# Per-call cost log (Wave 1 v2 schema)
emit_cost_record "$PAYLOAD" "$TOOL_NAME" "${PROJECT:-unknown}" "${RESPONSE_TOKENS:-0}"

exit 0
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-tracker-v2.sh
```

Expected: `test-tracker-v2: PASS`

- [ ] **Step 5: Commit**

```bash
git add hooks/superagent-tracker.sh test/test-tracker-v2.sh
git commit -m "feat(tracker): emit v2 calls.jsonl records (4-dim tokens + task_id + pricing_version)"
```

---

## Task 4: Cost — budget alerts + auto-downgrade.flag

**Files:**
- Create: `bin/superagent-cost-alerts` (separate small bin to avoid bloating superagent-cost; called from hooks/cron)
- Test: `test/test-cost-alerts.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-cost-alerts.sh`:

```bash
#!/usr/bin/env bash
# test/test-cost-alerts.sh — alerts emit at threshold crossings; flag drops at 0.9
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALERTS_BIN="$SCRIPT_DIR/../bin/superagent-cost-alerts"
COST_BIN="$SCRIPT_DIR/../bin/superagent-cost"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/cost"

# Budget = $20/day, target downgrade at 90%
cat > "$TMPHOME/.superagent/cost/budget.json" <<'JSON'
{"daily_usd":20,"monthly_usd":400,"alert_thresholds":[0.5,0.75,0.9,1.0],
 "auto_downgrade":{"at":0.9,"target":"sonnet"},"hard_stop":{"at":1.0,"mode":"prompt"}}
JSON

# v2 record worth $19.20 (96% of budget): output_tokens=1.28M @ $15/M = $19.20
TS=$(date -u -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/cost/calls.jsonl" <<JSONL
{"ts":"$TS","project":"/x","tool":"Bash","model":"sonnet","input_tokens":0,"output_tokens":1280000,"cache_write_tokens":0,"cache_read_tokens":0,"task_id":"t","http_status":200,"pricing_version":"2026-Q2"}
JSONL

HOME="$TMPHOME" PATH="$SCRIPT_DIR/../bin:$PATH" "$ALERTS_BIN" >/dev/null

# Alert at 90% should be appended
LATEST=$(tail -n1 "$TMPHOME/.superagent/cost/alerts.jsonl")
echo "$LATEST" | jq -e '.level == "critical" and .pct >= 0.9' >/dev/null \
  || { echo "FAIL: critical alert not emitted: $LATEST"; rm -rf "$TMPHOME"; exit 1; }

# Auto-downgrade.flag should be present and contain target=sonnet
[[ -f "$TMPHOME/.superagent/auto-downgrade.flag" ]] || { echo "FAIL: auto-downgrade.flag missing"; rm -rf "$TMPHOME"; exit 1; }
grep -q "sonnet" "$TMPHOME/.superagent/auto-downgrade.flag" || { echo "FAIL: flag missing target"; rm -rf "$TMPHOME"; exit 1; }

# Idempotency: running again should not duplicate the same threshold-tier alert
HOME="$TMPHOME" PATH="$SCRIPT_DIR/../bin:$PATH" "$ALERTS_BIN" >/dev/null
COUNT=$(grep -c '"level":"critical"' "$TMPHOME/.superagent/cost/alerts.jsonl" || echo 0)
[[ "$COUNT" -eq 1 ]] || { echo "FAIL: critical alert duplicated (count=$COUNT)"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-cost-alerts: PASS"
```

```bash
chmod +x test/test-cost-alerts.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-cost-alerts.sh
```

Expected: `bash: bin/superagent-cost-alerts: No such file` (or exec failure).

- [ ] **Step 3: Implement cost-alerts bin**

Create `bin/superagent-cost-alerts`:

```bash
#!/usr/bin/env bash
# superagent-cost-alerts — emit threshold-crossing alerts and drop auto-downgrade.flag.
# Idempotent: same threshold-tier alert is only appended once per session/day.
set -euo pipefail
ROOT="$HOME/.superagent"
BUDGET="$ROOT/cost/budget.json"
ALERTS="$ROOT/cost/alerts.jsonl"
FLAG="$ROOT/auto-downgrade.flag"
COST_BIN="$(dirname "$0")/superagent-cost"

[[ -f "$BUDGET" ]] || { echo "no budget config (expected $BUDGET)" >&2; exit 0; }
[[ -x "$COST_BIN" ]] || COST_BIN="superagent-cost"

mkdir -p "$(dirname "$ALERTS")"

DATA=$("$COST_BIN" today --json)
USED=$(echo "$DATA" | jq -r '.total_usd // 0')

python3 - "$DATA" "$BUDGET" "$ALERTS" "$FLAG" <<'PY'
import json, sys, os, datetime
data = json.loads(sys.argv[1])
budget = json.load(open(sys.argv[2]))
alerts_path = sys.argv[3]
flag_path = sys.argv[4]

used = float(data.get('total_usd', 0))
daily = float(budget.get('daily_usd', 20))
pct = used / daily if daily > 0 else 0
thresholds = budget.get('alert_thresholds', [0.5, 0.75, 0.9, 1.0])
levels = ['info', 'warning', 'critical', 'hard_stop']

# Determine highest threshold crossed
crossed_idx = -1
for i, t in enumerate(thresholds):
    if pct >= t:
        crossed_idx = i

if crossed_idx == -1:
    sys.exit(0)

level = levels[crossed_idx] if crossed_idx < len(levels) else f'tier-{crossed_idx}'
today = datetime.date.today().isoformat()

# Idempotency: don't re-emit if same level already exists today
already_emitted = False
if os.path.exists(alerts_path):
    for line in open(alerts_path):
        try:
            r = json.loads(line.strip())
            if r.get('level') == level and r.get('ts', '').startswith(today):
                already_emitted = True
                break
        except Exception:
            continue

if not already_emitted:
    rec = {
        'ts': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'level': level,
        'pct': round(pct, 4),
        'used_usd': round(used, 4),
        'budget_usd': daily,
        'action': 'suggest-downgrade' if level in ('warning', 'critical') else ('halt-prompt' if level == 'hard_stop' else 'log'),
    }
    with open(alerts_path, 'a') as f:
        f.write(json.dumps(rec) + '\n')

# Auto-downgrade flag at >=0.9
ad = budget.get('auto_downgrade', {})
ad_at = float(ad.get('at', 0.9))
ad_target = ad.get('target', 'sonnet')
if pct >= ad_at:
    with open(flag_path, 'w') as f:
        f.write(ad_target + '\n')
elif os.path.exists(flag_path):
    # Recovered below threshold — clear flag so auto-fallback resumes
    try:
        os.remove(flag_path)
    except OSError:
        pass
PY
```

```bash
chmod +x bin/superagent-cost-alerts
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-cost-alerts.sh
```

Expected: `test-cost-alerts: PASS`

- [ ] **Step 5: Commit**

```bash
git add bin/superagent-cost-alerts test/test-cost-alerts.sh
git commit -m "feat(cost): budget alerts + auto-downgrade.flag at 0.9 threshold"
```

---

## Task 5: auto-fallback skill — honor downgrade flag

**Files:**
- Modify: `skills/auto-fallback/SKILL.md` (add a short section explaining downgrade.flag behavior)
- Test: `test/test-auto-fallback-flag.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-auto-fallback-flag.sh`:

```bash
#!/usr/bin/env bash
# test/test-auto-fallback-flag.sh — SKILL.md mentions downgrade flag and shift behavior
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$SCRIPT_DIR/../skills/auto-fallback/SKILL.md"

grep -q 'auto-downgrade.flag' "$SKILL" || { echo "FAIL: SKILL.md missing 'auto-downgrade.flag'"; exit 1; }
grep -qE 'Opus.+Sonnet|Sonnet.+Haiku|in-Anthropic tier' "$SKILL" || { echo "FAIL: SKILL.md missing tier-shift wording"; exit 1; }
echo "test-auto-fallback-flag: PASS"
```

```bash
chmod +x test/test-auto-fallback-flag.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-auto-fallback-flag.sh
```

Expected: `FAIL: SKILL.md missing 'auto-downgrade.flag'`.

- [ ] **Step 3: Modify auto-fallback SKILL.md**

Append the following section near the end of `skills/auto-fallback/SKILL.md` (before the final closing fence/section):

```markdown

## In-Anthropic tier shift (Wave 1)

In addition to swapping the *backend* (Anthropic ↔ local), the auto-fallback skill now honors **in-tier downgrades** within Anthropic when the cost-tracker drops `~/.superagent/auto-downgrade.flag`.

### Trigger

`bin/superagent-cost-alerts` writes `~/.superagent/auto-downgrade.flag` containing a single token (e.g. `sonnet` or `haiku`) when daily spend crosses the budget's `auto_downgrade.at` threshold (default 0.9).

### Action when flag present

1. Read the flag file: `cat ~/.superagent/auto-downgrade.flag`.
2. If the current model is **higher tier** than the flag target (Opus → Sonnet, or Sonnet → Haiku), recommend or auto-perform the in-tier shift.
3. Announce the shift (`Backend: anthropic:<old-tier> → anthropic:<new-tier>  Reason: budget at 90%`).
4. The flag is cleared automatically by `superagent-cost-alerts` when usage drops below the threshold (e.g. after the 5h reset window).

### Precedence with other guards

When multiple shift signals fire simultaneously, apply in order: **budget > rate-limit > preference**. Budget downgrade beats a user preference for Opus; rate-limit (429) override beats both for the duration of the rate window.
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-auto-fallback-flag.sh
```

Expected: `test-auto-fallback-flag: PASS`.

- [ ] **Step 5: Commit**

```bash
git add skills/auto-fallback/SKILL.md test/test-auto-fallback-flag.sh
git commit -m "feat(auto-fallback): honor auto-downgrade.flag for in-Anthropic tier shifts"
```

---

## Task 6: Patterns — bin scaffolding + `list` subcommand

**Files:**
- Create: `bin/superagent-patterns`
- Test: `test/test-patterns.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-patterns.sh`:

```bash
#!/usr/bin/env bash
# test/test-patterns.sh — bin/superagent-patterns scaffolding (list, promote, decay, protect, prune)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATBIN="$SCRIPT_DIR/../bin/superagent-patterns"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/brain"
: > "$TMPHOME/.superagent/brain/patterns.jsonl"

# 1. list on empty store → 0 records
OUT=$(HOME="$TMPHOME" "$PATBIN" list --json)
COUNT=$(echo "$OUT" | jq '.count')
[[ "$COUNT" == "0" ]] || { echo "FAIL: empty list count=$COUNT, want 0"; rm -rf "$TMPHOME"; exit 1; }

# 2. list --help exits 0 and prints usage
HOME="$TMPHOME" "$PATBIN" --help | grep -q "Usage:" || { echo "FAIL: --help missing Usage:"; rm -rf "$TMPHOME"; exit 1; }

# 3. unknown subcommand exits 2
HOME="$TMPHOME" "$PATBIN" wat 2>/dev/null && { echo "FAIL: unknown subcommand should fail"; rm -rf "$TMPHOME"; exit 1; } || true

rm -rf "$TMPHOME"
echo "test-patterns(scaffolding): PASS"
```

```bash
chmod +x test/test-patterns.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-patterns.sh
```

Expected: `bin/superagent-patterns: No such file`.

- [ ] **Step 3: Create the scaffold bin**

Create `bin/superagent-patterns`:

```bash
#!/usr/bin/env bash
# superagent-patterns — pattern store CLI for the SuperAgent learning loop.
# Subcommands: list, promote, decay, protect, prune.
set -euo pipefail

ROOT="$HOME/.superagent/brain"
PATTERNS="$ROOT/patterns.jsonl"
PROTECTED="$ROOT/protected-patterns.jsonl"
ROUTES="$ROOT/routes.jsonl"

usage() {
  cat <<EOF
Usage: superagent-patterns <subcommand> [flags]

Subcommands:
  list [--json]            List all stored patterns.
  promote                  Scan routes.jsonl for repeated done-routes (>=3)
                           and (re)write pattern records.
  decay                    Apply exponential confidence decay to all patterns.
  protect <pattern-id>     Flip protected:true on the matching pattern.
  prune [--below RATE]     Remove unprotected patterns below RATE (default 0.1).

Files:
  $PATTERNS         (current store)
  $PROTECTED   (manual protect list)
  $ROUTES             (source data for promote)
EOF
}

mkdir -p "$ROOT" 2>/dev/null || true
[[ -f "$PATTERNS" ]]  || : > "$PATTERNS"
[[ -f "$PROTECTED" ]] || : > "$PROTECTED"
[[ -f "$ROUTES" ]]    || : > "$ROUTES"

cmd="${1:-}"
case "$cmd" in
  -h|--help|"")
    usage; exit 0
    ;;
  list)
    json=0
    [[ "${2:-}" == "--json" ]] && json=1
    if [[ $json -eq 1 ]]; then
      jq -sc '{count: length, patterns: .}' "$PATTERNS" 2>/dev/null || echo '{"count":0,"patterns":[]}'
    else
      printf '%-12s %-8s %-6s %-22s %s\n' ID SUCC USES SIGNAL CHAIN
      jq -r '"\(.id)\t\(.successRate)\t\(.useCount)\t\(.signal)\t\(.chain | join(","))"' "$PATTERNS" 2>/dev/null \
        | awk -F'\t' '{ printf "%-12s %-8s %-6s %-22s %s\n", $1, $2, $3, $4, $5 }'
    fi
    ;;
  promote|decay|protect|prune)
    # delegated to subsequent tasks — placeholder until implemented
    echo "subcommand '$cmd' not yet implemented" >&2
    exit 3
    ;;
  *)
    echo "unknown subcommand: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
```

```bash
chmod +x bin/superagent-patterns
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-patterns.sh
```

Expected: `test-patterns(scaffolding): PASS`.

- [ ] **Step 5: Commit**

```bash
git add bin/superagent-patterns test/test-patterns.sh
git commit -m "feat(patterns): scaffold superagent-patterns bin (list + help)"
```

---

## Task 7: Patterns — `promote`

**Files:**
- Modify: `bin/superagent-patterns` (implement `promote`)
- Test: `test/test-patterns-promote.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-patterns-promote.sh`:

```bash
#!/usr/bin/env bash
# test/test-patterns-promote.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATBIN="$SCRIPT_DIR/../bin/superagent-patterns"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/brain"
: > "$TMPHOME/.superagent/brain/patterns.jsonl"

# 3 routes with same chain → should produce 1 pattern record after promote
TS=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/brain/routes.jsonl" <<JSONL
{"ts":"$TS","task_hash":"abc","task":"fix bug in dark mode toggle","chain":["systematic-debugging","tdd"],"outcome":"done","backend":"anthropic"}
{"ts":"$TS","task_hash":"abc","task":"fix bug in dark mode toggle","chain":["systematic-debugging","tdd"],"outcome":"done","backend":"anthropic"}
{"ts":"$TS","task_hash":"abc","task":"fix bug in dark mode toggle","chain":["systematic-debugging","tdd"],"outcome":"done","backend":"anthropic"}
{"ts":"$TS","task_hash":"def","task":"this one should be ignored — only 1 occurrence","chain":["random"],"outcome":"done","backend":"anthropic"}
JSONL

HOME="$TMPHOME" "$PATBIN" promote >/dev/null

LINES=$(wc -l < "$TMPHOME/.superagent/brain/patterns.jsonl" | tr -d ' ')
[[ "$LINES" == "1" ]] || { echo "FAIL: expected 1 pattern, got $LINES"; cat "$TMPHOME/.superagent/brain/patterns.jsonl"; rm -rf "$TMPHOME"; exit 1; }

REC=$(cat "$TMPHOME/.superagent/brain/patterns.jsonl")
echo "$REC" | jq -e '.useCount == 3 and .successRate >= 0.59 and (.chain == ["systematic-debugging","tdd"])' >/dev/null \
  || { echo "FAIL: pattern record shape wrong: $REC"; rm -rf "$TMPHOME"; exit 1; }

# Idempotency — running again should NOT duplicate; useCount stays at 3 (same routes, no new evidence)
HOME="$TMPHOME" "$PATBIN" promote >/dev/null
LINES2=$(wc -l < "$TMPHOME/.superagent/brain/patterns.jsonl" | tr -d ' ')
[[ "$LINES2" == "1" ]] || { echo "FAIL: dedup broken on second run, got $LINES2 lines"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-patterns-promote: PASS"
```

```bash
chmod +x test/test-patterns-promote.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-patterns-promote.sh
```

Expected: `subcommand 'promote' not yet implemented` → `FAIL`.

- [ ] **Step 3: Implement `promote`**

In `bin/superagent-patterns`, replace the `promote|decay|protect|prune)` placeholder branch. Add this dedicated block, in this order (decay/protect/prune still placeholders):

```bash
  promote)
    python3 - "$ROUTES" "$PATTERNS" <<'PY'
import json, sys, hashlib, datetime, collections, os

routes_path = sys.argv[1]
patterns_path = sys.argv[2]

# Tunables (mirror defaults.toml)
PROMOTE_MIN_USES = int(os.environ.get('SUPERAGENT_LEARNING_PROMOTE_MIN_USES', '3'))
INITIAL_SUCCESS_RATE = 0.6   # neutral start; decay/boost from there

def signal_from_task(task: str) -> str:
    # Crude signal extraction — meaningful nouns/verbs only.
    # Lowercase, strip punctuation, drop stopwords, dedupe, alpha-sort, join.
    import re
    STOP = set("a an the is are was were be being been do does did has have had this that these those it i you we they to from in on at of for with by".split())
    words = re.findall(r"[a-z0-9]+", (task or '').lower())
    meaningful = [w for w in words if w not in STOP and len(w) >= 3]
    return " ".join(sorted(set(meaningful))[:8])

def pattern_id(signal, chain):
    h = hashlib.sha256()
    h.update(signal.encode())
    h.update(b"|")
    h.update(",".join(chain).encode())
    return "p-" + h.hexdigest()[:8]

# Load existing patterns
existing = {}
if os.path.exists(patterns_path):
    with open(patterns_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
                existing[r['id']] = r
            except Exception:
                continue

# Aggregate done-routes by (signal, chain)
agg = collections.Counter()
last_seen = {}
if os.path.exists(routes_path):
    with open(routes_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except Exception:
                continue
            if r.get('outcome') != 'done':
                continue
            chain = r.get('chain') or []
            if not chain:
                continue
            signal = signal_from_task(r.get('task', ''))
            key = (signal, tuple(chain))
            agg[key] += 1
            last_seen[key] = r.get('ts', '')

# Emit / update patterns where count >= threshold
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
for (signal, chain), count in agg.items():
    if count < PROMOTE_MIN_USES:
        continue
    pid = pattern_id(signal, list(chain))
    rec = existing.get(pid, {
        'id': pid,
        'kind': 'task-routing',
        'signal': signal,
        'chain': list(chain),
        'successRate': INITIAL_SUCCESS_RATE,
        'useCount': 0,
        'lastUsed': now,
        'protected': False,
    })
    # Reflect new evidence: clamp useCount to observed count, bump successRate by 0.03 per *new* use up to 1.0
    delta_uses = max(0, count - rec.get('useCount', 0))
    if delta_uses > 0:
      rec['useCount'] = count
      rec['successRate'] = min(1.0, rec.get('successRate', INITIAL_SUCCESS_RATE) + 0.03 * delta_uses)
      rec['lastUsed'] = last_seen.get((signal, chain)) or now
    existing[pid] = rec

# Persist atomically — overwrite (dedup by id implicit)
tmp = patterns_path + ".tmp"
with open(tmp, 'w') as f:
    for r in existing.values():
        f.write(json.dumps(r) + "\n")
os.replace(tmp, patterns_path)
PY
    ;;

  decay|protect|prune)
    echo "subcommand '$cmd' not yet implemented" >&2
    exit 3
    ;;
```

(Remove the previous combined `promote|decay|protect|prune)` placeholder branch; keep `*` last.)

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-patterns-promote.sh
```

Expected: `test-patterns-promote: PASS`.

- [ ] **Step 5: Commit**

```bash
git add bin/superagent-patterns test/test-patterns-promote.sh
git commit -m "feat(patterns): promote — emit/update pattern records from repeated done-routes"
```

---

## Task 8: Patterns — `decay`

**Files:**
- Modify: `bin/superagent-patterns` (implement `decay`)
- Test: `test/test-patterns-decay.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-patterns-decay.sh`:

```bash
#!/usr/bin/env bash
# test/test-patterns-decay.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATBIN="$SCRIPT_DIR/../bin/superagent-patterns"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/brain"

# Three patterns: one with old lastUsed, one already below 0.1, one protected at 0.05
OLD=$(python3 -c "import datetime; print((datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=24)).isoformat())")
NEW=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

cat > "$TMPHOME/.superagent/brain/patterns.jsonl" <<JSONL
{"id":"p-aaaa","kind":"task-routing","signal":"x y","chain":["a","b"],"successRate":0.80,"useCount":10,"lastUsed":"$OLD","protected":false}
{"id":"p-bbbb","kind":"task-routing","signal":"y z","chain":["c"],"successRate":0.05,"useCount":3,"lastUsed":"$NEW","protected":false}
{"id":"p-cccc","kind":"task-routing","signal":"q r","chain":["d"],"successRate":0.05,"useCount":3,"lastUsed":"$NEW","protected":true}
JSONL

HOME="$TMPHOME" "$PATBIN" decay >/dev/null

# p-aaaa: 0.80 * exp(-0.005 * 24) = 0.80 * 0.8869 ≈ 0.71
PA=$(grep '"p-aaaa"' "$TMPHOME/.superagent/brain/patterns.jsonl" | jq -r '.successRate')
PASS=$(python3 -c "print(0.69 < $PA < 0.73)")
[[ "$PASS" == "True" ]] || { echo "FAIL: p-aaaa successRate=$PA out of range (0.69, 0.73)"; rm -rf "$TMPHOME"; exit 1; }

# p-bbbb: dropped (below 0.1, unprotected)
grep -q '"p-bbbb"' "$TMPHOME/.superagent/brain/patterns.jsonl" \
  && { echo "FAIL: p-bbbb should have been pruned"; rm -rf "$TMPHOME"; exit 1; } || true

# p-cccc: floored at 0.3 (protected)
PC=$(grep '"p-cccc"' "$TMPHOME/.superagent/brain/patterns.jsonl" | jq -r '.successRate')
PASS_C=$(python3 -c "print($PC >= 0.30 - 0.001)")
[[ "$PASS_C" == "True" ]] || { echo "FAIL: p-cccc not floored at 0.3 (got $PC)"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-patterns-decay: PASS"
```

```bash
chmod +x test/test-patterns-decay.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-patterns-decay.sh
```

Expected: `subcommand 'decay' not yet implemented`.

- [ ] **Step 3: Implement `decay`**

In `bin/superagent-patterns`, replace the `decay|protect|prune)` placeholder. Add the `decay)` branch above the `protect|prune)` placeholder:

```bash
  decay)
    python3 - "$PATTERNS" <<'PY'
import json, sys, datetime, math, os

path = sys.argv[1]
DECAY_PER_HOUR = float(os.environ.get('SUPERAGENT_LEARNING_DECAY_RATE_PER_HOUR', '0.005'))
MIN_CONF = float(os.environ.get('SUPERAGENT_LEARNING_MIN_CONFIDENCE', '0.1'))
PROTECTED_FLOOR = float(os.environ.get('SUPERAGENT_LEARNING_PROTECTED_FLOOR', '0.3'))

now = datetime.datetime.now(datetime.timezone.utc)

records = []
if os.path.exists(path):
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except Exception:
                continue

kept = []
for r in records:
    sr = float(r.get('successRate', 0))
    last_used = r.get('lastUsed') or now.isoformat()
    try:
        t = datetime.datetime.fromisoformat(last_used)
    except Exception:
        t = now
    hours = max(0.0, (now - t).total_seconds() / 3600.0)
    sr_decayed = sr * math.exp(-DECAY_PER_HOUR * hours)

    if r.get('protected'):
        sr_decayed = max(sr_decayed, PROTECTED_FLOOR)
        r['successRate'] = round(sr_decayed, 4)
        kept.append(r)
        continue

    if sr_decayed < MIN_CONF:
        # prune
        continue

    r['successRate'] = round(sr_decayed, 4)
    kept.append(r)

tmp = path + ".tmp"
with open(tmp, 'w') as f:
    for r in kept:
        f.write(json.dumps(r) + "\n")
os.replace(tmp, path)
PY
    ;;
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-patterns-decay.sh
```

Expected: `test-patterns-decay: PASS`.

- [ ] **Step 5: Commit**

```bash
git add bin/superagent-patterns test/test-patterns-decay.sh
git commit -m "feat(patterns): decay — exponential confidence decay + protected floor + prune below 0.1"
```

---

## Task 9: Patterns — `protect` + `prune`

**Files:**
- Modify: `bin/superagent-patterns` (implement `protect`, `prune`)
- Test: `test/test-patterns-protect-prune.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-patterns-protect-prune.sh`:

```bash
#!/usr/bin/env bash
# test/test-patterns-protect-prune.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATBIN="$SCRIPT_DIR/../bin/superagent-patterns"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/brain"
NEW=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/brain/patterns.jsonl" <<JSONL
{"id":"p-1111","signal":"a","chain":["x"],"successRate":0.45,"useCount":4,"lastUsed":"$NEW","protected":false}
{"id":"p-2222","signal":"b","chain":["y"],"successRate":0.20,"useCount":2,"lastUsed":"$NEW","protected":false}
JSONL

# 1. protect by id
HOME="$TMPHOME" "$PATBIN" protect p-1111 >/dev/null
PROT=$(grep '"p-1111"' "$TMPHOME/.superagent/brain/patterns.jsonl" | jq -r '.protected')
[[ "$PROT" == "true" ]] || { echo "FAIL: protect did not flip protected:true (got $PROT)"; rm -rf "$TMPHOME"; exit 1; }

# 2. prune --below 0.5 → drops p-2222 (0.20) but keeps p-1111 (now protected)
HOME="$TMPHOME" "$PATBIN" prune --below 0.5 >/dev/null
LINES=$(wc -l < "$TMPHOME/.superagent/brain/patterns.jsonl" | tr -d ' ')
[[ "$LINES" == "1" ]] || { echo "FAIL: prune kept $LINES lines, want 1"; cat "$TMPHOME/.superagent/brain/patterns.jsonl"; rm -rf "$TMPHOME"; exit 1; }
grep -q '"p-1111"' "$TMPHOME/.superagent/brain/patterns.jsonl" || { echo "FAIL: protected p-1111 was pruned"; rm -rf "$TMPHOME"; exit 1; }

# 3. protect with bogus id exits 1
HOME="$TMPHOME" "$PATBIN" protect p-zzzz 2>/dev/null && { echo "FAIL: bogus protect should exit !=0"; rm -rf "$TMPHOME"; exit 1; } || true

rm -rf "$TMPHOME"
echo "test-patterns-protect-prune: PASS"
```

```bash
chmod +x test/test-patterns-protect-prune.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-patterns-protect-prune.sh
```

Expected: `subcommand 'protect' not yet implemented`.

- [ ] **Step 3: Implement `protect` and `prune`**

In `bin/superagent-patterns`, replace the `protect|prune)` placeholder branch with:

```bash
  protect)
    pid="${2:-}"
    [[ -z "$pid" ]] && { echo "Usage: superagent-patterns protect <pattern-id>" >&2; exit 1; }
    python3 - "$PATTERNS" "$pid" <<'PY'
import json, sys, os
path, pid = sys.argv[1], sys.argv[2]
records = []
hit = False
if os.path.exists(path):
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                r = json.loads(line)
                if r.get('id') == pid:
                    r['protected'] = True
                    hit = True
                records.append(r)
            except Exception:
                continue
if not hit:
    sys.stderr.write(f"no pattern with id '{pid}' found\n")
    sys.exit(1)
tmp = path + ".tmp"
with open(tmp, 'w') as f:
    for r in records:
        f.write(json.dumps(r) + "\n")
os.replace(tmp, path)
PY
    ;;
  prune)
    threshold="0.1"
    if [[ "${2:-}" == "--below" ]]; then
      threshold="${3:-0.1}"
    fi
    python3 - "$PATTERNS" "$threshold" <<'PY'
import json, sys, os
path, thr = sys.argv[1], float(sys.argv[2])
records = []
if os.path.exists(path):
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                records.append(json.loads(line))
            except Exception:
                continue
kept = [r for r in records if r.get('protected') or float(r.get('successRate', 0)) >= thr]
tmp = path + ".tmp"
with open(tmp, 'w') as f:
    for r in kept:
        f.write(json.dumps(r) + "\n")
os.replace(tmp, path)
PY
    ;;
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-patterns-protect-prune.sh
```

Expected: `test-patterns-protect-prune: PASS`.

- [ ] **Step 5: Commit**

```bash
git add bin/superagent-patterns test/test-patterns-protect-prune.sh
git commit -m "feat(patterns): protect + prune subcommands"
```

---

## Task 10: Classifier reads patterns.jsonl

**Files:**
- Modify: `bin/superagent-classify` (read patterns.jsonl, prepend matched chain when gate met)
- Test: `test/test-classify-patterns.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-classify-patterns.sh`:

```bash
#!/usr/bin/env bash
# test/test-classify-patterns.sh — classifier prepends pattern chain when gate met
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CBIN="$SCRIPT_DIR/../bin/superagent-classify"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/brain"

NEW=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
# A "high-quality" pattern matching "kustomize" (a word the static rules.yaml does NOT cover) — should fire
# A "low-quality" pattern (successRate too low) — should NOT fire
cat > "$TMPHOME/.superagent/brain/patterns.jsonl" <<JSONL
{"id":"p-good","signal":"deploy kustomize overlay","chain":["pattern-from-store"],"successRate":0.85,"useCount":12,"lastUsed":"$NEW","protected":false}
{"id":"p-weak","signal":"floof bloop","chain":["should-not-fire"],"successRate":0.50,"useCount":3,"lastUsed":"$NEW","protected":false}
JSONL

# Pattern match: gate met → "pattern-from-store" appears in chain
OUT1=$(HOME="$TMPHOME" "$CBIN" "deploy kustomize overlay to staging")
echo "$OUT1" | jq -e '.chain | index("pattern-from-store") != null' >/dev/null \
  || { echo "FAIL: high-quality pattern not applied: $OUT1"; rm -rf "$TMPHOME"; exit 1; }

# Pattern match: gate NOT met → "should-not-fire" does NOT appear
OUT2=$(HOME="$TMPHOME" "$CBIN" "floof bloop")
echo "$OUT2" | jq -e '.chain | index("should-not-fire") == null' >/dev/null \
  || { echo "FAIL: weak pattern incorrectly applied: $OUT2"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-classify-patterns: PASS"
```

```bash
chmod +x test/test-classify-patterns.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-classify-patterns.sh
```

Expected: `FAIL: high-quality pattern not applied` (current classifier ignores patterns.jsonl).

- [ ] **Step 3: Modify `bin/superagent-classify`**

Locate the python heredoc inside `bin/superagent-classify`. Make these three changes inside the heredoc (the bash `python3 - "$TASK" "$RULES_FILE" "$HISTORY_HINT" <<'PYEOF'` block):

**3a.** After the existing `import` line, add `import os`:

```python
import sys
import json
import re
import os
import yaml
```

**3b.** After the `chain = list(always_first)` line and the rule-matching loop, but BEFORE the `# stable dedup` step, insert:

```python
# ── pattern store augmentation (Wave 1 learning loop) ──────────────────────
# Read ~/.superagent/brain/patterns.jsonl. If a pattern's signal-token overlap
# with the task is ≥1 AND successRate ≥ 0.6 AND useCount ≥ 5, prepend its chain
# (after always_first, before rule-matched skills).
PATTERNS_PATH = os.path.expanduser("~/.superagent/brain/patterns.jsonl")
GATE_SR = float(os.environ.get('SUPERAGENT_LEARNING_CLASSIFIER_GATE_SUCCESS_RATE', '0.6'))
GATE_USE = int(os.environ.get('SUPERAGENT_LEARNING_CLASSIFIER_GATE_USE_COUNT', '5'))

def _tokens(s: str) -> set:
    return set(re.findall(r"[a-z0-9]+", (s or "").lower()))

if os.path.exists(PATTERNS_PATH):
    task_tokens = _tokens(task)
    best = None
    best_score = 0.0
    with open(PATTERNS_PATH) as _pf:
        for _line in _pf:
            _line = _line.strip()
            if not _line:
                continue
            try:
                pat = json.loads(_line)
            except Exception:
                continue
            if float(pat.get('successRate', 0)) < GATE_SR:
                continue
            if int(pat.get('useCount', 0)) < GATE_USE:
                continue
            sig_tokens = _tokens(pat.get('signal', ''))
            if not sig_tokens:
                continue
            overlap = len(task_tokens & sig_tokens)
            if overlap == 0:
                continue
            score = overlap * float(pat.get('successRate', 0))
            if score > best_score:
                best_score = score
                best = pat
    if best is not None:
        # Prepend the pattern chain after always_first
        injected = list(best.get('chain', []))
        # Place pattern skills right after always_first (head of chain), before rule-matched
        prefix = list(always_first)
        rest = [c for c in chain if c not in prefix]
        chain = prefix + injected + rest
```

**3c.** No other changes — the existing dedup step handles duplicates introduced by the prepend.

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-classify-patterns.sh
```

Expected: `test-classify-patterns: PASS`.

Then run the existing classifier test to confirm no regression:

```bash
test/test-classify.sh
```

Expected: existing assertions still pass (no patterns.jsonl in test fixture → unchanged behavior).

- [ ] **Step 5: Commit**

```bash
git add bin/superagent-classify test/test-classify-patterns.sh
git commit -m "feat(classifier): read patterns.jsonl with successRate>=0.6 + useCount>=5 gate"
```

---

## Task 11: Stop hook — call promote+decay

**Files:**
- Modify: `hooks/superagent-distill.sh` (append patterns promote+decay invocation)
- Test: `test/test-distill-patterns.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-distill-patterns.sh`:

```bash
#!/usr/bin/env bash
# test/test-distill-patterns.sh — Stop hook calls patterns promote+decay
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTILL="$SCRIPT_DIR/../hooks/superagent-distill.sh"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/brain"
TS=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

# 3 done routes → promote should produce 1 pattern after distill runs
cat > "$TMPHOME/.superagent/brain/routes.jsonl" <<JSONL
{"ts":"$TS","task_hash":"abc","task":"hello world test signal","chain":["alpha","beta"],"outcome":"done","backend":"anthropic"}
{"ts":"$TS","task_hash":"abc","task":"hello world test signal","chain":["alpha","beta"],"outcome":"done","backend":"anthropic"}
{"ts":"$TS","task_hash":"abc","task":"hello world test signal","chain":["alpha","beta"],"outcome":"done","backend":"anthropic"}
JSONL
: > "$TMPHOME/.superagent/brain/patterns.jsonl"

# Distill takes a Stop-event JSON via stdin; minimum payload
echo '{"hook_event_name":"Stop"}' | HOME="$TMPHOME" PATH="$SCRIPT_DIR/../bin:$PATH" bash "$DISTILL" || true

LINES=$(wc -l < "$TMPHOME/.superagent/brain/patterns.jsonl" | tr -d ' ')
[[ "$LINES" == "1" ]] || { echo "FAIL: distill did not promote (got $LINES lines)"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-distill-patterns: PASS"
```

```bash
chmod +x test/test-distill-patterns.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-distill-patterns.sh
```

Expected: `FAIL: distill did not promote`.

- [ ] **Step 3: Modify `hooks/superagent-distill.sh`**

Append this block to the END of `hooks/superagent-distill.sh` (after whatever existing distillation logic is in place):

```bash

# ── Wave 1: pattern store maintenance ─────────────────────────────────────────
# Resolve superagent-patterns: prefer PATH, then script-relative bin/, else skip.
PATBIN=""
if command -v superagent-patterns >/dev/null 2>&1; then
  PATBIN="$(command -v superagent-patterns)"
elif [[ -x "$(dirname "${BASH_SOURCE[0]}")/../bin/superagent-patterns" ]]; then
  PATBIN="$(dirname "${BASH_SOURCE[0]}")/../bin/superagent-patterns"
fi

if [[ -n "$PATBIN" ]]; then
  "$PATBIN" promote >/dev/null 2>&1 || true
  "$PATBIN" decay   >/dev/null 2>&1 || true
fi

exit 0
```

If the existing distill.sh ends with `exit 0`, place the new block ABOVE that exit (or remove the prior exit and keep the new one).

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-distill-patterns.sh
```

Expected: `test-distill-patterns: PASS`.

- [ ] **Step 5: Commit**

```bash
git add hooks/superagent-distill.sh test/test-distill-patterns.sh
git commit -m "feat(hooks): Stop hook calls patterns promote+decay"
```

---

## Task 12: New hook — UserPromptSubmit (`superagent-prompt-submit.py`)

**Files:**
- Create: `hooks/superagent-prompt-submit.py`
- Test: `test/test-hook-prompt-submit.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-hook-prompt-submit.sh`:

```bash
#!/usr/bin/env bash
# test/test-hook-prompt-submit.sh — UserPromptSubmit hook returns valid Claude Code output
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-prompt-submit.py"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/brain"
: > "$TMPHOME/.superagent/brain/routes.jsonl"
: > "$TMPHOME/.superagent/brain/patterns.jsonl"

PAYLOAD='{"session_id":"s-1","transcript_path":"/tmp/x","cwd":"/tmp","permission_mode":"default","hook_event_name":"UserPromptSubmit","prompt":"fix dark mode toggle bug"}'

OUT=$(HOME="$TMPHOME" PATH="$SCRIPT_DIR/../bin:$PATH" python3 "$HOOK" <<<"$PAYLOAD")

# Output must be valid JSON with hookSpecificOutput
echo "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null \
  || { echo "FAIL: invalid hook output: $OUT"; rm -rf "$TMPHOME"; exit 1; }

# Must contain additionalContext mentioning SuperAgent
echo "$OUT" | jq -e '.hookSpecificOutput.additionalContext | type == "string"' >/dev/null \
  || { echo "FAIL: additionalContext missing or not a string"; rm -rf "$TMPHOME"; exit 1; }

# Empty prompt → exit 0, no announce (don't crash)
echo '{"session_id":"s","prompt":""}' | HOME="$TMPHOME" python3 "$HOOK" >/dev/null

rm -rf "$TMPHOME"
echo "test-hook-prompt-submit: PASS"
```

```bash
chmod +x test/test-hook-prompt-submit.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-hook-prompt-submit.sh
```

Expected: `python3: can't open file 'hooks/superagent-prompt-submit.py'`.

- [ ] **Step 3: Create the hook**

Create `hooks/superagent-prompt-submit.py`:

```python
#!/usr/bin/env python3
"""UserPromptSubmit hook — classify the user prompt and inject an announce block.

Reads a Claude Code UserPromptSubmit JSON payload from stdin, runs the SA classifier
on the prompt text, and writes back a hookSpecificOutput envelope containing an
`additionalContext` block that summarizes the routing plan. Bails silently on any
error so a broken classifier never blocks the user's prompt.
"""
import json
import os
import shutil
import subprocess
import sys


def _emit(obj):
    sys.stdout.write(json.dumps(obj))
    sys.stdout.flush()


def main():
    try:
        raw = sys.stdin.read()
    except Exception:
        return 0

    try:
        payload = json.loads(raw or "{}")
    except Exception:
        return 0

    prompt = (payload.get("prompt") or "").strip()
    if not prompt:
        # Silent no-op for empty prompts — don't crash, don't announce.
        _emit({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit"}})
        return 0

    classifier = shutil.which("superagent-classify") or os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "bin", "superagent-classify"
    )
    classifier = os.path.abspath(classifier)

    chain = []
    complexity = "moderate"
    categories = []
    if os.path.exists(classifier):
        try:
            r = subprocess.run(
                [classifier, prompt],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if r.returncode == 0 and r.stdout.strip():
                data = json.loads(r.stdout)
                chain = data.get("chain") or []
                meta = data.get("meta") or {}
                complexity = meta.get("complexity", "moderate")
                categories = meta.get("categories") or []
        except Exception:
            pass

    # Build the announce block. ≤8 lines so we don't bloat context.
    lines = [
        "## SuperAgent route",
        f"Complexity: {complexity}" + (f"  Categories: {', '.join(categories)}" if categories else ""),
        "Chain: " + (" → ".join(chain) if chain else "(no chain — using default)"),
    ]
    additional_context = "\n".join(lines)

    _emit({
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": additional_context,
        }
    })
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

```bash
chmod +x hooks/superagent-prompt-submit.py
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-hook-prompt-submit.sh
```

Expected: `test-hook-prompt-submit: PASS`.

- [ ] **Step 5: Commit**

```bash
git add hooks/superagent-prompt-submit.py test/test-hook-prompt-submit.sh
git commit -m "feat(hooks): UserPromptSubmit hook — classify + announce route"
```

---

## Task 13: New hook — SubagentStop (`superagent-subagent-stop.py`)

**Files:**
- Create: `hooks/superagent-subagent-stop.py`
- Test: `test/test-hook-subagent-stop.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-hook-subagent-stop.sh`:

```bash
#!/usr/bin/env bash
# test/test-hook-subagent-stop.sh — appends a subagent-flagged route record
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-subagent-stop.py"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/brain"
: > "$TMPHOME/.superagent/brain/routes.jsonl"

PAYLOAD='{"hook_event_name":"SubagentStop","session_id":"s","stop_hook_active":false,"transcript_path":"/tmp/x","tool_input":{"description":"refactor auth module"},"tool_output":{"success":true}}'
HOME="$TMPHOME" python3 "$HOOK" <<<"$PAYLOAD" >/dev/null

LAST=$(tail -n1 "$TMPHOME/.superagent/brain/routes.jsonl")
echo "$LAST" | jq -e '.subagent == true and .outcome == "done"' >/dev/null \
  || { echo "FAIL: subagent-stop record shape: $LAST"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-hook-subagent-stop: PASS"
```

```bash
chmod +x test/test-hook-subagent-stop.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-hook-subagent-stop.sh
```

Expected: `python3: can't open file 'hooks/superagent-subagent-stop.py'`.

- [ ] **Step 3: Create the hook**

Create `hooks/superagent-subagent-stop.py`:

```python
#!/usr/bin/env python3
"""SubagentStop hook — log subagent outcome to ~/.superagent/brain/routes.jsonl
with subagent:true so we can attribute cost and route success back to a parent.
"""
import json
import os
import sys
import datetime


def main():
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw or "{}")
    except Exception:
        return 0

    success = bool((payload.get("tool_output") or {}).get("success", True))
    outcome = "done" if success else "fail"
    description = (payload.get("tool_input") or {}).get("description", "") or ""
    session_id = payload.get("session_id", "")

    record = {
        "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "task_hash": "",
        "task": description[:200],
        "chain": [],
        "outcome": outcome,
        "user_override": "no",
        "backend": os.environ.get("SUPERAGENT_BACKEND", "anthropic"),
        "subagent": True,
        "session_id": session_id,
    }

    routes = os.path.expanduser("~/.superagent/brain/routes.jsonl")
    os.makedirs(os.path.dirname(routes), exist_ok=True)
    try:
        with open(routes, "a") as f:
            f.write(json.dumps(record) + "\n")
    except Exception:
        pass

    # Pass through (no decision required for SubagentStop)
    sys.stdout.write(json.dumps({"hookSpecificOutput": {"hookEventName": "SubagentStop"}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

```bash
chmod +x hooks/superagent-subagent-stop.py
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-hook-subagent-stop.sh
```

Expected: `test-hook-subagent-stop: PASS`.

- [ ] **Step 5: Commit**

```bash
git add hooks/superagent-subagent-stop.py test/test-hook-subagent-stop.sh
git commit -m "feat(hooks): SubagentStop — log subagent outcomes to routes.jsonl"
```

---

## Task 14: New hook — Notification (`superagent-notification.py`)

**Files:**
- Create: `hooks/superagent-notification.py`
- Test: `test/test-hook-notification.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-hook-notification.sh`:

```bash
#!/usr/bin/env bash
# test/test-hook-notification.sh — info gets dropped, error gets passed through
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-notification.py"

# Info → suppressOutput true (drop)
INFO='{"hook_event_name":"Notification","notification_level":"info","notification_message":"build started"}'
OUT_INFO=$(python3 "$HOOK" <<<"$INFO")
echo "$OUT_INFO" | jq -e '.suppressOutput == true' >/dev/null \
  || { echo "FAIL: info should be suppressed: $OUT_INFO"; exit 1; }

# Error → suppressOutput false (pass through)
ERR='{"hook_event_name":"Notification","notification_level":"error","notification_message":"build failed"}'
OUT_ERR=$(python3 "$HOOK" <<<"$ERR")
echo "$OUT_ERR" | jq -e '.suppressOutput == false' >/dev/null \
  || { echo "FAIL: error should not be suppressed: $OUT_ERR"; exit 1; }

echo "test-hook-notification: PASS"
```

```bash
chmod +x test/test-hook-notification.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-hook-notification.sh
```

Expected: `python3: can't open file 'hooks/superagent-notification.py'`.

- [ ] **Step 3: Create the hook**

Create `hooks/superagent-notification.py`:

```python
#!/usr/bin/env python3
"""Notification hook — filter noisy notifications.

Pass-through for level 'error' or 'warning'. Drop most 'info'-level pings unless
the message contains a critical keyword. Never blocks; only sets suppressOutput.
"""
import json
import sys


CRITICAL_INFO_TOKENS = ("rate limit", "429", "quota", "throttle", "blocked")


def main():
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw or "{}")
    except Exception:
        sys.stdout.write(json.dumps({"hookSpecificOutput": {"hookEventName": "Notification"}, "suppressOutput": False}))
        return 0

    level = (payload.get("notification_level") or "info").lower()
    msg = (payload.get("notification_message") or "").lower()

    if level in ("error", "warning"):
        suppress = False
    else:
        # info — suppress unless a critical token appears
        suppress = not any(tok in msg for tok in CRITICAL_INFO_TOKENS)

    sys.stdout.write(json.dumps({
        "hookSpecificOutput": {"hookEventName": "Notification"},
        "suppressOutput": suppress,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

```bash
chmod +x hooks/superagent-notification.py
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-hook-notification.sh
```

Expected: `test-hook-notification: PASS`.

- [ ] **Step 5: Commit**

```bash
git add hooks/superagent-notification.py test/test-hook-notification.sh
git commit -m "feat(hooks): Notification filter — drop noisy info, pass error/warning through"
```

---

## Task 15: New hook — PermissionRequest (`superagent-permission.py`)

**Files:**
- Create: `hooks/superagent-permission.py`
- Test: `test/test-hook-permission.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-hook-permission.sh`:

```bash
#!/usr/bin/env bash
# test/test-hook-permission.sh — auto-allow patterns from safety/allow.txt
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-permission.py"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/safety"
cat > "$TMPHOME/.superagent/safety/allow.txt" <<'EOF'
^git push --force-with-lease\b
^npm test\b
EOF

# Allowed
PAYLOAD_OK='{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"git push --force-with-lease origin main"}}'
OUT_OK=$(HOME="$TMPHOME" python3 "$HOOK" <<<"$PAYLOAD_OK")
echo "$OUT_OK" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' >/dev/null \
  || { echo "FAIL: allowed pattern not auto-approved: $OUT_OK"; rm -rf "$TMPHOME"; exit 1; }

# Not allowed → defaults to ask
PAYLOAD_ASK='{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"rm -rf /important"}}'
OUT_ASK=$(HOME="$TMPHOME" python3 "$HOOK" <<<"$PAYLOAD_ASK")
echo "$OUT_ASK" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null \
  || { echo "FAIL: unmatched should default to ask: $OUT_ASK"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-hook-permission: PASS"
```

```bash
chmod +x test/test-hook-permission.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-hook-permission.sh
```

Expected: `python3: can't open file 'hooks/superagent-permission.py'`.

- [ ] **Step 3: Create the hook**

Create `hooks/superagent-permission.py`:

```python
#!/usr/bin/env python3
"""PermissionRequest hook — auto-allow Bash commands matching ~/.superagent/safety/allow.txt.

Each line in allow.txt is either a comment (`#`) or a regex matched against the
command string. Empty lines ignored. On any error, default to 'ask' (the safe
fallback that hands back to Claude Code's normal permission flow).
"""
import json
import os
import re
import sys


ALLOW_PATH = os.path.expanduser("~/.superagent/safety/allow.txt")


def _decision(verdict, reason=""):
    sys.stdout.write(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PermissionRequest",
            "permissionDecision": verdict,
            "permissionDecisionReason": reason,
        }
    }))


def main():
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw or "{}")
    except Exception:
        _decision("ask", "could not parse payload")
        return 0

    tool_name = payload.get("tool_name", "")
    cmd = (payload.get("tool_input") or {}).get("command", "") or ""

    if tool_name != "Bash" or not cmd:
        _decision("ask", "non-Bash or empty command")
        return 0

    if not os.path.exists(ALLOW_PATH):
        _decision("ask", "no allow-list configured")
        return 0

    try:
        with open(ALLOW_PATH) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                try:
                    if re.search(line, cmd):
                        _decision("allow", f"matched allow-list pattern: {line}")
                        return 0
                except re.error:
                    continue
    except Exception:
        pass

    _decision("ask", "no allow-list pattern matched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

```bash
chmod +x hooks/superagent-permission.py
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-hook-permission.sh
```

Expected: `test-hook-permission: PASS`.

- [ ] **Step 5: Commit**

```bash
git add hooks/superagent-permission.py test/test-hook-permission.sh
git commit -m "feat(hooks): PermissionRequest — auto-allow safety/allow.txt regexes"
```

---

## Task 16: New hook — PreCompact (`superagent-precompact.py`)

**Files:**
- Create: `hooks/superagent-precompact.py`
- Test: `test/test-hook-precompact.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-hook-precompact.sh`:

```bash
#!/usr/bin/env bash
# test/test-hook-precompact.sh — PreCompact dumps a pre-compact snapshot
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/superagent-precompact.py"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.superagent/brain"
TS=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/brain/routes.jsonl" <<JSONL
{"ts":"$TS","task":"recent task","chain":["a","b"],"outcome":"done"}
JSONL

OUT=$(HOME="$TMPHOME" python3 "$HOOK" <<<'{"hook_event_name":"PreCompact"}')
echo "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "PreCompact"' >/dev/null \
  || { echo "FAIL: invalid output: $OUT"; rm -rf "$TMPHOME"; exit 1; }

# Snapshot file should exist
ls "$TMPHOME"/.superagent/logs/precompact-*.jsonl >/dev/null 2>&1 \
  || { echo "FAIL: precompact snapshot not written"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-hook-precompact: PASS"
```

```bash
chmod +x test/test-hook-precompact.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-hook-precompact.sh
```

Expected: `python3: can't open file 'hooks/superagent-precompact.py'`.

- [ ] **Step 3: Create the hook**

Create `hooks/superagent-precompact.py`:

```python
#!/usr/bin/env python3
"""PreCompact hook — snapshot recent routes/learnings before window compacts.

Writes a small log file under ~/.superagent/logs/precompact-<ts>.jsonl containing
the last N=20 routes from routes.jsonl. If `claude-mem` is on PATH, also try a
best-effort `claude-mem ingest` of the snapshot — but never block on its absence.
"""
import datetime
import json
import os
import shutil
import subprocess
import sys


SNAPSHOT_DIR = os.path.expanduser("~/.superagent/logs")
ROUTES = os.path.expanduser("~/.superagent/brain/routes.jsonl")


def main():
    try:
        sys.stdin.read()  # drain stdin so the harness is happy
    except Exception:
        pass

    os.makedirs(SNAPSHOT_DIR, exist_ok=True)
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    snapshot = os.path.join(SNAPSHOT_DIR, f"precompact-{ts}.jsonl")

    lines = []
    if os.path.exists(ROUTES):
        try:
            with open(ROUTES) as f:
                lines = f.readlines()[-20:]
        except Exception:
            lines = []

    try:
        with open(snapshot, "w") as f:
            f.writelines(lines)
    except Exception:
        pass

    # Best-effort: hand off to claude-mem if available.
    cmem = shutil.which("claude-mem")
    if cmem:
        try:
            subprocess.run(
                [cmem, "ingest", snapshot],
                timeout=2,
                capture_output=True,
            )
        except Exception:
            pass

    sys.stdout.write(json.dumps({"hookSpecificOutput": {"hookEventName": "PreCompact"}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

```bash
chmod +x hooks/superagent-precompact.py
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-hook-precompact.sh
```

Expected: `test-hook-precompact: PASS`.

- [ ] **Step 5: Commit**

```bash
git add hooks/superagent-precompact.py test/test-hook-precompact.sh
git commit -m "feat(hooks): PreCompact — snapshot recent routes before window compacts"
```

---

## Task 17: Wire 5 new hooks into `hooks.json` + `install.sh`

**Files:**
- Modify: `hooks/hooks.json` (5 new event blocks)
- Modify: `install.sh` (Step 9b — copy + wire idempotently)
- Test: `test/test-install-hooks.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-install-hooks.sh`:

```bash
#!/usr/bin/env bash
# test/test-install-hooks.sh — install.sh wires 5 new events idempotently
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/../install.sh"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.claude"
echo '{}' > "$TMPHOME/.claude/settings.json"

# Run install — should populate the 5 new events
HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true

# Each event should appear exactly once
for event in UserPromptSubmit SubagentStop Notification PermissionRequest PreCompact; do
  count=$(jq --arg e "$event" '.hooks[$e] // [] | length' "$TMPHOME/.claude/settings.json")
  [[ "$count" -ge 1 ]] || { echo "FAIL: $event not wired (count=$count)"; rm -rf "$TMPHOME"; exit 1; }
done

# Idempotency: run install again, ensure no duplicates
HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true
for event in UserPromptSubmit SubagentStop Notification PermissionRequest PreCompact; do
  total=$(jq --arg e "$event" '[.hooks[$e][]?.hooks[]? | select(.command | contains("superagent"))] | length' "$TMPHOME/.claude/settings.json")
  [[ "$total" -le 1 ]] || { echo "FAIL: $event duplicated (count=$total) on second install"; rm -rf "$TMPHOME"; exit 1; }
done

rm -rf "$TMPHOME"
echo "test-install-hooks: PASS"
```

```bash
chmod +x test/test-install-hooks.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-install-hooks.sh
```

Expected: `FAIL: UserPromptSubmit not wired` (current install.sh wires only 2 of the 5 new events).

- [ ] **Step 3a: Update `hooks/hooks.json` template**

Replace the contents of `hooks/hooks.json` with:

```json
{
  "$schema": "https://raw.githubusercontent.com/anthropics/claude-code/main/schemas/hooks.json",
  "_comment": "Reference layout — install.sh writes the live config into ~/.claude/settings.json. Edit there for runtime; edit here to update the docs/template.",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [
          {"type": "command", "command": "python3 \"$HOME/.claude/superagent-safety.py\""}
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "python3 \"$HOME/.claude/superagent-session-start.py\""}
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash|Edit|Write|MultiEdit|Read|Grep|Glob",
        "hooks": [
          {"type": "command", "command": "bash \"$HOME/.claude/superagent-tracker.sh\""}
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "bash \"$HOME/.claude/superagent-distill.sh\" || true"}
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "python3 \"$HOME/.claude/superagent-prompt-submit.py\""}
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "python3 \"$HOME/.claude/superagent-subagent-stop.py\""}
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "python3 \"$HOME/.claude/superagent-notification.py\""}
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "python3 \"$HOME/.claude/superagent-permission.py\""}
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "python3 \"$HOME/.claude/superagent-precompact.py\""}
        ]
      }
    ]
  }
}
```

- [ ] **Step 3b: Update `install.sh` Step 9b**

Open `install.sh`. Locate Step 9b (`# ── Step 9b: Install Python safety + session-start hooks ───────`). Replace the inline Node.js wiring block with this expanded version that wires all 9 hook events idempotently. The full replacement starts at the line `info "Installing PreToolUse safety gate + SessionStart hook..."` and replaces everything up to the next major step header (look for `# ── Step 10` or similar).

Replacement block:

```bash
# ── Step 9b: Install Python + bash hooks (Wave 1: 9 events total) ─────────
info "Installing 9 SuperAgent hooks (4 existing + 5 net-new)..."

# Source files in repo
declare -A HOOK_SRCS=(
  [superagent-safety.py]="$SCRIPT_DIR/hooks/superagent-safety.py"
  [superagent-session-start.py]="$SCRIPT_DIR/hooks/superagent-session-start.py"
  [superagent-tracker.sh]="$SCRIPT_DIR/hooks/superagent-tracker.sh"
  [superagent-distill.sh]="$SCRIPT_DIR/hooks/superagent-distill.sh"
  [superagent-prompt-submit.py]="$SCRIPT_DIR/hooks/superagent-prompt-submit.py"
  [superagent-subagent-stop.py]="$SCRIPT_DIR/hooks/superagent-subagent-stop.py"
  [superagent-notification.py]="$SCRIPT_DIR/hooks/superagent-notification.py"
  [superagent-permission.py]="$SCRIPT_DIR/hooks/superagent-permission.py"
  [superagent-precompact.py]="$SCRIPT_DIR/hooks/superagent-precompact.py"
)

for name in "${!HOOK_SRCS[@]}"; do
  src="${HOOK_SRCS[$name]}"
  if [[ -f "$src" ]]; then
    cp "$src" "$CLAUDE_DIR/$name"
    chmod +x "$CLAUDE_DIR/$name"
  fi
done

ok "Hook scripts copied to $CLAUDE_DIR"

# Wire each event exactly once (idempotent) into ~/.claude/settings.json
node - <<'NODE'
const fs = require('fs');
const path = require('path');
const file = path.join(process.env.HOME, '.claude', 'settings.json');
const cfg = JSON.parse(fs.readFileSync(file, 'utf8'));
cfg.hooks = cfg.hooks || {};

const wirings = [
  { event: 'PreToolUse',       matcher: 'Bash|Edit|Write|MultiEdit|NotebookEdit', cmd: 'python3 "$HOME/.claude/superagent-safety.py"' },
  { event: 'SessionStart',     matcher: '*',                                       cmd: 'python3 "$HOME/.claude/superagent-session-start.py"' },
  { event: 'PostToolUse',      matcher: 'Bash|Edit|Write|MultiEdit|Read|Grep|Glob',cmd: 'bash "$HOME/.claude/superagent-tracker.sh"' },
  { event: 'Stop',             matcher: '*',                                       cmd: 'bash "$HOME/.claude/superagent-distill.sh" || true' },
  { event: 'UserPromptSubmit', matcher: '*',                                       cmd: 'python3 "$HOME/.claude/superagent-prompt-submit.py"' },
  { event: 'SubagentStop',     matcher: '*',                                       cmd: 'python3 "$HOME/.claude/superagent-subagent-stop.py"' },
  { event: 'Notification',     matcher: '*',                                       cmd: 'python3 "$HOME/.claude/superagent-notification.py"' },
  { event: 'PermissionRequest',matcher: 'Bash',                                    cmd: 'python3 "$HOME/.claude/superagent-permission.py"' },
  { event: 'PreCompact',       matcher: '*',                                       cmd: 'python3 "$HOME/.claude/superagent-precompact.py"' },
];

const SIG = (cmd) => {
  const m = cmd.match(/superagent-[a-z-]+\.(py|sh)/);
  return m ? m[0] : cmd;
};

for (const { event, matcher, cmd } of wirings) {
  cfg.hooks[event] = cfg.hooks[event] || [];
  const sig = SIG(cmd);
  // Skip if already wired (any block referencing this script signature)
  const already = cfg.hooks[event].some(blk =>
    (blk.hooks || []).some(h => (h.command || '').includes(sig))
  );
  if (!already) {
    cfg.hooks[event].push({
      matcher,
      hooks: [{ type: 'command', command: cmd }],
    });
  }
}

fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
console.log('All 9 SuperAgent hooks wired (idempotent)');
NODE

ok "9 hooks wired in $SETTINGS"

# Marker for Wave 1 completion
mkdir -p "$HOME/.superagent" 2>/dev/null || true
date -Iseconds > "$HOME/.superagent/.wave-1.installed" 2>/dev/null || true
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-install-hooks.sh
```

Expected: `test-install-hooks: PASS`.

- [ ] **Step 5: Commit**

```bash
git add hooks/hooks.json install.sh test/test-install-hooks.sh
git commit -m "feat(install): wire 5 new hooks into ~/.claude/settings.json idempotently"
```

---

## Task 18: Bench — add 5 prompts for Wave 1 keywords

**Files:**
- Modify: `bench/prompts.jsonl` (+5 prompts)
- Modify: `bench/run.sh` (no change unless count is hardcoded — verify)

- [ ] **Step 1: Write the failing test**

Run the existing bench against the current corpus first to record the baseline:

```bash
cd bench
./run.sh > /tmp/bench-before.txt
cat /tmp/bench-before.txt | tail -3
```

Expected: shows current pass rate (should be ≥85% per CHANGELOG).

- [ ] **Step 2: Append 5 new prompts**

Add these to the END of `bench/prompts.jsonl` (one JSON line each, increment ID from the current max):

```text
{"id": 25, "prompt": "track my daily Anthropic spend and warn me at 90% budget", "archetype": "cost", "expected_chain": ["mempalace-wake", "token-stats", "cost-budget", "auto-fallback"]}
{"id": 26, "prompt": "show last 5 routes and their outcomes", "archetype": "meta", "expected_chain": ["mempalace-wake", "token-stats"]}
{"id": 27, "prompt": "promote this routing pattern so we don't have to rediscover it next time", "archetype": "learning", "expected_chain": ["mempalace-wake", "superagent-learn-loop", "learn"]}
{"id": 28, "prompt": "auto-approve git push --force-with-lease in this repo", "archetype": "permission", "expected_chain": ["mempalace-wake", "superagent-safety"]}
{"id": 29, "prompt": "downgrade to sonnet when we hit 90% of daily plan", "archetype": "cost", "expected_chain": ["mempalace-wake", "auto-fallback", "cost-budget"]}
```

- [ ] **Step 3: Update classifier rules to route these prompts**

Add (or extend) entries in `skills/superagent/brain/rules.yaml` so the new keywords route correctly. Append the following rules near the end of the `rules:` list (preserve the existing ones):

```yaml
  - name: cost-budget
    signal: '\b(budget|spend|daily.+cost|alert|tier.+(downgrade|shift)|plan.+(limit|cap)|90 ?%)\b'
    chain:
      - mempalace-wake
      - token-stats
      - cost-budget
      - auto-fallback
    complexity: trivial

  - name: superagent-learn-loop
    signal: '\b(promote|pattern|routing.+pattern|learn(ing)?.+loop|don.?t.+rediscover)\b'
    chain:
      - mempalace-wake
      - superagent-learn-loop
      - learn
    complexity: trivial

  - name: meta-routes
    signal: '\b(last \d+ routes|recent routes|last few prompts|routes\.jsonl|outcome history)\b'
    chain:
      - mempalace-wake
      - token-stats
    complexity: trivial
```

- [ ] **Step 4: Run bench, expect ≥85% on the extended corpus**

```bash
cd bench
./run.sh
```

Expected: pass rate ≥85% across all 29 prompts.

If a prompt fails, tweak the regex in `rules.yaml` to disambiguate. Do NOT lower the gate.

- [ ] **Step 5: Commit**

```bash
git add bench/prompts.jsonl skills/superagent/brain/rules.yaml
git commit -m "feat(bench): +5 prompts for Wave 1 cost-budget/learn-loop/meta keywords"
```

---

## Task 19: Migration — `install.sh` v2.3 → v2.4

**Files:**
- Modify: `install.sh` (add backup + marker logic at the top of the install flow)
- Test: `test/test-install-migration.sh`

- [ ] **Step 1: Write the failing test**

Create `test/test-install-migration.sh`:

```bash
#!/usr/bin/env bash
# test/test-install-migration.sh — backup calls.jsonl + write .wave-1.installed marker
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$SCRIPT_DIR/../install.sh"

TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.claude" "$TMPHOME/.superagent/cost"
echo '{}' > "$TMPHOME/.claude/settings.json"

# Pre-existing v1 calls.jsonl (no input_tokens)
TS=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)
cat > "$TMPHOME/.superagent/cost/calls.jsonl" <<JSONL
{"ts":"$TS","project":"/x","tool":"Bash","tokens":42,"model":"sonnet"}
JSONL

HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true

# Backup must exist
[[ -f "$TMPHOME/.superagent/cost/calls.v1.jsonl.bak" ]] \
  || { echo "FAIL: calls.v1.jsonl.bak missing"; rm -rf "$TMPHOME"; exit 1; }
# Marker must exist
[[ -f "$TMPHOME/.superagent/.wave-1.installed" ]] \
  || { echo "FAIL: .wave-1.installed marker missing"; rm -rf "$TMPHOME"; exit 1; }

# Idempotency: re-run, no duplicate backup file proliferation
HOME="$TMPHOME" bash "$INSTALL" >/dev/null 2>&1 || true
COUNT=$(ls "$TMPHOME/.superagent/cost/" | grep -c 'calls\.v1' || echo 0)
[[ "$COUNT" -le 1 ]] || { echo "FAIL: backup duplicated (count=$COUNT)"; rm -rf "$TMPHOME"; exit 1; }

rm -rf "$TMPHOME"
echo "test-install-migration: PASS"
```

```bash
chmod +x test/test-install-migration.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-install-migration.sh
```

Expected: `FAIL: calls.v1.jsonl.bak missing`.

- [ ] **Step 3: Add migration block to `install.sh`**

In `install.sh`, locate the early section right after `set -euo pipefail` and the `SCRIPT_DIR` definition (before any side-effect step). Insert a Wave-1 migration block:

```bash
# ── Wave 1 migration: v2.3 → v2.4 backup + marker (idempotent) ──────────────
WAVE1_MARKER="$HOME/.superagent/.wave-1.installed"
SA_ROOT="$HOME/.superagent"
mkdir -p "$SA_ROOT/cost" "$SA_ROOT/.backups" 2>/dev/null || true

# Backup v1 calls.jsonl on first install only (presence of marker == already done).
if [[ ! -f "$WAVE1_MARKER" ]] && [[ -f "$SA_ROOT/cost/calls.jsonl" ]]; then
  if [[ ! -f "$SA_ROOT/cost/calls.v1.jsonl.bak" ]]; then
    cp "$SA_ROOT/cost/calls.jsonl" "$SA_ROOT/cost/calls.v1.jsonl.bak"
    info "v1 calls.jsonl backed up to calls.v1.jsonl.bak (Wave 1 schema upgrade)"
  fi
fi
```

The Step 9b block already writes `WAVE1_MARKER` after wiring hooks (added in Task 17). So the second-run idempotency comes for free: marker present → skip backup.

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-install-migration.sh
```

Expected: `test-install-migration: PASS`.

- [ ] **Step 5: Commit**

```bash
git add install.sh test/test-install-migration.sh
git commit -m "feat(install): Wave 1 migration — backup calls.v1 + .wave-1.installed marker"
```

---

## Task 20: Skill docs + version bump + CHANGELOG + README row

**Files:**
- Create: `skills/superagent-learn-loop/SKILL.md`
- Create: `skills/cost-budget/SKILL.md`
- Modify: `README.md` (capability table row)
- Modify: `CHANGELOG.md` (v2.4.0 entry)
- Modify: `package.json` (version → 2.4.0)

- [ ] **Step 1: Write the failing test**

Create `test/test-wave1-docs.sh`:

```bash
#!/usr/bin/env bash
# test/test-wave1-docs.sh — Wave 1 doc + version artifacts present and consistent
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/skills/superagent-learn-loop/SKILL.md" ]] \
  || { echo "FAIL: superagent-learn-loop SKILL.md missing"; exit 1; }
[[ -f "$ROOT/skills/cost-budget/SKILL.md" ]] \
  || { echo "FAIL: cost-budget SKILL.md missing"; exit 1; }

grep -q '## v2.4.0' "$ROOT/CHANGELOG.md" \
  || { echo "FAIL: CHANGELOG missing v2.4.0 section"; exit 1; }

VERSION=$(jq -r '.version' "$ROOT/package.json" 2>/dev/null || echo missing)
[[ "$VERSION" == "2.4.0" ]] || { echo "FAIL: package.json version is $VERSION, want 2.4.0"; exit 1; }

grep -qE 'patterns\.jsonl|learning loop|budget alerts' "$ROOT/README.md" \
  || { echo "FAIL: README missing Wave 1 capability row"; exit 1; }

echo "test-wave1-docs: PASS"
```

```bash
chmod +x test/test-wave1-docs.sh
```

- [ ] **Step 2: Run test to verify it fails**

```bash
test/test-wave1-docs.sh
```

Expected: `FAIL: superagent-learn-loop SKILL.md missing`.

- [ ] **Step 3a: Create `skills/superagent-learn-loop/SKILL.md`**

```bash
mkdir -p skills/superagent-learn-loop
```

Create `skills/superagent-learn-loop/SKILL.md`:

```markdown
---
name: superagent-learn-loop
description: SuperAgent learning loop. Promotes recurring done-routes into pattern records, decays stale ones, and feeds them back to the classifier. Use whenever the user wants to teach SuperAgent which chains worked, prune old patterns, or inspect/protect specific routes. Triggers on "promote pattern", "learn this routing", "decay patterns", "list patterns", "protect pattern".
---

# superagent-learn-loop

The SuperAgent classifier becomes self-improving in v2.4. Every Stop hook runs `superagent-patterns promote` (extracts repeated done-routes into pattern records) and `superagent-patterns decay` (exponentially decays inactive ones). The classifier reads `~/.superagent/brain/patterns.jsonl` and prepends matched chains when `successRate ≥ 0.6` and `useCount ≥ 5`.

## When to use

- User says "remember this pattern" / "promote this route" / "learn this".
- User wants to inspect, protect, or prune the pattern store.
- After a session where you discovered a chain that should survive into future sessions.

## Procedure

1. **List current patterns** to ground the user:
   ```bash
   superagent-patterns list
   ```
2. **Manual promote** if the user wants the latest routes folded in immediately (Stop hook already does this on session end):
   ```bash
   superagent-patterns promote
   ```
3. **Protect a high-value pattern** so decay won't drop it below 0.3:
   ```bash
   superagent-patterns protect p-<id>
   ```
4. **Manual prune** to clean noise below a custom threshold:
   ```bash
   superagent-patterns prune --below 0.3
   ```

## Files

- Store: `~/.superagent/brain/patterns.jsonl` (append-only JSONL).
- Source: `~/.superagent/brain/routes.jsonl` (read by `promote`).
- Defaults: `~/.superagent/defaults.toml` `[learning]` section.

## Ethos

Memory is compounding interest. Each successful chain that survives the gate becomes a faster route next session. Don't bypass the gate — `successRate ≥ 0.6 + useCount ≥ 5` is what keeps one-off coincidences out of the classifier.
```

- [ ] **Step 3b: Create `skills/cost-budget/SKILL.md`**

```bash
mkdir -p skills/cost-budget
```

Create `skills/cost-budget/SKILL.md`:

```markdown
---
name: cost-budget
description: Per-day Anthropic budget alerts and auto-downgrade. Reads ~/.superagent/cost/budget.json, emits tiered alerts at 50/75/90/100% of daily budget, and drops auto-downgrade.flag for the auto-fallback skill at 0.9. Use when user says "set budget", "alert me at 90%", "downgrade at threshold", "show today's spend".
---

# cost-budget

Wave 1 introduced per-task USD attribution and budget enforcement. The existing `token-stats` skill remains for stats; this skill is for *enforcement*.

## When to use

- User asks about today's spend, weekly cost, or budget status.
- User wants to set or change a daily/monthly budget.
- User configures auto-downgrade target (e.g. drop to Sonnet at 90%).
- An alert in `~/.superagent/cost/alerts.jsonl` requires user attention.

## Procedure

1. **Show today's spend with full v2 breakdown:**
   ```bash
   superagent-cost today
   ```
2. **Run alerts (idempotent, safe to re-run):**
   ```bash
   superagent-cost-alerts
   ```
3. **Set or update budget:**
   Edit `~/.superagent/cost/budget.json`:
   ```json
   {"daily_usd":20,"monthly_usd":400,
    "alert_thresholds":[0.5,0.75,0.9,1.0],
    "auto_downgrade":{"at":0.9,"target":"sonnet"},
    "hard_stop":{"at":1.0,"mode":"prompt"}}
   ```
4. **Inspect recent alerts:**
   ```bash
   tail -n 5 ~/.superagent/cost/alerts.jsonl | jq .
   ```

## Pricing

Default 4-dim pricing table is hardcoded for 2026-Q2 (Haiku/Sonnet/Opus × input/output/cache_write/cache_read). Override at `~/.superagent/cost/pricing.json` for non-standard tiers or custom contracts.

## Auto-downgrade flow

When `daily_usd` consumption ≥ `auto_downgrade.at` (default 0.9), `superagent-cost-alerts` writes `~/.superagent/auto-downgrade.flag` containing the target model. The `auto-fallback` skill reads this flag at routing time and proposes the in-tier shift (Opus→Sonnet, Sonnet→Haiku). The flag clears automatically when usage drops below the threshold.

## Hard stop

At 100% with `hard_stop.mode: prompt` (default), the next route prints a confirmation prompt rather than silently halting. Set `mode: halt` only for unattended workloads.
```

- [ ] **Step 3c: Update `CHANGELOG.md`**

Prepend (after the title) a new section:

```markdown
## v2.4.0 — 2026-05-09 (Wave 1: Foundation)

### Added
- **Hooks lifecycle expanded** — 5 net-new events: `UserPromptSubmit`, `SubagentStop`, `Notification`, `PermissionRequest`, `PreCompact`. Total wired hooks: 4 → 9.
- **Learning loop** — `~/.superagent/brain/patterns.jsonl` store with promote/decay/protect/prune. Classifier prepends matched chains when `successRate ≥ 0.6 AND useCount ≥ 5`.
- **Cost-tracker schema v2** — 4-dim pricing (input/output/cache_write/cache_read), `pricing_version` field, v1 records auto-detected and treated as `output_tokens` only.
- **Budget alerts + auto-downgrade** — `bin/superagent-cost-alerts`, `~/.superagent/cost/budget.json`, `~/.superagent/auto-downgrade.flag`. Tiered alerts at 50/75/90/100% of daily budget.
- **`superagent-learn-loop` skill** — user-facing skill for the learning loop.
- **`cost-budget` skill** — user-facing skill for budget enforcement.
- **`bin/superagent-patterns`** — pattern store CLI.
- **`bin/superagent-cost-alerts`** — alert emitter + flag manager.
- **`~/.superagent/defaults.toml`** — single source of truth for magic numbers.

### Changed
- `auto-fallback` skill honors `auto-downgrade.flag` for in-Anthropic tier shifts (precedence: budget > rate-limit > preference).
- `superagent-classify` reads `patterns.jsonl` after `rules.yaml`.
- `superagent-tracker.sh` writes 4-dim records.
- `superagent-distill.sh` calls `superagent-patterns promote && decay` at session Stop.

### Migration
- v1 `calls.jsonl` records auto-detected and read transparently (no rewrite).
- Backup of pre-Wave-1 `calls.jsonl` saved to `~/.superagent/cost/calls.v1.jsonl.bak`.
- Idempotency marker at `~/.superagent/.wave-1.installed`.

### Bench
- 25 prompts (5 added for Wave 1 keywords). Gate ≥85% routing accuracy.
```

- [ ] **Step 3d: Update `README.md` capability table**

In `README.md`, locate the capabilities/features table and add this row near the top:

```markdown
| ✨ **Self-improving classifier (v2.4)** | `~/.superagent/brain/patterns.jsonl` learns from every Stop. Successful chains promote; stale ones decay. Plus 9-event hooks lifecycle, budget alerts, and auto-downgrade at 90% spend. |
```

- [ ] **Step 3e: Bump `package.json`**

```bash
node -e "const f='package.json';const p=require('./'+f);p.version='2.4.0';require('fs').writeFileSync(f, JSON.stringify(p, null, 2)+'\n')"
```

- [ ] **Step 4: Run test to verify it passes**

```bash
test/test-wave1-docs.sh
```

Expected: `test-wave1-docs: PASS`.

- [ ] **Step 5: Commit**

```bash
git add skills/superagent-learn-loop/SKILL.md skills/cost-budget/SKILL.md \
        CHANGELOG.md README.md package.json test/test-wave1-docs.sh
git commit -m "feat(v2.4.0): Wave 1 docs + skills + CHANGELOG + version bump"
```

---

## Task 21: Wave 1 ship checklist

**Files:**
- Run all tests in sequence; recompile adapters; tag release.

- [ ] **Step 1: Run the full Wave 1 test suite**

```bash
for t in test/test-state-init.sh test/test-cost-v2.sh test/test-tracker-v2.sh \
         test/test-cost-alerts.sh test/test-auto-fallback-flag.sh \
         test/test-patterns.sh test/test-patterns-promote.sh \
         test/test-patterns-decay.sh test/test-patterns-protect-prune.sh \
         test/test-classify-patterns.sh test/test-distill-patterns.sh \
         test/test-hook-prompt-submit.sh test/test-hook-subagent-stop.sh \
         test/test-hook-notification.sh test/test-hook-permission.sh \
         test/test-hook-precompact.sh test/test-install-hooks.sh \
         test/test-install-migration.sh test/test-wave1-docs.sh; do
  echo "→ $t"
  "$t" || { echo "STOP: $t failed"; exit 1; }
done
echo "All Wave 1 tests pass."
```

Expected: `All Wave 1 tests pass.`

- [ ] **Step 2: Run existing tests for regression**

```bash
test/test-classify.sh
test/test-distill.sh
test/test-canary.sh
test/test-switch-list.sh
```

Expected: all pass (existing behavior unchanged when patterns.jsonl is empty).

- [ ] **Step 3: Run bench and confirm ≥85%**

```bash
cd bench && ./run.sh
```

Expected: `pass rate ≥ 0.85` over 29 prompts.

- [ ] **Step 4: Recompile adapters**

```bash
bin/superagent-compile
```

Expected: 7 adapter dirs (`adapters/{aider,codex,continue,copilot,cursor,gemini,windsurf}`) regenerated. New skills (`superagent-learn-loop`, `cost-budget`) propagate as rule files. Hooks remain Claude Code-only.

- [ ] **Step 5: Final verification**

```bash
git log --oneline | head -25
git status
```

Expected: ~20 sequential `feat(...)` commits since the last release (one per task), clean working tree, no untracked files.

- [ ] **Step 6: Tag and push**

(Only when the user explicitly approves shipping — the AGENT MUST NOT push without that approval.)

```bash
# After user says "ship it":
git tag -a v2.4.0 -m "Wave 1: Foundation — hooks lifecycle + learning loop + budget alerts"
# git push origin main --follow-tags    # only with explicit user permission
```

---

## Self-review checklist

Before declaring this plan complete, verify:

1. **Spec coverage.** Every Wave 1 component in `docs/superpowers/specs/2026-05-08-superagent-v3-upgrade-design.md` §6 has at least one task here:
   - §6.1 hooks lifecycle (5 hooks) → Tasks 12-16, wired in Task 17. ✓
   - §6.2 learning loop (patterns.jsonl + bin + classifier integration + Stop call) → Tasks 6-11. ✓
   - §6.3 cost-tracker schema bump (4-dim pricing + tracker.sh + budget alerts + auto-downgrade flag) → Tasks 2-5. ✓
   - §6.4 data flow → covered implicitly by hook wiring + tracker.sh + classify + cost-alerts. ✓
   - §6.5 testing → 19 test scripts, bench extension, regression check. ✓

2. **Cross-cutting (§9) coverage for Wave 1 only:**
   - §9.2 state hygiene → Task 1 creates dirs; rotation deferred to Wave 3 (acceptable per phased rollout).
   - §9.3 defaults.toml → Task 1. ✓
   - §9.4 migration → Task 19. ✓
   - §9.5 adapter recompile → Task 21 step 4. ✓
   - §9.6 bench gate → Task 18 + Task 21 step 3. ✓
   - §9.7 docs → Task 20. ✓

3. **No placeholders.** Search confirmed: every step has full code, exact file paths, exact commands, expected outputs. No "TBD" / "TODO" / "implement later".

4. **Type consistency.** Pattern record shape `{id, kind, signal, chain, successRate, useCount, lastUsed, protected}` is used identically across Tasks 6, 7, 8, 9, 10. Cost record shape v2 used identically in Tasks 2, 3.

5. **Idempotency.** Tasks that modify shared config (state-init, hooks.json wiring, install.sh migration) are explicitly tested for idempotency in Tasks 1, 17, 19.
