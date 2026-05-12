#!/usr/bin/env bash
# test/test-obs-trace.sh — trace tree builder with bottleneck flag
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/../bin/superagent-trace"
EMIT="$SCRIPT_DIR/../bin/superagent-obs"

TMPHOME=$(mktemp -d)
trap 'rm -rf "$TMPHOME"' EXIT
mkdir -p "$TMPHOME/.superagent/obs"

# Build a 3-span tree: root + 2 children, plus 4 baseline same-op spans to compute p95
HOME="$TMPHOME" "$EMIT" span --op tool.Bash --trace t-other --span s-noise1 --start 0 --end 50  --status OK
HOME="$TMPHOME" "$EMIT" span --op tool.Bash --trace t-other --span s-noise2 --start 0 --end 60  --status OK
HOME="$TMPHOME" "$EMIT" span --op tool.Bash --trace t-other --span s-noise3 --start 0 --end 55  --status OK
HOME="$TMPHOME" "$EMIT" span --op tool.Bash --trace t-other --span s-noise4 --start 0 --end 70  --status OK
HOME="$TMPHOME" "$EMIT" span --op root      --trace t-x     --span s-root  --start 0 --end 500 --status OK
HOME="$TMPHOME" "$EMIT" span --op tool.Bash --trace t-x     --span s-fast  --parent s-root --start 10  --end 30  --status OK
HOME="$TMPHOME" "$EMIT" span --op tool.Bash --trace t-x     --span s-slow  --parent s-root --start 50  --end 500 --status OK

OUT=$(HOME="$TMPHOME" "$BIN" t-x)
echo "$OUT" | grep -q "root" || { echo "FAIL: root span missing"; echo "$OUT"; exit 1; }
echo "$OUT" | grep -q "tool.Bash" || { echo "FAIL: child span missing"; exit 1; }
# s-slow (450ms) is >> p95 of the noise set (~70ms) → must flag bottleneck
echo "$OUT" | grep -q "bottleneck" || { echo "FAIL: bottleneck flag missing"; echo "$OUT"; exit 1; }

echo "test-obs-trace: PASS"
