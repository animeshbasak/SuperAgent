# SuperAgent — Per-Skill Agent Memory

Convention for per-skill persistent memory. Lets each skill accumulate its own
domain learnings without polluting the global `mempalace` index.

## Layout

```
~/.superagent/agent-memory/
├── <skill-name>/
│   ├── MEMORY.md         ← human-readable index (one bullet per fact)
│   ├── learnings.jsonl   ← append-only structured log
│   └── refs/             ← optional: pinned snippets, command outputs
```

## Lifecycle

1. **Read on demand.** When a skill activates, the brain may load
   `~/.superagent/agent-memory/<skill>/MEMORY.md` (≤4 KB) into context as a
   system reminder. No automatic preload to keep token cost low.

2. **Write on success.** When a skill completes a non-trivial task, it appends
   one structured line to `learnings.jsonl`:

   ```json
   {"ts": "2026-05-04T12:00Z", "task_hash": "abc123", "kind": "feedback|fact|pattern", "content": "..."}
   ```

3. **Distill periodically.** A weekly job (or `Stop` hook on milestone) reduces
   the JSONL into `MEMORY.md` bullets. Keep it short — if you can't fit the
   skill's hard-won knowledge into 50 bullets, you're hoarding.

## What belongs here vs. mempalace

| Memory type | Per-skill (`agent-memory/`) | Global (`mempalace`) |
|---|---|---|
| Project facts (deadlines, who-does-what) | ❌ | ✅ |
| User preferences | ❌ | ✅ |
| Skill-specific gotchas (e.g. framer-motion + RSC pitfalls) | ✅ | ❌ |
| Tool versions tested with | ✅ | ❌ |
| Cross-session decisions | ❌ | ✅ |

If a fact would help any future skill in any project, it belongs in
`mempalace`. If it only helps one skill, it belongs here.

## Reading from a skill

```python
import json, os
from pathlib import Path

mem_dir = Path.home() / ".superagent" / "agent-memory" / "<skill-name>"
memory = (mem_dir / "MEMORY.md").read_text() if (mem_dir / "MEMORY.md").exists() else ""
```

## Writing from a skill

```bash
mkdir -p ~/.superagent/agent-memory/<skill-name>
printf '%s\n' "{\"ts\":\"$(date -u +%FT%TZ)\",\"kind\":\"pattern\",\"content\":\"...\"}" \
  >> ~/.superagent/agent-memory/<skill-name>/learnings.jsonl
```

## Initialization

`hooks/superagent-state-init.sh` creates the root directory. Skills that opt in
ship a `MEMORY.md.template` alongside `SKILL.md`; the installer copies it to
`~/.superagent/agent-memory/<skill>/MEMORY.md` if missing.
