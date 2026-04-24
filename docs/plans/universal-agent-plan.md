# SuperAgent → Universal Agent: Multi-Platform Support

> Transform SuperAgent from a Claude Code–only orchestrator into a platform-agnostic "AI coding agent enhancer" that works across **Claude Code, Codex CLI, Gemini/Antigravity, Cursor, Windsurf, Copilot, Continue.dev, Aider**, and any future agent.

## Constraint: Zero Impact on Claude Code

**The existing Claude Code implementation MUST NOT be changed.** All current skills, hooks, plugins, agents, and install behavior remain identical. Multi-platform support is additive only — new directories and files alongside the existing structure.

## Background

SuperAgent v2 is currently coupled to **Claude Code** at three layers:

| Layer | Coupling point | What makes it Claude-only |
|-------|---------------|--------------------------|
| **Config format** | `CLAUDE.md`, `.claude/`, `.claude-plugin/` | Only Claude reads these files |
| **Plugin system** | `claude plugin install`, `installed_plugins.json` | Proprietary Claude plugin registry |
| **Agent frontmatter** | `model: haiku`, `tools: Bash`, `skills:` | Claude-specific YAML keys |
| **Install script** | `install.sh` hardcodes `~/.claude/` paths | No other platform uses `~/.claude/` |

The **portable core** is already platform-agnostic:
- `skills/*/SKILL.md` → 15 skill markdowns with instructions (universally parseable)
- `skills/superagent/brain/rules.yaml` → Python regex routing, no Claude dependency
- `bin/superagent-classify` → pure bash + Python, emits JSON
- `hooks/*.sh` → standard bash scripts
- `graphify` + `mempalace` → standalone Python tools

---

## Architecture: The Adapter Pattern

Every modern AI coding agent reads markdown files from well-known paths. They differ in:
1. **Where** the files go (file names and directories)
2. **What frontmatter** they expect (YAML keys)
3. **How they discover** instructions (always-on vs glob vs manual)

### Platform Instruction Formats

| Platform | Instruction File | Location | Format |
|----------|-----------------|----------|--------|
| **Claude Code** | `CLAUDE.md` | `~/.claude/CLAUDE.md`, `.claude/` | Markdown + YAML frontmatter |
| **Codex CLI** | `AGENTS.md` | `~/.codex/AGENTS.md`, project root | Plain markdown, hierarchical |
| **Gemini/Antigravity** | `GEMINI.md` | `~/.gemini/GEMINI.md`, `.agent/rules/` | Markdown + YAML frontmatter |
| **Cursor** | `.mdc` files | `.cursor/rules/*.mdc` | Markdown + frontmatter (description, globs, alwaysApply) |
| **Windsurf** | `AGENTS.md` + rules | `.windsurf/rules/*.md`, root `AGENTS.md` | Markdown, activation modes |
| **Copilot** | `copilot-instructions.md` | `.github/copilot-instructions.md` | Single markdown file |
| **Continue.dev** | Rule files | `.continue/rules/*.md` | Markdown + optional YAML frontmatter |
| **Aider** | `CONVENTIONS.md` | Project root, `~/.aider.conf.yml` | Markdown + YAML config |

### Key Insight
All platforms read markdown. The differences are just file names, paths, and frontmatter. A **compilation step** can transform our universal skill set into each platform's format.

---

## Directory Structure (additive — no existing files moved)

```
SuperAgent/
├── (EXISTING — UNCHANGED)
│   ├── .claude/                    # Claude Code config
│   ├── .claude-plugin/             # Claude plugin manifest
│   ├── .github/                    # CI workflows
│   ├── agents/                     # Claude agent files
│   ├── bench/                      # Classifier benchmark
│   ├── bin/                        # CLI tools
│   ├── docs/                       # Documentation
│   ├── hooks/                      # Bash hooks
│   ├── skills/                     # All 15 skills
│   ├── test/                       # Tests
│   ├── CLAUDE.md                   # Claude global instructions
│   ├── ETHOS.md                    # Guiding principles
│   ├── README.md                   # Current Claude-focused README
│   └── install.sh                  # Current Claude installer
│
├── (NEW — MULTI-PLATFORM)
│   ├── adapters/
│   │   ├── codex/
│   │   │   ├── install.sh
│   │   │   └── templates/
│   │   │       └── AGENTS.md
│   │   ├── gemini/
│   │   │   ├── install.sh
│   │   │   └── templates/
│   │   │       ├── GEMINI.md
│   │   │       └── skills/           # Per-skill SKILL.md files
│   │   ├── cursor/
│   │   │   ├── install.sh
│   │   │   └── templates/
│   │   │       ├── superagent-core.mdc
│   │   │       ├── superagent-tdd.mdc
│   │   │       ├── superagent-ui.mdc
│   │   │       └── superagent-debug.mdc
│   │   ├── windsurf/
│   │   │   ├── install.sh
│   │   │   └── templates/
│   │   │       ├── AGENTS.md
│   │   │       └── rules/
│   │   ├── copilot/
│   │   │   ├── install.sh
│   │   │   └── templates/
│   │   │       └── copilot-instructions.md
│   │   ├── continue/
│   │   │   ├── install.sh
│   │   │   └── templates/
│   │   │       └── rules/
│   │   └── aider/
│   │       ├── install.sh
│   │       └── templates/
│   │           ├── CONVENTIONS.md
│   │           └── .aider.conf.yml
│   ├── bin/
│   │   └── superagent-compile       # Skill-to-platform compiler
│   ├── install-universal.sh          # Multi-platform installer (separate from install.sh)
│   └── docs/
│       └── platforms/                # Per-platform guides
```

---

## Skill Compilation Strategy

### The Problem
Each platform has different context limits and loading mechanisms:
- **Cursor**: 12,000 char total limit across all active rules → needs compact format
- **Codex/Windsurf**: Single AGENTS.md → needs everything inlined
- **Gemini/Antigravity**: SKILL.md files → near-identical to current format
- **Copilot**: Single file → needs compact compilation

### The Solution: `superagent-compile`

A build script that reads all 15 skills and produces platform-specific output:

```bash
# Generate for a specific platform
superagent-compile --platform codex --output adapters/codex/templates/AGENTS.md
superagent-compile --platform cursor --output adapters/cursor/templates/
superagent-compile --platform gemini --output adapters/gemini/templates/skills/
```

Compilation modes:
- **Full**: All skills concatenated (Codex, Windsurf, Aider)
- **Compact**: Routing table + skill summaries + key rules (<12k chars for Cursor)
- **Modular**: Individual files per skill (Gemini, Continue.dev)

### What Gets Compiled

For each skill, the compiler extracts:
1. **Name** and **description** from frontmatter
2. **When to use** triggers
3. **Procedure** steps
4. **Verification** requirements

Platform-specific frontmatter is added:
- Cursor: `description`, `globs`, `alwaysApply`
- Gemini: `name`, `description` (same as Claude, easiest port)
- Continue: `name` in YAML frontmatter
- Others: No frontmatter needed (plain markdown)

### Routing Brain Adaptation

The routing brain (`rules.yaml` + `superagent-classify`) currently runs as bash + Python. For platforms that can't execute arbitrary tools:

| Platform | Tool execution? | Routing strategy |
|----------|----------------|-----------------|
| Claude Code | ✅ Full bash/Python | `superagent-classify` (current) |
| Codex CLI | ✅ Can run bash | `superagent-classify` (same) |
| Gemini/Antigravity | ✅ Can run bash | `superagent-classify` (same) |
| Cursor | ❌ No tool execution | Routing table as prompt instructions |
| Windsurf | ✅ Can run bash | `superagent-classify` (same) |
| Copilot | ❌ No tool execution | Routing table as prompt instructions |
| Continue.dev | ❌ Limited | Routing table as prompt instructions |
| Aider | ✅ Can run bash | `superagent-classify` (same) |

For platforms without tool execution, the compiled output includes the full routing table as **prompt instructions**:

```markdown
## Task Routing (follow this automatically)

When the user's task matches these patterns, follow the corresponding procedure:

| Pattern | Procedure |
|---------|-----------|
| bug, fix, broken, error, crash | → systematic-debugging → TDD |
| build, create, implement + feature | → brainstorming → writing-plans → TDD → executing-plans |
| design, UI, UX, component | → brainstorming → ui-ux-pro-max |
| ... | ... |
```

---

## Execution Phases

### Phase 1: Compiler + Codex Adapter (~2 hours)
Build `superagent-compile` and the Codex AGENTS.md adapter.

### Phase 2: Gemini/Antigravity Adapter (~1 hour)
Closest format match — SKILL.md files are nearly identical.

### Phase 3: Cursor Adapter (~2 hours)
Compact compilation needed for 12k char limit.

### Phase 4: Windsurf + Copilot + Continue + Aider (~2 hours)
Similar to Codex (AGENTS.md) and Gemini (modular) adapters.

### Phase 5: Universal Installer (~2 hours)
Platform detection + per-platform install orchestration.

### Phase 6: Documentation + README (~1 hour)
Per-platform guides and multi-platform README.

---

## Verification Plan

### Automated
- Existing `bench/` tests pass unchanged (routing brain untouched)
- `test/test-classify.sh` passes (classifier unchanged)
- New: `test/test-compile.sh` — verify compiled output is valid per platform

### Manual
- Install on Claude Code → verify identical behavior to current v2
- Install Codex adapter → verify `AGENTS.md` is picked up
- Install Cursor adapter → verify `.cursor/rules/` files appear
- Install Gemini adapter → verify `GEMINI.md` is read

### Regression Gate
- `install.sh` (original) must produce byte-identical output as before
- All 15 skills must remain functional in Claude Code
- No files in the existing directory tree are modified
