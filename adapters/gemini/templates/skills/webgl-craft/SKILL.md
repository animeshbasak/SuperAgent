---
name: webgl-craft
description: 
---

# WebGL Craft — Technique Library for Premium Creative Web

This skill is a router, not an implementation. It exists to answer one question:
**"What technique should I reach for, and what is its cost?"**

Do not try to implement anything from memory. Find the right reference file first,
read it, then build. Premium creative web rewards precision over breadth; the wrong
technique applied well still loses to the right technique applied simply.

---

## HOW TO USE THIS SKILL

1. Identify which of the five technique domains the user's need falls into (below).
2. Read the matching reference file in full before writing any code.
3. If the need spans multiple domains, read them in the order listed in § COMMON COMBINATIONS.
4. If the user is planning a full site, read `references/architecture.md` FIRST — the
   architectural decision (persistent canvas vs. hybrid vs. DOM-first) constrains
   every other choice.
5. Pull working code from `recipes/` only after the approach is settled. Recipes are
   starting points, not drop-ins; every one has edit notes at the top.

---

## THE FIVE TECHNIQUE DOMAINS

### 1. Architecture — `references/architecture.md`

The site-level decision: where does the canvas live, how do routes transition, what
is rendered in the DOM vs. the WebGL scene. Read this first for any new project.

**Read when the user says:** "I want to build a [site/portfolio/landing page]",
"how should I structure this", "Next.js or Svelte", "React Three Fiber vs. vanilla
Three.js", "single page or multi-page", "smooth scroll", "page transitions",
"persistent canvas".

### 2. Shaders & 3D — `references/shaders.md`

The WebGL scene itself. Material design, post-processing, lighting, SDF/MSDF text,
particle systems, GPGPU, shader-driven distortion, and the specific signature effects
(gravitational lensing, fluid distortion, volumetric clouds, photo-projection,
procedural geometry).

**Read when the user says:** "3D hero", "shader", "distortion", "particles",
"black hole", "refraction", "bloom", "chromatic aberration", "film grain",
"lensing", "liquid cursor", "fluid", "noise", "volumetric", "crystal", "ice",
"glass", "glow".

### 3. Motion & Scroll — `references/motion-scroll.md`

GSAP ScrollTrigger patterns, Lenis configuration, scroll-to-uniform binding,
horizontal scroll pinning, camera scrubbing, timeline choreography, split-text
reveals, DrawSVG signatures, and the two-track frame budget pattern.

**Read when the user says:** "scroll animation", "on scroll", "parallax", "pinned",
"horizontal scroll", "reveal", "sticky", "scrub", "timeline", "camera path",
"choreography", "cinematic scroll".

### 4. Interaction Surfaces — `references/interaction.md`

Custom cursors, hover state systems, magnetic effects, AI-terminal patterns,
keyboard navigation, audio that responds to state, `prefers-reduced-motion`
handling, and mobile interaction degradation.

**Read when the user says:** "custom cursor", "magnetic button", "hover effect",
"AI chat widget", "terminal", "command palette", "ambient audio", "sound design",
"accessibility", "reduced motion", "mobile interaction".

### 5. Pipeline & Performance — `references/pipeline.md`

Asset compression (Draco/Meshopt/KTX2/Basis), glTF workflow, loading strategy,
shader pre-warming, bundle splitting, WebGPU/WebGL2 fallback via TSL, device-tier
adaptation, Lighthouse survival, `prefers-reduced-motion` compliance, and the
two-track frame budget implementation details.

**Read when the user says:** "too slow", "janky", "performance", "mobile is broken",
"Lighthouse", "bundle size", "WebGPU", "load time", "asset optimization",
"compression", "cross-browser".

---

## COMMON COMBINATIONS

Certain user intents consistently require the same combination of references. When
you recognize one, read them all in order before proposing anything.

**"Build me a portfolio / agency / studio site"**
→ architecture.md → motion-scroll.md → shaders.md → interaction.md → pipeline.md

**"Make the hero 3D and cinematic"**
→ shaders.md → motion-scroll.md → pipeline.md

**"Add a custom cursor that does [X]"**
→ interaction.md → shaders.md (if the cursor renders WebGL content)

**"Fix the performance"**
→ pipeline.md → architecture.md (if the answer is architectural) → motion-scroll.md
(if the answer is scroll-handler related)

**"Make page transitions smooth"**
→ architecture.md → motion-scroll.md → interaction.md

**"The site feels flat / generic / AI-looking"**
→ This is almost never a technique gap. Read `references/signature-moves.md` first.
The problem is usually the absence of ONE memorable interaction that literalizes the
site's subject. Adding more effects makes it worse.

---

## THE NON-NEGOTIABLE PRINCIPLES

These hold across every decision in every reference file. If a proposed approach
violates one of these, stop and reconsider before writing code.

**Signature interactions beat signature stacks.** One memorable gesture that
literalizes the site's subject outperforms ten generic premium effects. Before
suggesting Three.js, GSAP, Lenis, and post-processing, ask: what is the ONE
interaction this site will be remembered for? Read `references/signature-moves.md`
for the framework.

**Canvas is never the whole page.** Even sites that feel canvas-dominant (Igloo,
Prometheus) keep critical text in the DOM for SEO, screen readers, and copy-paste.
The question is never "canvas vs. DOM" — it is "which specific elements justify
WebGL rendering and which do not."

**The frame budget is two-track, not one.** The hero runs at native refresh rate.
Secondary elements (background particles, ambient fog, instrument telemetry) run
at 12–15 fps via a render-on-tick gate. This is the single most under-used
technique in the reference set and the cheapest performance win available.

**Shaders are authored in TSL, not GLSL, when targeting 2026+.** Three.js Shading
Language compiles to both WebGL2 and WebGPU from one source. Writing raw GLSL
today is writing migration work for tomorrow. Exception: pre-existing GLSL from
reputable public sources (Shadertoy, glslSandbox) is fine to port as-is, but any
new shader work should be TSL.

**Accessibility is a gate, not a feature.** `prefers-reduced-motion` kills or
dampens EVERY motion primitive. Keyboard focus is reachable on every interactive
element. Canvas-rendered text has a DOM mirror with `aria-hidden` on the canvas.
Skip this and the portfolio fails the Lighthouse screen recruiters run.

**Loading is UX, not a waiting room.** A 3-second "Load [Name]" preloader is a
recruiter-time tax. The DOM hero and critical interactions should be responsive
within 1.5s on 4G; the WebGL scene streams in afterward with a graceful reveal.
Never block first interaction on a preload.

---

## WHEN NOT TO USE THIS SKILL

Do not use this skill for:

- Content websites where motion would be distracting (news, blogs, documentation,
  SaaS dashboards). Use a clean, boring build. This skill's techniques are
  inappropriate for reading-optimized UX.
- Internal tools, admin panels, developer dashboards. WebGL here is costume, not
  function. Stick to standard component libraries.
- Sites where the subject is a form or a table. No amount of shader work makes
  data entry more pleasant; it makes it worse.
- E-commerce purchase flows. Keep the narrative/experiential layer separate
  (see how Lando Norris decouples `landonorris.com` from `store.landonorris.com`).
- Accessibility-critical contexts (government, healthcare, education). The
  trade-offs premium creative web accepts are not acceptable here.

If the user wants "premium" feel on a site that falls in these categories, the
answer is typography, spacing, color discipline, and motion restraint — not WebGL.

---

## REFERENCE FILE STRUCTURE

```
webgl-craft/
├── SKILL.md                          ← you are here
├── references/
│   ├── architecture.md               ← site-level decisions
│   ├── shaders.md                    ← WebGL scene and materials
│   ├── motion-scroll.md              ← GSAP/Lenis/ScrollTrigger
│   ├── interaction.md                ← cursors, AI terminals, audio, a11y
│   ├── pipeline.md                   ← assets, perf, WebGPU/TSL
│   └── signature-moves.md            ← the "what is this site's one gesture" framework
└── recipes/
    ├── persistent-canvas-r3f.tsx     ← single canvas across routes (Next.js App Router)
    ├── lensing-shader.ts             ← Schwarzschild black hole approximation (TSL)
    ├── fluid-cursor-mask.ts          ← Lando-style liquid blob cursor (TSL)
    ├── msdf-text-hero.tsx            ← troika-three-text hero with shader distortion
    ├── scroll-uniform-bridge.ts      ← GSAP ScrollTrigger → shader uniform
    ├── two-track-frame-budget.ts     ← 60fps hero + 12fps secondary gate
    ├── barba-style-transitions.tsx   ← persistent canvas + DOM overlay swap
    ├── ai-terminal-widget.tsx        ← streaming LLM terminal with rate limit + reduced motion
    └── audio-reactive-gain.ts        ← Web Audio gain modulated by scroll velocity
```

Each recipe file begins with a header:
- **Source lineage:** what public technique it's derived from
- **When to use:** the conditions under which this recipe is appropriate
- **When NOT to use:** the conditions under which a different approach is correct
- **Edit points:** the parameters most likely to need tuning per project
- **Known trade-offs:** accessibility, performance, mobile cost

Treat recipes as starting scaffolds. Every one is written to be read and modified,
not copy-pasted.

---

## META: WHY THIS SKILL EXISTS

The default failure mode when building a premium creative site is:

1. Reaching for Three.js + GSAP + Lenis because they are "what everyone uses"
2. Adding effects (bloom, chromatic aberration, film grain) until the site "looks
   premium"
3. Shipping, getting a 7/10 Awwwards score, wondering why it didn't hit 9/10

The reason is always the same: the site has no signature move. It is a competent
assembly of techniques without a reason to exist. This skill's purpose is to route
every decision back to the question of signature — and to supply the technical
precision to execute that signature when identified.

The techniques in the reference files were distilled from deep teardowns of sites
that achieved 8.5+/10 Awwwards scores: Igloo Inc (Developer Site of the Year 2024),
Lando Norris (Site of the Day Nov 2025), Prometheus Fuels (Site of the Month May
2021), and Shopify Editions Winter '26 Renaissance (SOTD Winter 2025). These are
not the only good sites; they are the four that, between them, cover the full
space of modern creative-web patterns from persistent-world to hybrid to DOM-first.

Trust the routing. Read the reference. Then build.
