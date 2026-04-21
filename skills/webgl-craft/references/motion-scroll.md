# Motion and Scroll — Choreography Systems

This file covers the motion layer: GSAP, ScrollTrigger, Lenis, timeline
authoring, split-text, DrawSVG, the scroll-to-uniform bridge, and the
two-track frame budget pattern.

Scroll is the primary input for most creative sites. Getting the scroll
system right is more important than any individual animation — a site with
elegant scroll choreography and mediocre visuals consistently beats a site
with beautiful visuals and broken scroll.

---

## THE SCROLL STACK

The 2026 defensible default:

- **Native browser scroll** as the input.
- **Lenis** for smoothing (optional but recommended; skip only if the
  target audience includes accessibility-critical users who find smooth
  scroll disorienting).
- **GSAP ScrollTrigger** for pinning, scrubbing, and event-based triggers.
- **GSAP Timelines** for authoring choreography.
- **A scroll-uniform bridge** for feeding scroll state into shaders.

Alternatives:
- **Locomotive Scroll** is older and still used; Lenis has replaced it in
  most new builds in 2024–2026.
- **Framer Motion's `useScroll`** is adequate for DOM-only sites. For
  sites with a WebGL layer, GSAP ScrollTrigger has better integration.
- **Motion One** is smaller than GSAP and web-native. Lacks ScrollTrigger
  parity; not recommended for scroll-heavy creative sites.

---

## LENIS SETUP

Lenis is a lerp-based smooth scroll. Configure once at app root:

```javascript
import Lenis from 'lenis'

const lenis = new Lenis({
  duration: 1.2,         // how long a flick takes to settle
  easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
  smoothWheel: true,
  smoothTouch: false,    // keep touch native; users expect it
  orientation: 'vertical',
})

function raf(time) {
  lenis.raf(time)
  requestAnimationFrame(raf)
}
requestAnimationFrame(raf)
```

**Integrate with GSAP:**

```javascript
import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
gsap.registerPlugin(ScrollTrigger)

lenis.on('scroll', ScrollTrigger.update)
gsap.ticker.add((time) => lenis.raf(time * 1000))
gsap.ticker.lagSmoothing(0)
```

This replaces the manual `requestAnimationFrame` loop with GSAP's ticker,
ensuring Lenis and ScrollTrigger share one render pulse.

**Critical: disable Lenis on `prefers-reduced-motion`:**

```javascript
const prefersReducedMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)'
).matches

if (!prefersReducedMotion) {
  // init Lenis
}
```

Smooth scroll is disorienting for some users and a stated accessibility
violation if not gated on this media query.

---

## SCROLLTRIGGER PATTERNS

### Pattern 1: Pin and scrub

The hero section pins to the viewport while scroll progress drives an
animation, then unpins and continues to the next section.

```javascript
gsap.to('.hero-element', {
  xPercent: -100,
  ease: 'none',
  scrollTrigger: {
    trigger: '.hero',
    start: 'top top',
    end: '+=200%',       // pin for 2 viewports worth of scroll
    scrub: 1,            // 1-second lag follows scroll (feels elastic)
    pin: true,
    pinSpacing: true,
  },
})
```

Use `scrub: true` (no lag) for tight coupling, `scrub: 1` (1s ease) for
cinematic feel, `scrub: 0.5` for middle ground.

### Pattern 2: Horizontal scroll section

Vertical scroll drives horizontal translate of a wrapper. Used for
filmstrips, timelines, project carousels.

```javascript
const container = document.querySelector('.horizontal-container')
const sections = gsap.utils.toArray('.horizontal-section')

gsap.to(sections, {
  xPercent: -100 * (sections.length - 1),
  ease: 'none',
  scrollTrigger: {
    trigger: container,
    pin: true,
    scrub: 1,
    end: () => `+=${container.offsetWidth}`,
  },
})
```

Degrade to vertical stack below a breakpoint:

```javascript
ScrollTrigger.matchMedia({
  '(min-width: 768px)': function () {
    // horizontal scroll setup
  },
  '(max-width: 767px)': function () {
    // do nothing; sections stack vertically via CSS
  },
})
```

### Pattern 3: Trigger-based timeline

A timeline plays once when the element enters the viewport. Used for
text reveals, image reveals, section intros.

```javascript
const tl = gsap.timeline({
  scrollTrigger: {
    trigger: '.section',
    start: 'top 80%',    // fires when section top hits 80% of viewport
    toggleActions: 'play none none reverse',
  },
})

tl.from('.section-headline', { y: 50, opacity: 0, duration: 0.8 })
  .from('.section-subhead', { y: 30, opacity: 0, duration: 0.6 }, '-=0.4')
  .from('.section-cta', { scale: 0.8, opacity: 0, duration: 0.5 }, '-=0.3')
```

The negative offsets (`-=0.4`) make the animations overlap, producing the
staggered-cascade feel.

### Pattern 4: Scroll-to-uniform bridge

Scroll progress drives a shader uniform. This is the bridge between the
DOM/motion system and the WebGL scene.

See `recipes/scroll-uniform-bridge.ts` for a full implementation.

---

## SPLIT TEXT

GSAP's `SplitText` plugin breaks text into characters, words, or lines as
individual DOM elements, each animatable independently.

```javascript
import { SplitText } from 'gsap/SplitText'
gsap.registerPlugin(SplitText)

const split = new SplitText('.headline', { type: 'words,chars' })

gsap.from(split.chars, {
  y: 100,
  opacity: 0,
  duration: 0.6,
  stagger: 0.02,
  ease: 'power3.out',
  scrollTrigger: { trigger: '.headline', start: 'top 80%' },
})
```

**Critical:** re-split on resize if the text reflows (line breaks change).
Use `split.revert()` before `new SplitText(...)` to restore the original
markup first.

**Accessibility:** `SplitText` preserves aria-label on the source element
automatically in recent versions. For older versions, set
`aria-label="original text"` manually and `aria-hidden="true"` on the
split children.

**Alternative:** for sites without GSAP, `splitting.js` does the same job
without a license dependency. SplitText requires a GSAP Club membership
(affordable, but a license consideration).

---

## DRAWSVG

DrawSVG (GSAP plugin) animates SVG stroke-dashoffset to produce a
"drawing-in" effect. Used for signatures, logos, line art, mission
patches.

```javascript
import { DrawSVGPlugin } from 'gsap/DrawSVGPlugin'
gsap.registerPlugin(DrawSVGPlugin)

gsap.from('.signature path', {
  drawSVG: '0%',
  duration: 2,
  ease: 'power2.inOut',
  stagger: 0.1,
  scrollTrigger: { trigger: '.signature', start: 'top 70%' },
})
```

**Non-GSAP alternative:** set CSS `stroke-dasharray` and `stroke-dashoffset`
manually and animate with Framer Motion or CSS transitions. Less precise
but license-free.

For complex SVGs, ensure each path to be drawn is a single connected
path, not multiple sub-paths. Multi-path SVGs draw all paths simultaneously
from 0%; the visual often looks wrong.

---

## THE TWO-TRACK FRAME BUDGET

The Prometheus Fuels technique: the hero scene runs at native refresh rate;
secondary elements (ambient particles, background fog, instrument
telemetry) run at 12–15 fps.

This is the single most underused technique in creative web and the
cheapest performance win available.

**Why it works:** the human eye detects motion smoothness only in objects
that command attention. Background elements rendered at 12fps read as
"present" without costing the frame budget to render smoothly.

**Implementation:** gate the secondary render with a modulo check on
frame counter.

```javascript
let frameCount = 0
const SECONDARY_FPS = 12
const SECONDARY_INTERVAL = 60 / SECONDARY_FPS  // 5 frames per update at 60fps

function renderLoop() {
  frameCount++

  // Primary: every frame
  renderer.render(heroScene, camera)

  // Secondary: every Nth frame
  if (frameCount % Math.round(SECONDARY_INTERVAL) === 0) {
    renderer.render(ambientScene, camera)
  }

  requestAnimationFrame(renderLoop)
}
```

See `recipes/two-track-frame-budget.ts` for the production version with
delta-time accuracy.

**What qualifies as secondary:**
- Background particle fields.
- Ambient fog or cloud layers.
- Non-interactive decorative elements.
- Instrument telemetry displays (updated periodically anyway).

**What does not qualify:**
- Anything the user is directly interacting with (cursor effects, hover
  state, clicked elements).
- Foreground objects in focus.
- Text that must remain legible during motion.

---

## EASING — THE RIGHT DEFAULTS

GSAP ships many eases. Four cover 90% of cases:

- **`power2.out`** — starts fast, decelerates. The default for entrances,
  reveals, and most "it arrives" motions.
- **`power3.inOut`** — smooth acceleration both in and out. The default
  for section transitions, camera paths, scrubbed motion.
- **`expo.out`** — dramatic deceleration. Use for hero reveals, headline
  entrances, anything that should feel weighty.
- **`none` / `linear`** — no easing. Correct for scroll-scrubbed motion
  where the user's scroll gesture is the easing.

Avoid `elastic` and `bounce` on web work. They read as jokey/gimmicky and
are associated with mid-2010s motion design. Exceptions: explicitly
playful brands (children's products, entertainment, gaming).

Never mix eases randomly. Pick 2–3 for the project and reuse them.

---

## STAGGER DEFAULTS

GSAP stagger:

```javascript
gsap.from('.item', {
  y: 50,
  opacity: 0,
  duration: 0.6,
  stagger: 0.05,    // 50ms between items
})
```

Stagger values that work across creative web:
- **0.02–0.03s** for character-level text reveal (feels like typing).
- **0.05–0.08s** for word or line-level reveal (feels cinematic).
- **0.1–0.15s** for image or card grids (feels orchestrated).
- **0.2s+** reads as slow; use sparingly.

For random-order stagger (less robotic feel):

```javascript
stagger: { amount: 0.6, from: 'random' }
```

---

## CAMERA CHOREOGRAPHY (WEBGL)

For WebGL sites, scroll drives camera movement. Two patterns.

### Pattern A: Bezier path with scroll progress

Pre-define a 3D path (from Blender, authored in code, or extracted from a
glTF animation). Scroll progress maps to position along the path.

```javascript
import { CatmullRomCurve3, Vector3 } from 'three'

const path = new CatmullRomCurve3([
  new Vector3(0, 0, 5),
  new Vector3(2, 1, 3),
  new Vector3(0, 2, -1),
  new Vector3(-2, 1, -3),
  new Vector3(0, 0, -5),
])

// In render loop, bind to scroll:
const scrollProgress = lenis.animatedScroll / document.body.scrollHeight
const pointOnPath = path.getPointAt(scrollProgress)
camera.position.copy(pointOnPath)

const lookAtTarget = path.getPointAt(Math.min(scrollProgress + 0.01, 1))
camera.lookAt(lookAtTarget)
```

### Pattern B: GSAP timeline of camera properties

Author the camera path as a GSAP timeline with scroll scrubbing.

```javascript
const cameraTl = gsap.timeline({
  scrollTrigger: {
    trigger: '.scene-container',
    start: 'top top',
    end: 'bottom bottom',
    scrub: 1,
  },
})

cameraTl
  .to(camera.position, { x: 2, y: 1, z: 3, duration: 1, ease: 'none' })
  .to(camera.position, { x: 0, y: 2, z: -1, duration: 1, ease: 'none' })
  .to(camera.position, { x: -2, y: 1, z: -3, duration: 1, ease: 'none' })
```

Use Pattern A when the path is complex and mathematical. Use Pattern B
when the path is story-driven and you want per-waypoint easing.

---

## RESPECTING REDUCED MOTION

Every motion primitive must honor `prefers-reduced-motion`. This is a
gate, not a feature.

```javascript
const prefersReducedMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)'
).matches

if (prefersReducedMotion) {
  // Option A: disable all animations (set durations to 0)
  gsap.globalTimeline.timeScale(100)

  // Option B: replace animations with opacity fades only
  // (requires designing a reduced-motion variant)
}
```

The correct approach is Option B — design a reduced-motion variant that
preserves the site's intent with minimal motion, not Option A which
produces a broken experience. Reduced-motion users should get a
recognizable site.

For ScrollTrigger specifically:

```javascript
ScrollTrigger.matchMedia({
  '(prefers-reduced-motion: no-preference)': function () {
    // all the motion-heavy ScrollTriggers
  },
  '(prefers-reduced-motion: reduce)': function () {
    // static/minimal equivalents — typically just opacity fades
  },
})
```

---

## THE MOTION CHECKPOINT

Before writing choreography code:

1. **Is Lenis appropriate?** If the site is content-heavy (news, docs,
   SaaS), native scroll is correct. If creative/cinematic, Lenis.
2. **Which ScrollTrigger pattern fits this section?** Pin-scrub /
   horizontal / trigger timeline / scroll-uniform bridge.
3. **Is the text revealed via SplitText or WebGL?** SplitText for DOM;
   SDF shader distortion for 3D-integrated type.
4. **What is the camera choreography pattern?** Bezier path (mathematical)
   or GSAP timeline (story-driven).
5. **Is a two-track frame budget in play?** Identify primary vs.
   secondary elements.
6. **What is the reduced-motion variant?** Never skip this question.
7. **How does the scroll feel on mobile?** Touch scroll should remain
   native; Lenis smoothTouch false.

With these answered, implement via recipes and standard GSAP patterns.
