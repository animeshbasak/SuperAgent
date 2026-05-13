# testgen

> Coverage gap detection + test scaffolding. Calls the project's own coverage tool (jest/vitest/pytest/tarpaulin/go-cover), normalizes the JSON output, ranks files by gap × LOC, and emits a markdown skeleton naming the tests to write — never the bodies. Triggers on "coverage", "untested", "test coverage", "testgen", "tdd gap", "scaffold tests", "coverage gap".

# testgen

Wave 3 ships an opt-in coverage adapter that augments TDD. Testgen is the inspector; the `tester` agent (Wave 2) and `agent-skills:test-driven-development` are the implementers. Testgen **never writes test bodies**.

## When to use

- The user asks "where's our coverage weakest" / "scaffold tests for X" / "coverage gap report".
- About to refactor untested code — generate the lock-down test list first.
- `ship` skill consults testgen to refuse a regression in coverage before push.

## Procedure

1. **Scan** — runs the project's coverage tool and caches a normalized report:
   ```bash
   superagent-testgen scan                                  # auto-detect format
   superagent-testgen scan --fixture coverage-summary.json  # bypass tool spawn
   ```
   Supported formats: jest (`coverage-summary.json`), pytest (`coverage.json`), with the same shape for vitest. Other tools (tarpaulin, go-cover) can be added by extending the format detector.
2. **Rank** — list the largest gaps by `gap × LOC`:
   ```bash
   superagent-testgen gap --top 5
   ```
3. **Scaffold** for a specific file — emit a markdown skeleton:
   ```bash
   superagent-testgen suggest src/auth.ts
   ```
   Output includes uncovered line ranges (collapsed into runs like `L42-50`) and named symbols extracted from the source file. **No test bodies are written** — the skeleton names what to test.
4. **Status** — current coverage vs threshold:
   ```bash
   superagent-testgen status         # human
   superagent-testgen status --json  # for ship/review to consult
   ```

## Files

- Normalized report cache: `~/.superagent/testgen/last-report.json`.
- Project threshold: `~/.superagent/testgen/min-coverage.txt` (default 70).
- User-supplied coverage command override: `~/.superagent/testgen/cov-cmd.txt`.

## Hand-off

- For each test in the suggested skeleton, dispatch the `tester` agent (Wave 2) to write the body. The `tester` agent in turn invokes `agent-skills:test-driven-development`.
- Before `ship`, run `superagent-testgen status --json` and refuse to ship if `verdict == "BELOW THRESHOLD"` and the project enforces it.

## Ethos

Testgen lists the work; it doesn't do the work. A test the LLM wrote unprompted by a coverage gap is worth less than a test driven by a named hole in the suite. Coverage thresholds are per-project, never global — legacy code at 50% is fine if the team is at 80% for new code.
