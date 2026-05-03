#!/usr/bin/env python3
# superagent-safety.py — PreToolUse reversibility-aware action gate
#
# Wired by install.sh into ~/.claude/settings.json under hooks.PreToolUse.
# Reads Claude Code hook JSON from stdin, emits a decision JSON to stdout.
#
# Decisions:
#   - allow: tool runs without prompting
#   - ask:   user is prompted to confirm
#   - deny:  tool is blocked, model is told why
#
# Pre-authorization sources (in order):
#   1. ~/.superagent/safety/allow.txt        — one regex per line
#   2. CLAUDE.md "## SuperAgent Safety Allow" section bullets
#   3. settings.local.json permissions.allow (Claude already honors)
#
# Bypass: SUPERAGENT_SAFETY=off in env disables the gate entirely.
#
# Local-only mode (~/.superagent/local-only present): network egress patterns
# (curl/wget to non-localhost) are also gated.

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

# ──────────────────────────────────────────────────────────────────────────────
# Risky patterns (regex, anchored loosely)
# ──────────────────────────────────────────────────────────────────────────────

RISKY_BASH = [
    # Destructive filesystem
    (r"\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)", "rm -rf"),
    (r"\bsudo\s+rm\b",                                          "sudo rm"),
    (r"^\s*:\(\)\s*\{\s*:\|:&\s*\}\s*;\s*:\s*$",                "fork bomb"),
    (r"\bchmod\s+-R\s+0?777\b",                                 "chmod -R 777"),
    (r"\bdd\s+if=.*\s+of=/dev/(sd[a-z]|disk[0-9]|nvme[0-9])",   "dd to raw disk"),
    (r">\s*/dev/(sd[a-z]|disk[0-9]|nvme[0-9])",                 "redirect to raw disk"),
    (r"\bmkfs\.[a-z0-9]+\b",                                    "mkfs"),

    # Git destructive
    (r"\bgit\s+push\s+(?:--force\b|--force[^=]|-f\b)",          "git push --force"),
    (r"\bgit\s+reset\s+--hard\b",                               "git reset --hard"),
    (r"\bgit\s+clean\s+-[a-zA-Z]*f",                            "git clean -f"),
    (r"\bgit\s+checkout\s+\.",                                  "git checkout ."),
    (r"\bgit\s+restore\s+\.",                                   "git restore ."),
    (r"\bgit\s+branch\s+-D\b",                                  "git branch -D"),
    (r"--no-verify\b",                                          "skipping git hooks (--no-verify)"),
    (r"\bgit\s+commit\s+--amend\b",                             "git commit --amend"),
    (r"\bgit\s+rebase\s+-i\b",                                  "interactive rebase"),

    # Database destructive
    (r"\bDROP\s+(TABLE|DATABASE|SCHEMA|INDEX|VIEW)\b",          "DROP statement"),
    (r"\bTRUNCATE\s+TABLE\b",                                   "TRUNCATE"),
    (r"\bDELETE\s+FROM\s+\w+(?!\s+WHERE\b)",                    "unbounded DELETE FROM"),
    (r"\bUPDATE\s+\w+\s+SET\b(?![^;]*\bWHERE\b)",               "unbounded UPDATE"),

    # Migrations / package downgrades
    (r"\bmigrate\s+down\b",                                     "migrate down"),
    (r"\bmigration:rollback\b",                                 "migration rollback"),
    (r"\bnpm\s+uninstall\b",                                    "npm uninstall"),
    (r"\bpip\s+uninstall\b",                                    "pip uninstall"),

    # Process / network mass-kill
    (r"\bkill(all)?\s+-9\s+",                                   "kill -9"),
    (r"\bpkill\s+-9\b",                                         "pkill -9"),

    # Permission-skip / sandbox-escape (these should never be issued by Claude)
    (r"--dangerously-skip-permissions",                         "--dangerously-skip-permissions"),
]

RISKY_NETWORK = [
    (r"\bcurl\b[^|]*\bhttps?://(?!(?:localhost|127\.0\.0\.1|0\.0\.0\.0|::1))",  "curl to remote host"),
    (r"\bwget\b[^|]*\bhttps?://(?!(?:localhost|127\.0\.0\.1|0\.0\.0\.0|::1))",  "wget remote"),
]

# Edit/Write tools — block edits to sensitive files unless pre-approved
SENSITIVE_PATHS = [
    re.compile(r"(^|/)\.env(\.|$)"),
    re.compile(r"/\.aws/credentials$"),
    re.compile(r"/\.ssh/id_(rsa|ed25519|dsa|ecdsa)$"),
    re.compile(r"/id_(rsa|ed25519|dsa|ecdsa)\.pub$"),
    re.compile(r"\.pem$"),
    re.compile(r"\.key$"),
    re.compile(r"^/etc/"),
    re.compile(r"^/System/"),
    re.compile(r"\.netrc$"),
]


# ──────────────────────────────────────────────────────────────────────────────
# Pre-authorization
# ──────────────────────────────────────────────────────────────────────────────

def load_allow_patterns() -> list[re.Pattern]:
    home = Path.home()
    sources = [
        home / ".superagent" / "safety" / "allow.txt",
        home / ".claude" / "CLAUDE.md",
    ]
    patterns: list[re.Pattern] = []
    for src in sources:
        if not src.exists():
            continue
        try:
            text = src.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        if src.name == "CLAUDE.md":
            # Extract bullets under "## SuperAgent Safety Allow" through next heading
            m = re.search(
                r"^##+\s*SuperAgent\s+Safety\s+Allow\s*$(.*?)(?=^##+\s|\Z)",
                text, flags=re.M | re.S | re.I,
            )
            if not m:
                continue
            block = m.group(1)
            for line in block.splitlines():
                line = line.strip()
                if line.startswith("- ") or line.startswith("* "):
                    pat = line[2:].strip().strip("`")
                    if pat:
                        try:
                            patterns.append(re.compile(pat))
                        except re.error:
                            pass
        else:
            for line in text.splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                try:
                    patterns.append(re.compile(line))
                except re.error:
                    pass
    return patterns


def is_pre_approved(payload: str, allowed: list[re.Pattern]) -> bool:
    return any(p.search(payload) for p in allowed)


# ──────────────────────────────────────────────────────────────────────────────
# Classification
# ──────────────────────────────────────────────────────────────────────────────

def classify_bash(command: str) -> tuple[str | None, str | None]:
    for pattern, label in RISKY_BASH:
        if re.search(pattern, command, flags=re.I):
            return label, "risky"
    if (Path.home() / ".superagent" / "local-only").exists():
        for pattern, label in RISKY_NETWORK:
            if re.search(pattern, command, flags=re.I):
                return label, "network"
    return None, None


def classify_path(path: str) -> str | None:
    if not path:
        return None
    for pat in SENSITIVE_PATHS:
        if pat.search(path):
            return f"sensitive path ({path})"
    return None


# ──────────────────────────────────────────────────────────────────────────────
# Hook entrypoint
# ──────────────────────────────────────────────────────────────────────────────

def emit(decision: str, reason: str = "", *, exit_code: int = 0) -> None:
    """Emit Claude Code hook response and exit.

    Claude Code understands either a JSON object on stdout with
    `permissionDecision`/`reason`, or exit code 2 (block + stderr).
    We use stdout JSON for ask/allow, exit 2 for hard block."""
    if decision == "deny":
        sys.stderr.write(f"[superagent-safety] BLOCKED: {reason}\n")
        sys.exit(2)
    out = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }
    }
    sys.stdout.write(json.dumps(out))
    sys.stdout.write("\n")
    sys.exit(exit_code)


def main() -> None:
    if os.environ.get("SUPERAGENT_SAFETY") == "off":
        emit("allow", "safety gate disabled via SUPERAGENT_SAFETY=off")
        return

    try:
        raw = sys.stdin.read()
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        # Malformed input — don't block, let Claude handle it.
        emit("allow", "malformed hook input")
        return

    tool_name = payload.get("tool_name") or payload.get("toolName") or ""
    tool_input = payload.get("tool_input") or payload.get("toolInput") or {}

    label: str | None = None

    if tool_name == "Bash":
        cmd = tool_input.get("command", "") or ""
        risky, _kind = classify_bash(cmd)
        label = risky
        scan_text = cmd
    elif tool_name in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        path = tool_input.get("file_path") or tool_input.get("filePath") or ""
        label = classify_path(path)
        scan_text = path
    else:
        emit("allow", "tool not gated")
        return

    if not label:
        emit("allow", "no risky pattern matched")
        return

    allowed = load_allow_patterns()
    if is_pre_approved(scan_text, allowed):
        emit("allow", f"pre-approved override matched ({label})")
        return

    # Default: ask the user. Use deny only for absolute red lines.
    if label == "fork bomb" or label.startswith("dd to raw disk") or "mkfs" in label:
        emit("deny", f"superagent-safety refuses: {label}")
        return

    emit("ask", f"superagent-safety: {label} — confirm before proceeding")


if __name__ == "__main__":
    main()
