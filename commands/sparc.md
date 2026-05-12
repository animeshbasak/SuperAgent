---
name: sparc
description: Slash dispatcher for the SPARC 5-phase pipeline. Forwards args to bin/superagent-sparc.
---

# /sparc

Routes the user's subcommand to `bin/superagent-sparc`. See [sparc](../skills/sparc/SKILL.md) for the full procedure.

## Usage

```
/sparc init <slug>                       # scaffold ~/.superagent/sparc/<slug>/
/sparc gate                              # evaluate current phase gate
/sparc advance                           # bump phase (refuses unless gate passed)
/sparc report                            # traceability matrix output
/sparc status [--json]                   # phase + gate + last failure + artifacts
```

## Procedure

- `init <slug>` → run bin and print returned directory.
- `gate` → run bin; if exit code !=0, surface the failure reasons verbatim so the user knows what to fix.
- `advance` → run bin; on refusal, suggest running `gate` first.
- `report` → run bin; print the matrix markdown verbatim.
- `status` → human-readable by default; pass `--json` only if user asks for machine output.

Do not auto-init SPARC for the user. They opt in.
