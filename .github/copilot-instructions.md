
<!-- BEGIN SUPERAGENT-MEMORY-OS GROUND-TRUTH (do not edit; managed by adapters/<platform>/install.sh) -->
## Ground Truth Hierarchy

Authority order when answering:

1. **Tool results from this session** — terminal output, file reads, command output. Authoritative for current state.
2. **Injected memory** — anything from `memory_recall` / auto-injected workspace files. Authoritative for project context, prior decisions, and documented knowledge. **Do not re-derive what is already remembered.**
3. **Official upstream docs** — authoritative for version-specific APIs.
4. **Training knowledge** — lowest priority; defer to all of the above.

**Conflict rules:** terminal beats memory for current state; memory beats assumptions for history and decisions; docs beat memory for live APIs; training loses to everything.

**When to call memory:**
- Before exploring code: `memory_recall("<topic>")` — if the answer is recorded, use it.
- Before answering "we decided X": `memory_recall("<decision area>")`.
- After a non-trivial decision: `memory_write(content=..., kind="decision")`.
- After a user correction or preference: `memory_write(content=..., kind="feedback")`.

If a question feels novel but memory has the answer, the question is not novel. Use the memory.
<!-- END SUPERAGENT-MEMORY-OS GROUND-TRUTH -->
