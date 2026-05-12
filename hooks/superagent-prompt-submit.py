#!/usr/bin/env python3
"""UserPromptSubmit hook — classify the user prompt and inject an announce block.

Reads a Claude Code UserPromptSubmit JSON payload from stdin, runs the SA classifier
on the prompt text, and writes back a hookSpecificOutput envelope containing an
`additionalContext` block that summarizes the routing plan. Bails silently on any
error so a broken classifier never blocks the user's prompt.
"""
import json
import os
import shutil
import subprocess
import sys


def _emit(obj):
    sys.stdout.write(json.dumps(obj))
    sys.stdout.flush()


def main():
    try:
        raw = sys.stdin.read()
    except Exception:
        return 0

    try:
        payload = json.loads(raw or "{}")
    except Exception:
        return 0

    prompt = (payload.get("prompt") or "").strip()
    if not prompt:
        _emit({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit"}})
        return 0

    classifier = shutil.which("superagent-classify") or os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "bin", "superagent-classify"
    )
    classifier = os.path.abspath(classifier)

    chain = []
    complexity = "moderate"
    categories = []
    if os.path.exists(classifier):
        try:
            r = subprocess.run(
                [classifier, prompt],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if r.returncode == 0 and r.stdout.strip():
                data = json.loads(r.stdout)
                chain = data.get("chain") or []
                meta = data.get("meta") or {}
                complexity = meta.get("complexity", "moderate")
                categories = meta.get("categories") or []
        except Exception:
            pass

    # ── AIDefence (Wave 2) ──────────────────────────────────────────────────────
    aidefence_enabled = os.path.exists(
        os.path.expanduser("~/.superagent/aidefence/enabled")
    )
    if aidefence_enabled:
        aidefence_bin = shutil.which("superagent-aidefence") or os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "..", "bin", "superagent-aidefence"
        )
        aidefence_bin = os.path.abspath(aidefence_bin)
        try:
            r = subprocess.run(
                [aidefence_bin, "scan", prompt],
                capture_output=True, text=True, timeout=2,
            )
            if r.returncode == 0 and r.stdout.strip():
                verdict = json.loads(r.stdout)
                critical = any(t.get("severity") == "critical" for t in verdict.get("threats", []))
                high = any(t.get("severity") == "high" for t in verdict.get("threats", []))
                if critical:
                    _emit({
                        "decision": "deny",
                        "hookSpecificOutput": {
                            "hookEventName": "UserPromptSubmit",
                            "additionalContext": "AIDefence: critical threat detected — request blocked.",
                        },
                        "stopReason": "aidefence-critical",
                    })
                    return 0
                if high:
                    _emit({
                        "decision": "ask",
                        "hookSpecificOutput": {
                            "hookEventName": "UserPromptSubmit",
                            "additionalContext": "AIDefence: high-severity threat — confirm before proceeding.",
                        },
                    })
                    return 0
        except Exception:
            pass

    lines = [
        "## SuperAgent route",
        f"Complexity: {complexity}" + (f"  Categories: {', '.join(categories)}" if categories else ""),
        "Chain: " + (" → ".join(chain) if chain else "(no chain — using default)"),
    ]
    additional_context = "\n".join(lines)

    _emit({
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": additional_context,
        }
    })
    return 0


if __name__ == "__main__":
    sys.exit(main())
