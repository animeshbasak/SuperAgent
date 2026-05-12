#!/usr/bin/env python3
"""PreCompact hook — snapshot recent routes/learnings before window compacts.

Writes a small log file under ~/.superagent/logs/precompact-<ts>.jsonl containing
the last N=20 routes from routes.jsonl. If `claude-mem` is on PATH, also try a
best-effort `claude-mem ingest` of the snapshot — but never block on its absence.
"""
import datetime
import json
import os
import shutil
import subprocess
import sys


SNAPSHOT_DIR = os.path.expanduser("~/.superagent/logs")
ROUTES = os.path.expanduser("~/.superagent/brain/routes.jsonl")


def main():
    try:
        sys.stdin.read()
    except Exception:
        pass

    os.makedirs(SNAPSHOT_DIR, exist_ok=True)
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    snapshot = os.path.join(SNAPSHOT_DIR, f"precompact-{ts}.jsonl")

    lines = []
    if os.path.exists(ROUTES):
        try:
            with open(ROUTES) as f:
                lines = f.readlines()[-20:]
        except Exception:
            lines = []

    try:
        with open(snapshot, "w") as f:
            f.writelines(lines)
    except Exception:
        pass

    cmem = shutil.which("claude-mem")
    if cmem:
        try:
            subprocess.run([cmem, "ingest", snapshot], timeout=2, capture_output=True)
        except Exception:
            pass

    sys.stdout.write(json.dumps({"hookSpecificOutput": {"hookEventName": "PreCompact"}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
