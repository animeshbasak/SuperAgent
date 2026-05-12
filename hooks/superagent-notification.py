#!/usr/bin/env python3
"""Notification hook — filter noisy notifications.

Pass-through for level 'error' or 'warning'. Drop most 'info'-level pings unless
the message contains a critical keyword. Never blocks; only sets suppressOutput.
"""
import json
import sys


CRITICAL_INFO_TOKENS = ("rate limit", "429", "quota", "throttle", "blocked")


def main():
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw or "{}")
    except Exception:
        sys.stdout.write(json.dumps({"hookSpecificOutput": {"hookEventName": "Notification"}, "suppressOutput": False}))
        return 0

    level = (payload.get("notification_level") or "info").lower()
    msg = (payload.get("notification_message") or "").lower()

    if level in ("error", "warning"):
        suppress = False
    else:
        suppress = not any(tok in msg for tok in CRITICAL_INFO_TOKENS)

    sys.stdout.write(json.dumps({
        "hookSpecificOutput": {"hookEventName": "Notification"},
        "suppressOutput": suppress,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
