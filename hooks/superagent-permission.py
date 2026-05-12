#!/usr/bin/env python3
"""PermissionRequest hook — auto-allow Bash commands matching ~/.superagent/safety/allow.txt.

Each line in allow.txt is either a comment (`#`) or a regex matched against the
command string. Empty lines ignored. On any error, default to 'ask' (the safe
fallback that hands back to Claude Code's normal permission flow).
"""
import json
import os
import re
import sys


ALLOW_PATH = os.path.expanduser("~/.superagent/safety/allow.txt")


def _decision(verdict, reason=""):
    sys.stdout.write(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PermissionRequest",
            "permissionDecision": verdict,
            "permissionDecisionReason": reason,
        }
    }))


def main():
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw or "{}")
    except Exception:
        _decision("ask", "could not parse payload")
        return 0

    tool_name = payload.get("tool_name", "")
    cmd = (payload.get("tool_input") or {}).get("command", "") or ""

    if tool_name != "Bash" or not cmd:
        _decision("ask", "non-Bash or empty command")
        return 0

    if not os.path.exists(ALLOW_PATH):
        _decision("ask", "no allow-list configured")
        return 0

    try:
        with open(ALLOW_PATH) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                try:
                    if re.search(line, cmd):
                        _decision("allow", f"matched allow-list pattern: {line}")
                        return 0
                except re.error:
                    continue
    except Exception:
        pass

    _decision("ask", "no allow-list pattern matched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
