#!/usr/bin/env python3
"""SubagentStop hook — log subagent outcome to ~/.superagent/brain/routes.jsonl
with subagent:true so we can attribute cost and route success back to a parent.
"""
import json
import os
import sys
import datetime


def main():
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw or "{}")
    except Exception:
        return 0

    success = bool((payload.get("tool_output") or {}).get("success", True))
    outcome = "done" if success else "fail"
    description = (payload.get("tool_input") or {}).get("description", "") or ""
    session_id = payload.get("session_id", "")

    record = {
        "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "task_hash": "",
        "task": description[:200],
        "chain": [],
        "outcome": outcome,
        "user_override": "no",
        "backend": os.environ.get("SUPERAGENT_BACKEND", "anthropic"),
        "subagent": True,
        "session_id": session_id,
    }

    routes = os.path.expanduser("~/.superagent/brain/routes.jsonl")
    os.makedirs(os.path.dirname(routes), exist_ok=True)
    try:
        with open(routes, "a") as f:
            f.write(json.dumps(record) + "\n")
    except Exception:
        pass

    sys.stdout.write(json.dumps({"hookSpecificOutput": {"hookEventName": "SubagentStop"}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
