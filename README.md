# SuperAgent for Claude Code

> One command turns Claude Code into a senior engineer who already knows your codebase, remembers every decision, never skips tests, and ships Awwwards-class UIs.

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install.sh
```

Restart Claude Code. Type `superagent`. Done.

---

## The problem with Claude Code out of the box

Every session starts cold. You re-explain the same codebase. Claude reads 40 files to answer one question. It forgets what you decided last Tuesday. It dives into code before you've agreed on a plan. It says "done" when it isn't. And when you ask for a "premium" UI, you get Bootstrap with a gradient.

You're losing hours. And tokens.

---

## What SuperAgent adds

### A routing brain
Every task is analyzed and routed to the right skill chain — automatically. "Fix this bug" triggers systematic debugging → TDD → verification, in that order, every time. You never have to remember which skill to reach for.

### A knowledge graph
`graphify` indexes your entire codebase into a queryable graph. One query replaces reading 71 files. Your real compression ratio — measured from *your* codebase, not a benchmark — is tracked live in your statusline.

```
[SA: ~231k saved | 48x]
```

### A memory system
`mempalace` stores cross-session context locally. No API key. 96.6% retrieval accuracy. Claude walks into your project already knowing what matters.

### 20+ expert skills
TDD, planning, systematic debugging, parallel agents, security review, code quality, UI design intelligence, premium WebGL/3D — each one enforces discipline you'd otherwise skip at 11pm.

### Premium creative web
`webgl-craft` is a technique library distilled from deep teardowns of Awwwards winners (Igloo Inc, Lando Norris, Prometheus Fuels, Shopify Editions). Five technique domains. Nine production-ready recipes. One question it always routes back to: *what is this site's signature move?*

---

## Install

```bash
git clone https://github.com/animeshbasak/SuperAgent
bash SuperAgent/install.sh
```

**What runs automatically:**

| Step | What happens |
|------|-------------|
| Registers plugin marketplaces | superpowers, caveman, claude-mem, ui-ux-pro-max |
| Installs Claude plugins | 5 plugins via `claude plugin install` |
| Installs webgl-craft | Premium WebGL/3D skill to `~/.claude/skills/webgl-craft` |
| Indexes `~/.claude` into mempalace | Cross-session memory, ready on first use |
| Builds graphify knowledge graph | All installed skills, queryable immediately |
| Wires token savings tracker | Statusline badge + `/token-stats` command |
| Calibrates compression ratio | From your actual codebase, not benchmarks |

**After install:** restart Claude Code, type `superagent`.

**Requirements:** Claude Code CLI · Node.js 18+ · macOS or Linux

---

## Routing table

Type `superagent` (or just start any task). The routing brain activates the right stack:

| Intent | Skill chain |
|--------|-------------|
| "build X" / "add feature" | brainstorming → writing-plans → TDD → executing-plans |
| "fix bug" / "broken" | systematic-debugging → TDD → verification |
| "understand codebase" | graphify query → smart-explore |
| "ship" / "PR" / "merge" | verification → requesting-code-review → finishing-branch |
| "design" / "UI" / "component" | ui-ux-pro-max → TDD → verification |
| "3D" / "WebGL" / "cinematic" | webgl-craft → TDD → verification |
| "did we solve this?" | mempalace search → claude-mem:mem-search |
| 2+ independent tasks | dispatching-parallel-agents |

No configuration. No manual skill selection. It just routes.

---

## What's installed

| Tool | Type | Purpose |
|------|------|---------|
| **superagent** | Claude skill | Routing brain — activates this whole system |
| **superpowers** | Claude plugin | 20+ workflow skills (TDD, planning, debugging, reviews) |
| **caveman** | Claude plugin | ~75% token reduction mode for terse sessions |
| **claude-mem** | Claude plugin | Cross-session memory + AST-level code search |
| **ui-ux-pro-max** | Claude plugin | Frontend design intelligence — 50+ styles, 161 palettes, 57 font pairings |
| **webgl-craft** | Claude skill | Premium WebGL/3D creative web — Awwwards-class technique library |
| **graphify** | Python (pipx) | Codebase → knowledge graph, 71.5x token reduction per query |
| **mempalace** | Python (pipx) | Local-first AI memory, no API key, 96.6% retrieval accuracy |

---

## webgl-craft — Premium creative web

`webgl-craft` routes every WebGL/3D decision through the right technique reference. Five domains, nine production recipes, one principle: **signature interactions beat signature stacks**.

**Triggers automatically on:** Three.js · React Three Fiber · WebGL · WebGPU · shaders · GSAP ScrollTrigger · Lenis · Framer Motion transitions · custom cursors · MSDF text · particles · post-processing · "make it cinematic" · "feels flat" · "Awwwards" · "FWA" · "Active Theory"

**Five technique domains:**

| Domain | Reference | When to read |
|--------|-----------|-------------|
| Architecture | `architecture.md` | Persistent canvas vs hybrid vs DOM-first — read FIRST for new projects |
| Shaders & 3D | `shaders.md` | Materials, post-processing, GPGPU, gravitational lensing, fluid distortion |
| Motion & Scroll | `motion-scroll.md` | GSAP ScrollTrigger, Lenis, camera scrubbing, timeline choreography |
| Interaction | `interaction.md` | Custom cursors, magnetic effects, AI terminals, audio, a11y |
| Pipeline & Perf | `pipeline.md` | Draco/KTX2/Basis, WebGPU/TSL, Lighthouse, device-tier adaptation |

**Nine production recipes:**

```
recipes/
├── persistent-canvas-r3f.tsx     single canvas across routes (Next.js App Router)
├── lensing-shader.ts             Schwarzschild black hole approximation (TSL)
├── fluid-cursor-mask.ts          Lando-style liquid blob cursor (TSL)
├── msdf-text-hero.tsx            troika-three-text hero with shader distortion
├── scroll-uniform-bridge.ts      GSAP ScrollTrigger → shader uniform
├── two-track-frame-budget.ts     60fps hero + 12fps secondary gate
├── barba-style-transitions.tsx   persistent canvas + DOM overlay swap
├── ai-terminal-widget.tsx        streaming LLM terminal with rate limit + reduced motion
└── audio-reactive-gain.ts        Web Audio gain modulated by scroll velocity
```

Distilled from Igloo Inc (Developer SOTY 2024), Lando Norris (SOTD Nov 2025), Prometheus Fuels (SOTM May 2021), and Shopify Editions Winter '26.

---

## Token savings tracker

After running `graphify update` on your project, SuperAgent measures your real compression ratio and starts tracking:

```
$ /token-stats

SuperAgent Token Stats — /your/project
──────────────────────────────────────────────
Compression ratio : 48.3x  (your codebase, measured 2026-04-22)
──────────────────────────────────────────────
Lifetime
  Graphify queries  : 47      → 198k tokens saved
  Mempalace hits    : 23      → ~31k tokens saved (estimate)
  Total saved       : ~229k tokens

Last 5 sessions
  Date          Graphify    Mempalace   Saved
  2026-04-22    12          4           ~58k
  2026-04-21    8           2           ~38k
  2026-04-20    15          6           ~71k
──────────────────────────────────────────────
```

The ratio is yours — measured from your actual index, not the 71.5x benchmark number.

---

## Index your project

```bash
cd ~/my-project
graphify update ./src          # build knowledge graph
mempalace init . --yes && mempalace mine .   # index for memory
```

Then in Claude Code:

```
graphify query "how does authentication work?"
mempalace search "auth decisions from last week"
```

---

## Skill reference

Full skill roster available via `/skills` in Claude Code after install. Key ones:

| Skill | When it activates |
|-------|------------------|
| `superpowers:brainstorming` | Before any creative/feature work |
| `superpowers:test-driven-development` | Any feature or bugfix |
| `superpowers:systematic-debugging` | Bug, test failure, unexpected behavior |
| `superpowers:verification-before-completion` | Before claiming done or opening PR |
| `superpowers:writing-plans` | Multi-step task, have requirements |
| `superpowers:dispatching-parallel-agents` | 2+ independent tasks |
| `superpowers:finishing-a-development-branch` | Ready to integrate |
| `claude-mem:smart-explore` | AST-level code search, token-efficient |
| `claude-mem:mem-search` | "Did we solve this before?" |
| `caveman:caveman` | Token-reduction sessions |
| `ui-ux-pro-max` | Any frontend design or component |
| `webgl-craft` | WebGL/3D/creative web |
| `claude-api` | Anthropic SDK, prompt caching, model config |

---

## Manual Python install (if Homebrew unavailable)

```bash
pip install pipx && pipx ensurepath
pipx install graphifyy
pipx install mempalace
mempalace init ~/.claude --yes && mempalace mine ~/.claude
cd ~/.claude && graphify update skills
```

---

## Links

- [graphify](https://github.com/animeshbasak/graphifyy) — knowledge graph engine
- [mempalace](https://github.com/animeshbasak/mempalace) — local AI memory
- [superpowers](https://github.com/claude-plugins-official/superpowers) — 20+ workflow skills
- [claude-mem](https://github.com/thedotmack/claude-mem) — cross-session observations
- [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — frontend design intelligence

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

If this saved you time, star it. If it saved you tokens, `/token-stats` will tell you exactly how many.
