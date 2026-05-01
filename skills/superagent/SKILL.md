---
name: superagent
description: Master entrypoint. Takes a task, classifies it, composes a skill chain, announces the plan, executes. Use whenever the user types /superagent <task> or says "use superagent for X".
argument-hint: "<task description>"
---

# SuperAgent Router

> **Ethos:** Verify or die. Rewind, don't correct. Memory compounds. Leverage over toil. Local first.

## When to use
- User invokes `/superagent <task>`.
- User says "superagent this", "full power mode", "activate all agents".
- Any complex task where you're unsure which skills to chain.

## Procedure

**1. Detect backend (always).** First call only:
```bash
backend=$(superagent-switch status 2>/dev/null | awk '/^mode:/ {print $2}')
[ -z "$backend" ] && backend="anthropic"
```
If `backend=local`, run in **lite mode**: skip step 2 context load, cap chain at 3 skills, shorter announce format, prefer `agent-skills:*` skills (more deterministic step-by-step) over open-ended ones. Local models handle structured checklists better than free-form reasoning.

**2. Load context (cloud only).** Skip on local backend. Otherwise run once per session:
```bash
command -v mempalace >/dev/null 2>&1 && mempalace wake-up 2>/dev/null | head -60 || true
```

**3. Classify.** Run the classifier on `$ARGUMENTS`:
```bash
if command -v superagent-classify >/dev/null 2>&1; then
  superagent-classify "$ARGUMENTS"
else
  echo '{"chain":[],"hint":null}'
fi
```
Output is JSON `{chain: [...], hint: [...|null]}`. **If classifier missing or chain empty:** fall back to keyword matching against the available skills list shown in your system reminders — including the `agent-skills:*` namespace (16 skills imported from agent-skills covering define → plan → build → verify → ship). Pick top-3 by description overlap and ask user.

**4. Announce.** Print to the user:
```
SuperAgent routing plan for: "<task>"
Backend: <anthropic|local:model-name>
Chain: skill1 → skill2 → skill3
Rationale: <one line why each skill was selected>
Estimated effort: <rough>
Proceed? (yes / edit / skip N / run-only N)
```
On local backend, omit Rationale and Estimated effort lines — keep announce ≤4 lines total.

**5. Auto-execute (default).** Do NOT ask "Proceed?". The user opted in by invoking SuperAgent. Skip the confirmation gate and start running the chain immediately.

**Opt-in confirm prefix.** If `$ARGUMENTS` starts with `? ` (literal question mark + space), strip the prefix before classifying and run in **confirm mode** for this call only — show the chain and wait for `yes/edit/skip N/run-only N`. Pre-process (works in bash and zsh):
```bash
TASK="$ARGUMENTS"
CONFIRM="auto"
if [ "${TASK:0:2}" = "? " ]; then
  CONFIRM="yes"
  TASK="${TASK#? }"
fi
```

**Force-confirm (override auto, even without `?` prefix):**
- Task or chain contains a destructive op: `ship`, `deploy`, `push`, `force`, `delete`, `drop`, `rm`, `migrate down`, `revert`, `reset --hard`.
- Chain includes `cso` or `security-review` (findings should be reviewed first).
- Local backend AND chain length > 3 (offer to trim or confirm full plan).
- Classifier returned empty/`mempalace-wake` only AND keyword-match has no high-confidence single skill.

**6. Execute.** For each skill in the chain, invoke via the Skill tool in order. Between skills, summarize the artifact produced in one sentence. If a skill fails or user says "stop", halt and report.

**7. Log.** After completion (or halt), append to `~/.superagent/brain/routes.jsonl` (auto-create if missing):
```bash
mkdir -p ~/.superagent/brain
# then append the route record
```
```json
{"ts": "<iso>", "task_hash": "<sha256-12>", "task": "<first 120 chars>", "chain": [...], "outcome": "done|halt|fail", "user_override": "yes|no", "backend": "<anthropic|local>"}
```

## Skill namespaces

The roster is organized into namespaces. Pick from any:

- **Bare names** — core SuperAgent skills (`ship`, `review`, `cso`, `simplify`, `investigate`, `learn`, plan-* family, `auto-fallback`, `superagent-switch`, `free-llm`, etc.)
- **`agent-skills:*`** — Addy Osmani's production engineering skills (16 skills): `idea-refine`, `spec-driven-development`, `planning-and-task-breakdown`, `incremental-implementation`, `test-driven-development`, `context-engineering`, `source-driven-development`, `frontend-ui-engineering`, `api-and-interface-design`, `browser-testing-with-devtools`, `debugging-and-error-recovery`, `performance-optimization`, `git-workflow-and-versioning`, `ci-cd-and-automation`, `deprecation-and-migration`, `documentation-and-adrs`. Step-by-step + verifiable; preferred when a process must be followed exactly (especially on local models).
- **`superpowers:*`** — Claude Code superpowers (TDD, debugging, brainstorming, plan execution).
- **`claude-mem:*`, `caveman:*`, `vercel:*`, `ui-ux-pro-max:*`** — domain plugins.

When a core skill and an `agent-skills:*` skill overlap (e.g. `simplify` vs `agent-skills:incremental-implementation` for refactor work), the bare-name SuperAgent skill wins by default. Prefer the `agent-skills:*` version explicitly when the user wants step-by-step rigor or when running on a local model.

## Local-backend rules (when `backend=local`)

Local models (Qwen, Llama, DeepSeek via free-claude-code proxy) need extra discipline:

- **Cap chains at 3 skills.** Longer chains lose coherence on weaker models.
- **No mempalace pre-load.** Saves ~4k tokens of context the model can't use well.
- **Prefer `agent-skills:*`** for build/verify/ship tasks — their explicit checklists translate better than free-form skill prose.
- **Skip `claude-api` skill** — it's Anthropic-SDK-specific and confuses non-Anthropic backends. Suggest `free-llm` if user wants AI-app guidance.
- **Single-skill route by default** for trivial questions — don't chain just to chain.
- **Don't promise tool reliability.** If a skill needs a specific MCP (Chrome DevTools, Notion, etc.), tell the user to verify it's connected before running.

## Fallback — classifier uncertain
If classifier is missing or returns an empty chain:
1. Read the available skills list from your system reminders.
2. Match user's task keywords against skill descriptions (prefer exact verb matches: "build" → builds, "fix" → debugging, "ship" → ship).
3. Show top-3 candidates and let user pick.
4. Never invent a skill name not in the list.

## What stays manual
- Plan Mode (Shift+Tab twice) — user's call.
- Rewind (Esc Esc) — user's call.
- Permission grants — `/permissions`.
- Backend switch — user runs `/superagent-switch to <model>` or `back`.

## Verification
After each skill runs, require the skill's own output. For build/fix chains, the final `verification-before-completion` (or `agent-skills:test-driven-development` Verification block on local backend) must pass before declaring done.
