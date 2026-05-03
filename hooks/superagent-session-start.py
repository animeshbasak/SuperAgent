#!/usr/bin/env python3
# superagent-session-start.py — SessionStart hook
#
# Fires once when a Claude Code session starts. Loads lightweight context
# the brain wants available without paying the full mempalace wake cost.
#
# Outputs a small JSON `additionalContext` block that Claude Code injects
# into the session as a system reminder.
#
# Cheap by design: no shelling out, no network, ~50 lines of context max.

from __future__ import annotations

import datetime as dt
import json
import os
import sys
from pathlib import Path


def read_or_empty(path: Path, max_bytes: int = 4096) -> str:
    try:
        if not path.exists():
            return ""
        return path.read_text(encoding="utf-8", errors="ignore")[:max_bytes]
    except Exception:
        return ""


def routes_summary(routes_path: Path, n: int = 5) -> str:
    text = read_or_empty(routes_path, 16_384)
    if not text.strip():
        return ""
    lines = [ln for ln in text.splitlines() if ln.strip()][-n:]
    out: list[str] = []
    for ln in lines:
        try:
            r = json.loads(ln)
        except Exception:
            continue
        chain = " → ".join(r.get("chain", [])) or "-"
        out.append(f"  - {r.get('ts','')[:16]} [{r.get('outcome','?')}] {chain}")
    if not out:
        return ""
    return "Recent routes (last 5):\n" + "\n".join(out)


def main() -> None:
    if os.environ.get("SUPERAGENT_SAFETY") == "off":
        sys.exit(0)

    home = Path.home()
    state = home / ".superagent"
    routes = state / "brain" / "routes.jsonl"
    local_only = state / "local-only"

    parts: list[str] = []
    parts.append(
        f"## SuperAgent context\n"
        f"Date: {dt.date.today().isoformat()}\n"
        f"Backend mode: {'local-only' if local_only.exists() else 'mixed'}"
    )
    rs = routes_summary(routes)
    if rs:
        parts.append(rs)

    body = "\n\n".join(parts)
    out = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": body,
        }
    }
    sys.stdout.write(json.dumps(out))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
