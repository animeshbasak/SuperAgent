---
name: bench
---
# bench

> Run the 20-prompt classifier bench and print the score. Use after editing rules.yaml or after adding a new skill that affects routing.

# Bench

> **Ethos:** Verify or die.

## When to use
- After any change to `skills/superagent/brain/rules.yaml`.
- After adding a new skill that should route via a new regex.
- As a pre-merge gate — the CI workflow runs this automatically.

## Procedure

1. Detect the repo root (the directory that contains `bench/run.sh`).
2. Run:
   ```bash
   bash bench/run.sh
   ```
3. Capture output and exit code.
4. If exit code == 0: report `PASS` + the avg score.
5. If non-zero: print the per-prompt misses. Suggest which `rules.yaml` regex to tune by correlating misses with rule names.

## Output

```
Bench: PASS=N FAIL=M AVG=X.XX
```

If FAIL > 0: per-prompt diagnostics + a ranked list of rules to tune.

## Verification

Exit non-zero if avg < 0.90 OR fails > 2 (hard gate thresholds from Task 1.3).
