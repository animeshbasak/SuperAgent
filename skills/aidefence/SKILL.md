---
name: aidefence
description: Per-prompt injection + PII scanner. Pure regex over 58 shipped patterns (instruction override, role switching, prompt injection, jailbreak, encoding attacks, context manipulation, PII). Wired into UserPromptSubmit hook when enabled. Default off. Triggers on "scan prompt", "prompt injection", "PII scan", "jailbreak", "enable aidefence", "defend prompts".
---

# aidefence

Wave 2 adds a per-prompt threat scanner that runs at the harness boundary before the model sees the request. It is **default off** — too many dev workflows legitimately mention words like "ignore" or include test fixtures with fake credentials. Opt in with `superagent-aidefence enable` once the patterns suit your workflow.

## When to use

- User says "turn on aidefence" / "scan this prompt" / "is this prompt safe".
- You suspect a prompt-injection payload in user-provided content (issues, docs, support tickets).
- After a security incident — review `~/.superagent/aidefence/learned.jsonl` for adaptive misfires.

## Procedure

1. **Inspect current state:**
   ```bash
   superagent-aidefence status
   superagent-aidefence list | head
   ```
2. **Enable for the session:**
   ```bash
   superagent-aidefence enable
   ```
   This drops `~/.superagent/aidefence/enabled`. The `UserPromptSubmit` hook (Wave 1) now calls `scan` on every prompt; critical severity → `deny`, high severity → `ask` (force-confirm), medium/PII → log only.
3. **Scan ad-hoc:**
   ```bash
   superagent-aidefence scan "some prompt to test"
   ```
4. **Train it down on a false positive:**
   ```bash
   superagent-aidefence feedback <pattern-id> inaccurate
   ```
   Repeated inaccurate verdicts decay that pattern's effectiveness via EMA (alpha=0.1). After ~30 events, baseline confidence collapses by ~95%, so the pattern stops blocking common phrasing.
5. **Disable when shipping safely is preferred over scanning:**
   ```bash
   superagent-aidefence disable
   ```

## Escape hatches

The scanner skips text that:

- Starts with a fenced code block (```\```) — assumed to be code, not a prompt.
- Starts with `// quote:` — used when the user is *quoting* an attack for analysis.

Both produce `{safe: true, skipped: "escape-hatch"}`.

## Files

- Shipped: `skills/aidefence/patterns.json` (58 patterns, source of truth).
- Runtime: `~/.superagent/aidefence/patterns.json` (mutable copy for tuning).
- Feedback: `~/.superagent/aidefence/learned.jsonl` (append-only EMA history).
- Flag: `~/.superagent/aidefence/enabled` (presence = on).

## Decision policy

| Severity | Hook decision | Behavior |
|---|---|---|
| `critical` | `deny` | Block the prompt with stopReason. |
| `high` | `ask` | Force-confirm in the harness. |
| `medium` / `pii_*` | log only | Append to learned.jsonl, never block. |

## Ethos

Verify or die. The scanner is a regex gate — fast (<25 ms) and explicit. It cannot catch a determined adversary, but it stops the obvious 80% of injection payloads and PII leaks that would otherwise reach the model. **Default off** because false positives erode trust faster than misses; the user opts in once they trust the corpus on their workflow.
