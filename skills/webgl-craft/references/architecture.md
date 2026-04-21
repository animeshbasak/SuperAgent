# Architecture — Site-Level Decisions

The architectural decision is: **where does the canvas live, and how do routes
transition.** Every other technical decision is downstream of this. Read this
file first for any new project.

---

## THE THREE ARCHITECTURES

Every premium creative site in the reference set falls into one of three
architectures. Choose explicitly before any code is written.

### A. Persistent World (canvas-dominant)

The page IS the WebGL canvas. DOM is a thin overlay for accessibility and text.
Routes are camera moves inside the same scene. Examples: Igloo Inc (abeto),
Prometheus Fuels (Active Theory Hydra).

**Use when:**
- The subject is inherently spatial (a world, a landscape, a machine, a product
  with physical presence).
- The brief tolerates an accessibility score in the 6.5–7.5 range.
- The build team has deep WebGL expertise and 10+ weeks.
- The site will be judged on Awwwards Developer Site of the Year tier.

**Do not use when:**
- The site has more than 3–4 conceptual sections. Persistent worlds cannot carry
  information-dense pages without devolving into indirection.
- The audience includes recruiters running Lighthouse. Expect Performance scores
  below 80 on mobile and Accessibility scores below 85.
- The copy volume is high. Marketing pages with more than ~500 words of body
  copy suffer in persistent-world architectures because canvas text is SEO-dark
  and screen-reader-hostile unless carefully mirrored.
- The team does not have a technical artist who can write custom geometry
  exporters and a volume-data pipeline. Persistent worlds live or die on asset
  authoring, not code.

**What it looks like technically:**
- A single `<canvas>` root takes the viewport. DOM is `position: absolute`
  overlay elements for navigation, CTAs, and text that must be crawlable.
- Route changes do NOT remount the canvas. They trigger a camera path animation
  that ends at the new "section" of the world.
- Scroll is mapped to a normalized 0–1 uniform, fed into shaders and camera
  position drivers.
- Shader compilation is pre-warmed during the intro sequence to eliminate
  first-interaction jank.

### B. Hybrid (document + scoped canvas)

A conventional document (DOM-first, routable, SEO-correct) with a custom WebGL
layer grafted onto specific moments. Canvas either persists across routes (via
Barba-style swap) or mounts per-section. Examples: Lando Norris (OFF+BRAND,
Webflow + Three.js), Shopify Editions Winter '26 (Three.js WebGPU).

**Use when:**
- The site has 5+ sections or substantial content payload.
- Accessibility and SEO are non-negotiable.
- The brief calls for "premium" but also "marketable" — the most common case.
- The team is competent in WebGL but not deeply specialized.
- Build time is 4–8 weeks.

**Do not use when:**
- The brief demands full immersion. A hybrid site, by definition, has moments
  where the user is in standard DOM. That is sometimes what the brief wants and
  sometimes what the brief is explicitly rejecting.
- The signature move requires continuous canvas context across all routes
  (e.g., a single physical artifact that must persist through the entire scroll
  journey). In this case, use Persistent World.

**What it looks like technically:**
- Next.js, Nuxt, SvelteKit, or Webflow + custom JS for the document layer.
- Three.js or React Three Fiber scoped to a root canvas element that persists
  across route transitions (the Barba pattern) OR mounts per-route (simpler,
  but loses inter-route continuity).
- Lenis + GSAP ScrollTrigger for smoothing and scrubbing.
- Custom shader layer is isolated — the hero is WebGL, the "about" page is
  regular DOM, the "projects" page mounts a new WebGL scene on entry.
- DOM semantics are preserved. Lighthouse scores land in the 85–95 range.

### C. DOM-First (WebGL as accent)

Standard React/Next/Svelte site with WebGL appearing as accent moments — a
hero shader, a single 3D product viewer, a scroll-triggered canvas effect. The
rest of the site is conventional CSS-and-DOM.

**Use when:**
- The audience runs Lighthouse and expects 95+.
- The content is the product (documentation, editorial, SaaS marketing, news).
- WebGL serves one specific moment, not the site's character.
- The team is primarily frontend engineers, not creative technologists.
- Build time is 2–4 weeks.

**Do not use when:**
- The brief is aspirationally award-chasing. DOM-first sites rarely win
  Developer jury awards; they can win Design jury awards if the visual work is
  exceptional.

**What it looks like technically:**
- Next.js or standard React stack.
- One or two WebGL components (react-three-fiber Canvas) scoped to single
  sections.
- No persistent canvas, no shader pre-warming, no custom asset pipeline beyond
  standard image optimization.
- Lighthouse scores land in the 95+ range.

---

## THE DECISION TREE

```
Is the site's subject inherently spatial (a world, a product, a physical thing)?
├── Yes → Is the copy volume under 500 words?
│         ├── Yes → Is the team WebGL-native with 10+ weeks?
│         │        ├── Yes → PERSISTENT WORLD
│         │        └── No  → HYBRID
│         └── No  → HYBRID
└── No  → Is WebGL serving one specific moment, not the whole site?
          ├── Yes → DOM-FIRST
          └── No  → HYBRID
```

---

## ROUTING AND TRANSITIONS

The routing architecture choice is downstream of the site architecture.

### Persistent World routing
- Routes exist but do not remount. URL changes update a central store; the
  store drives a GSAP timeline that moves the camera.
- Next.js App Router with parallel routes and intercepted routes is a natural
  fit if using React; Svelte with manual hash routing or SvelteKit with a
  custom `<slot>` pattern works for Svelte builds.
- The canvas root is mounted ONCE at the layout level, never at the page level.
- Back/forward navigation replays camera paths in reverse.

### Hybrid with persistent canvas
- The WebGL canvas is mounted at the layout level. Page content is DOM inside
  the same layout, rendered above (via `z-index`) or adjacent to the canvas.
- Page transitions fade DOM out → camera moves / shader changes → fade new
  DOM in. This is the Barba.js pattern, achievable in React with Framer
  Motion's `AnimatePresence mode="wait"` or Next.js App Router's loading
  states.
- The WebGL scene has a "transition state" uniform that peaks during the swap
  (often driving a glitch, dissolve, or camera shake).

### Hybrid with per-route canvas
- Each page mounts its own `<Canvas>` on entry, unmounts on exit.
- Simpler to reason about; loses cross-route continuity.
- Use when the signature move is single-page or the routes are genuinely
  separate concepts.

### DOM-first
- Standard page-based routing. Canvas components are local to the pages that
  use them.
- No special transition handling beyond standard `AnimatePresence` or CSS.

---

## FRAMEWORK CHOICE

Framework is a secondary decision, not a signature-level one. These are the
defensible defaults in 2026.

**React + Next.js 15 App Router.** The right default for hybrid and DOM-first
architectures. App Router's layout system maps cleanly onto persistent canvas
patterns. Pair with `@react-three/fiber` and `@react-three/drei`. Known
weakness: React reconciliation overhead in large scenes (1000+ meshes); for
those, drop to imperative Three.js inside a single R3F component.

**Svelte / SvelteKit.** Strong for persistent-world sites where reactivity is
driving a single scene (see Igloo Inc). Less ecosystem around 3D-specific
libraries than React. `threlte` is the analog of R3F.

**Webflow + custom JS module.** Valid and often correct for sites where the
client needs CMS access (editorial, athlete personal sites, portfolios for
non-developers). Webflow handles layout, forms, CMS; a custom bundle (Three.js
+ GSAP + Lenis) handles the creative layer. This is the Lando Norris pattern.

**Vanilla Three.js + Vite.** Correct when the signature move is deeply custom
and React overhead is unjustified. This is the Igloo Inc / Active Theory
pattern. Requires more discipline on state management but yields the smallest
bundles and highest frame rates.

**Astro + islands.** Valid for DOM-first sites where WebGL is a single island.
Not appropriate for hybrid or persistent-world.

---

## STATE MANAGEMENT FOR WEBGL SITES

A specific anti-pattern to avoid: putting WebGL scene state inside React state
(`useState`, `useReducer`). React's render cycle is 60fps at best and under
memory pressure drops well below that. Scene state belongs in refs or in an
external store that the animation loop reads directly.

**Recommended pattern (React):**

- Use Zustand for cross-component scene state (which section is active,
  scroll progress, audio state).
- Subscribe the animation loop to Zustand via `useStore.subscribe` outside
  React render cycles.
- Use refs for per-frame values (mouse position, raycaster targets, camera
  lookAt). Never put these in React state.
- DOM components subscribe to Zustand normally via `useStore` hooks.

This gives the animation loop direct state access without triggering React
re-renders, and keeps DOM components reactive where they should be.

---

## CMS AND CONTENT

Most portfolios do not need a CMS. Most product sites and studio sites do.

**No CMS needed:**
- Personal portfolio with 3–10 projects. Store content in TypeScript files
  in the repo. Editing is a git commit. This is the correct default for
  individual portfolios.

**Lightweight CMS warranted:**
- Agency sites with 20+ case studies and non-technical editors.
- Editorial sites.
- E-commerce catalogs.

**Recommended stacks:**
- **Sanity** for structured content with custom rich-text. Strongest developer
  experience.
- **Contentful** for enterprise CMS needs.
- **Notion as CMS** for one-person operations who live in Notion. Works via
  the Notion API; limited but zero-friction.
- **Payload CMS** (self-hosted) for teams that want code-defined schemas and
  own infrastructure.

Keep WebGL-relevant assets (textures, models) in a dedicated CDN bucket, not
the CMS. CMS should own copy and image thumbnails; binary assets belong in
Cloudflare R2, Bunny CDN, or AWS S3 + CloudFront.

---

## DEPLOYMENT AND HOSTING

**Vercel** for Next.js. Defaults are correct; just ship.

**Cloudflare Pages** for static-site variants (Astro, plain Vite+Three.js).
Better global edge performance than Vercel for purely static work.

**Netlify** remains viable but is rarely the optimal choice in 2026.

**Self-hosted** (DigitalOcean, Fly.io) when server-side AI inference or heavy
API routes are in play. Only justify self-hosted if there's a concrete reason
(cost, data residency, API proximity).

---

## COMMERCE SEPARATION

If the site has a commerce layer, separate it. Lando Norris does this with
`landonorris.com` (editorial) vs. `store.landonorris.com` (Shopify). The
experiential site stays pure; commerce stays boring and conversion-optimized.

Never try to put a Shopify checkout inside a WebGL scene. Users abandon.

---

## THE ARCHITECTURAL CHECKPOINT

Before writing any code, these must be answered:

1. **Architecture:** Persistent World / Hybrid / DOM-First?
2. **Framework:** React+Next / SvelteKit / Webflow+JS / Vanilla+Vite / Astro?
3. **Canvas mount point:** Layout-level (persistent) / Page-level (per-route)?
4. **Routing pattern:** Camera paths / Barba-style swap / Standard page
   transitions?
5. **State management:** Zustand + refs / Component state only / External
   signals?
6. **CMS:** None (in-repo) / Sanity / Contentful / Payload / Notion?
7. **Deployment:** Vercel / Cloudflare Pages / Netlify / Self-hosted?
8. **Commerce layer:** None / Same domain / Separate subdomain?
9. **What specifically will be in the DOM vs. the WebGL scene?** List by
   element. Navigation, headline, body copy, project titles, project
   descriptions, CTAs, footer — for each, DOM or canvas?

Answers in hand, proceed to `shaders.md` for scene design or `motion-scroll.md`
for choreography.
