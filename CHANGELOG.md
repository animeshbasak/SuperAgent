# Changelog

All notable changes to SuperAgent are documented here.

---

## [1.1.0] — 2026-04-22

### Added
- **webgl-craft skill** — Premium WebGL/3D creative web technique library
  - Five technique domains: Architecture, Shaders & 3D, Motion & Scroll, Interaction Surfaces, Pipeline & Performance
  - Six reference files distilled from Awwwards SOTY/SOTD teardowns (Igloo Inc, Lando Norris, Prometheus Fuels, Shopify Editions Winter '26)
  - Nine production-ready recipes: persistent canvas R3F, gravitational lensing shader (TSL), fluid cursor mask, MSDF text hero, scroll-uniform bridge, two-track frame budget, Barba-style transitions, AI terminal widget, audio-reactive gain
  - Auto-triggers on: Three.js, React Three Fiber, WebGL, shaders, GSAP ScrollTrigger, Lenis, Framer Motion, custom cursors, "cinematic", "Awwwards", "feels flat", and more
  - Installed to `~/.claude/skills/webgl-craft/` with `references/` and `recipes/` subdirs
- **install.sh Step 5b** — webgl-craft installed automatically as part of one-command setup
- **SuperAgent SKILL.md** — webgl-craft added to UI/UX roster table, master decision flow, and installation table
- **CHANGELOG.md** — this file

### Changed
- `install.sh` version banner updated to v1.1
- README rewritten with webgl-craft section, full skill reference table, and improved routing table

---

## [1.0.0] — 2026-04-17

### Added
- **superagent** — master routing skill + superagent-brain PROACTIVE agent
- **superpowers** — 20+ workflow skills (TDD, planning, debugging, reviews, git, security)
- **caveman** — ~75% token reduction communication mode
- **claude-mem** — cross-session memory + AST-level code search via tree-sitter
- **ui-ux-pro-max** — frontend design intelligence (50+ styles, 161 palettes, 57 font pairings, 161 product types)
- **graphify** — codebase → knowledge graph, 71.5x token reduction per query (Python/pipx)
- **mempalace** — local-first AI memory, 96.6% retrieval accuracy, no API key (Python/pipx)
- **token-stats skill** — `/token-stats` command with lifetime report and per-session breakdown
- **superagent-tracker.sh** — PostToolUse hook measuring real token savings per session
- **superagent-statusline.sh** — statusLine badge showing live compression ratio and total saved
- **install.sh** — one-command installer: plugins + Python tools + hooks + calibration + CLAUDE.md
- Calibration step: compression ratio measured from user's actual codebase, stored in `~/.claude/superagent-stats.json`
- Auto-indexing: mempalace indexes `~/.claude` and graphify builds skills knowledge graph on first install
