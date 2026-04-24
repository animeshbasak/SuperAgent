#!/usr/bin/env bash
# bench/score.sh — LCS similarity between two JSON arrays
# Usage: bash bench/score.sh '$expected_json_array' '$actual_json_array'
# Output: score in range [0.00 .. 1.00]  (lcs_length / max(|expected|, |actual|))

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: score.sh <expected_json_array> <actual_json_array>" >&2
  exit 1
fi

python3 - "$1" "$2" <<'PYEOF'
import sys
import json

try:
    expected = json.loads(sys.argv[1])
    actual   = json.loads(sys.argv[2])
except json.JSONDecodeError as e:
    print(f"score.sh: JSON parse error: {e}", file=sys.stderr)
    sys.exit(1)

m, n = len(expected), len(actual)

if m == 0 and n == 0:
    print("1.00")
    sys.exit(0)

if m == 0 or n == 0:
    print("0.00")
    sys.exit(0)

# ordered LCS via DP
dp = [[0] * (n + 1) for _ in range(m + 1)]
for i in range(1, m + 1):
    for j in range(1, n + 1):
        if expected[i - 1] == actual[j - 1]:
            dp[i][j] = dp[i - 1][j - 1] + 1
        else:
            dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])

lcs_len = dp[m][n]
score = lcs_len / max(m, n)
print(f"{score:.2f}")
PYEOF
