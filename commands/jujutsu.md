---
name: jujutsu
description: DEPRECATED alias for /diff-risk. Use /diff-risk instead — this slash exists only for backward compatibility.
---

# /jujutsu (deprecated)

This slash is the legacy alias for `/diff-risk`. The skill was renamed in v2.6 to avoid collision with the Jujutsu VCS.

## Behavior

1. Print a one-line deprecation note to stderr:
   `→ /jujutsu is a deprecation alias; use /diff-risk going forward.`
2. Forward the user's subcommand to `bin/superagent-diff-risk` exactly as `/diff-risk` would.

## Why renamed

"Jujutsu" is also a real VCS (https://github.com/jj-vcs/jj). Reusing the name for a git-diff scorer confuses users who think it integrates with that VCS. The slash is preserved so existing scripts don't break.
