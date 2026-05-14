#!/usr/bin/env bash
# test/test-agent-pool.sh — verify agent-pool skill, bin, and credits.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
SKILL="$ROOT/skills/agent-pool/SKILL.md"
BIN="$ROOT/bin/superagent-pool"

# --- 1. SKILL.md exists with proper frontmatter -----------------------------
[[ -f "$SKILL" ]] || { echo "FAIL: $SKILL missing"; exit 1; }
grep -q '^name: agent-pool$' "$SKILL" || { echo "FAIL: SKILL.md missing 'name: agent-pool' frontmatter"; exit 1; }

# --- 2. Credits octogent ----------------------------------------------------
grep -q 'github.com/hesamsheikh/octogent' "$SKILL" || { echo "FAIL: SKILL.md does not credit octogent URL"; exit 1; }

# --- 3. Distinguishes from Wave 2 specialist agents -------------------------
grep -qi 'wave 2' "$SKILL" || { echo "FAIL: SKILL.md does not mention Wave 2"; exit 1; }
grep -qi 'specialist' "$SKILL" || { echo "FAIL: SKILL.md does not distinguish from specialist agents"; exit 1; }

# --- 4. bin --help exits 0 and mentions all subcommands ---------------------
[[ -x "$BIN" ]] || { echo "FAIL: $BIN not executable"; exit 1; }
HELP=$("$BIN" --help)
for w in spawn list tag kill status; do
  echo "$HELP" | grep -q "$w" || { echo "FAIL: --help missing '$w'"; exit 1; }
done

# --- 5. list --json returns valid JSON with sessions key even when empty ----
TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
# Case A: ~/.claude/projects/ absent entirely
OUT=$(HOME="$TMPHOME" "$BIN" list --json)
echo "$OUT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert isinstance(d.get('sessions'), list), d" \
  || { echo "FAIL: list --json invalid when ~/.claude/projects missing"; exit 1; }

# Case B: ~/.claude/projects/ present but empty
mkdir -p "$TMPHOME/.claude/projects"
OUT=$(HOME="$TMPHOME" "$BIN" list --json)
echo "$OUT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert d == {'sessions': []}, d" \
  || { echo "FAIL: list --json should be {sessions:[]} when projects dir empty"; exit 1; }

# Case C: with one fake session
mkdir -p "$TMPHOME/.claude/projects/some-project"
echo '{"type":"user"}' > "$TMPHOME/.claude/projects/some-project/sess-abc.jsonl"
OUT=$(HOME="$TMPHOME" "$BIN" list --json)
COUNT=$(echo "$OUT" | python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())['sessions']))")
[[ "$COUNT" == "1" ]] || { echo "FAIL: list --json should find 1 session (got $COUNT)"; exit 1; }

# --- 6. spawn emits valid JSON with directive == spawn-claude ---------------
OUT=$(HOME="$TMPHOME" "$BIN" spawn "test description")
echo "$OUT" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d.get('directive') == 'spawn-claude', d
assert d.get('description') == 'test description', d
assert isinstance(d.get('cwd'), str) and d['cwd'], d
assert isinstance(d.get('sessionTag'), str) and d['sessionTag'], d
" || { echo "FAIL: spawn output invalid"; exit 1; }

# --- 7. tag appends to tags.jsonl -------------------------------------------
HOME="$TMPHOME" "$BIN" tag s-abc "demo tag" >/dev/null
TAGFILE="$TMPHOME/.superagent/pool/tags.jsonl"
[[ -f "$TAGFILE" ]] || { echo "FAIL: tags.jsonl not created"; exit 1; }
LINES=$(wc -l < "$TAGFILE" | tr -d ' ')
[[ "$LINES" == "1" ]] || { echo "FAIL: tags.jsonl should have 1 line (got $LINES)"; exit 1; }
python3 -c "
import json
with open('$TAGFILE') as f:
    rec = json.loads(f.readline())
assert rec.get('sessionId') == 's-abc', rec
assert rec.get('description') == 'demo tag', rec
assert 'ts' in rec, rec
" || { echo "FAIL: tags.jsonl record malformed"; exit 1; }

# --- 8. kill appends abandon record -----------------------------------------
HOME="$TMPHOME" "$BIN" kill s-abc >/dev/null
ABFILE="$TMPHOME/.superagent/pool/abandons.jsonl"
[[ -f "$ABFILE" ]] || { echo "FAIL: abandons.jsonl not created"; exit 1; }
python3 -c "
import json
with open('$ABFILE') as f:
    rec = json.loads(f.readline())
assert rec.get('action') == 'abandon', rec
assert rec.get('sessionId') == 's-abc', rec
" || { echo "FAIL: abandons.jsonl record malformed"; exit 1; }

# --- 9. status reports counts -----------------------------------------------
STATUS=$(HOME="$TMPHOME" "$BIN" status)
echo "$STATUS" | grep -q 'active sessions: 1' || { echo "FAIL: status active count wrong: $STATUS"; exit 1; }
echo "$STATUS" | grep -q 'tagged:          1' || { echo "FAIL: status tagged count wrong: $STATUS"; exit 1; }
echo "$STATUS" | grep -q 'abandoned:       1' || { echo "FAIL: status abandoned count wrong: $STATUS"; exit 1; }

echo "test-agent-pool: PASS"
