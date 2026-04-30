# Animations — GSAP, Easing, Deterministic Seeking

Hyperframes uses GSAP for property animation. Timelines are paused and the
runtime drives playback via frame seeking. You define the choreography; the
engine controls the clock. This separation is what makes renders deterministic.

---

## The four key rules

These are the rules that, when violated, cause 90% of render bugs:

1. **Always create timelines paused** — `gsap.timeline({ paused: true })`.
2. **Register on `window.__timelines`** — key must equal the composition's
   `data-composition-id`.
3. **Use the position parameter (3rd arg) for absolute timing** — not
   chained delays.
4. **Animate visual properties only** — never `play()`, `pause()`,
   `currentTime =`, or media DOM mutation in scripts.

---

## Setup

```html
<script src="https://cdn.jsdelivr.net/npm/gsap@3/dist/gsap.min.js"></script>
<script>
  // 1. Create the paused timeline — runtime owns the clock
  const tl = gsap.timeline({ paused: true });

  // 2. Add tweens with absolute position (3rd arg)
  tl.from("#title", { opacity: 0, y: -50, duration: 1 }, 0);
  tl.to("#title",   { opacity: 0, duration: 0.5 }, 4.5);

  // 3. Initialize and register
  window.__timelines = window.__timelines || {};
  window.__timelines["root"] = tl;  // key MUST match data-composition-id
</script>
```

---

## Supported timeline methods

| Method                                          | Use                                |
| ----------------------------------------------- | ---------------------------------- |
| `tl.to(target, vars, position)`                 | Animate from current to target     |
| `tl.from(target, vars, position)`               | Animate from given to current      |
| `tl.fromTo(target, fromVars, toVars, position)` | Animate explicit start to end      |
| `tl.set(target, vars, position)`                | Snap value at exact frame          |

The `position` argument is in seconds, absolute from timeline start. Always
use it. Do not rely on chained sequencing — frame seeks are random-access and
position-based timing is what makes them work.

---

## Supported properties

`opacity`, `x`, `y`, `scale`, `scaleX`, `scaleY`, `rotation`, `rotationX`,
`rotationY`, `rotationZ`, `width`, `height`, `visibility`, `color`,
`backgroundColor`, plus any CSS-animatable property. CSS variables work too:
`tl.to(el, { "--my-var": "1px" })`.

---

## Easing

GSAP includes a robust easing set. Common picks:

| Easing                  | Feel                                       |
| ----------------------- | ------------------------------------------ |
| `power1.out`            | Soft deceleration (default-good for fades) |
| `power2.out`            | Slightly snappier deceleration             |
| `power3.out`            | Strong deceleration — premium feel         |
| `power4.out`            | Cinematic — entrance moves                 |
| `expo.out`              | Aggressive deceleration; UI snaps          |
| `back.out(1.7)`         | Overshoot — playful entrance               |
| `elastic.out(1, 0.3)`   | Bouncy — rare; use sparingly               |
| `circ.inOut`            | Smooth round trip                          |
| `none`                  | Linear — for camera dollies, parallax      |

Specify in the `vars` object: `tl.from("#title", { y: -50, duration: 1, ease: "power3.out" }, 0)`.

For deterministic motion that reads as "expensive", default to `power3.out`
on entrances and `power2.in` on exits, and avoid the bouncy easings unless
the brief calls for it.

---

## Timeline duration === composition duration

The composition's runtime length is exactly the GSAP timeline's `duration()`.
This is the single most-violated invariant in hyperframes:

```javascript
// Last animation ends at 3 seconds...
tl.from("#title", { opacity: 0, y: -50, duration: 1 }, 0);
tl.to("#title",   { opacity: 0, duration: 1 }, 2);
// ...so the composition is 3 seconds long.
```

If the longest media clip is 30 seconds but the timeline is 3 seconds, the
video gets cut off at 3 seconds. To extend without animating anything:

```javascript
// Forces the timeline to 30 seconds with a no-op tween at the end
tl.set({}, {}, 30);
```

This is the canonical fix for "my video is shorter than the source clip".

---

## Position parameter — absolute is non-negotiable

```javascript
// CORRECT — every tween's position is explicit
tl.from("#title",    { opacity: 0, y: -50, duration: 1 }, 0);
tl.to("#title",      { opacity: 0, duration: 0.5 },        4);
tl.from("#caption",  { opacity: 0, duration: 0.5 },        4.5);

// WRONG — implicit chaining is fragile under random-access seek
tl.from("#title", { opacity: 0, duration: 1 });
tl.to("#title", { opacity: 0, duration: 0.5 }, "+=3");  // relative offset
```

Why: render seeks each frame independently. Relative chains are still
position-resolved at parse time, so the framework tolerates them, but
absolute positions make the timeline self-documenting and survive edits.

---

## Stagger for grouped reveals

```javascript
tl.from(".bar", {
  scaleY: 0,
  transformOrigin: "bottom",
  duration: 0.6,
  ease: "power3.out",
  stagger: 0.08,           // 80ms between each .bar entrance
}, 0.5);
```

Stagger is the cheapest motion-graphics polish move. Use it on chart bars,
list items, captions, anything with ≥ 3 siblings.

---

## Sub-composition timelines auto-nest

When a parent composition embeds a nested composition (via
`data-composition-src` or inline), the child registers its own timeline on
`window.__timelines` and the framework nests it into the parent timeline at
the host element's `data-start`. Do NOT manually call
`master.add(window.__timelines["intro"], 0)` — it duplicates the timeline
and breaks seeking.

---

## What NOT to do

These patterns will break a render:

```javascript
// WRONG — playing media in scripts (framework owns playback)
document.getElementById("hero").play();
document.getElementById("music").currentTime = 5;

// WRONG — un-paused timeline
const tl = gsap.timeline();   // missing { paused: true }

// WRONG — animating dimensions on a <video>
tl.to("#hero", { width: 500, height: 280 }, 5);
// (Browser may stop emitting frames. Wrap in a <div> and animate the wrapper.)

// WRONG — manually nesting sub-timelines
const master = window.__timelines["root"];
master.add(window.__timelines["intro"], 0);

// WRONG — unseeded randomness
const x = Math.random() * 100;   // different output every render
// Use a seeded RNG or pre-compute.

// WRONG — wall-clock or rAF timing
setInterval(() => tl.progress(...), 16);
requestAnimationFrame(...);
// Render is seek-driven; no realtime hooks fire.

// WRONG — animating left / top / width / height on <video>
tl.to("#hero", { left: 100, top: 50 });
// Wrap the video in a <div>, animate the wrapper.

// WRONG — fetching at render time
fetch("/api/title-text").then(...);
// All assets must be loaded before render. Bake values in.
```

---

## Determinism contract

Same composition + same fps + same dimensions = byte-identical (in Docker)
or visually-identical (locally) MP4. The contract requires:

- No `Date.now()`, `performance.now()`, `Math.random()` (unseeded), or
  `requestAnimationFrame`.
- No render-time network fetches. Pre-load everything.
- No reads from `localStorage`, `IndexedDB`, or any host state.
- No CSS `animation` keyframes — they run on wall-clock, bypassing the
  seeker. Use GSAP for everything.
- No `transition: ... s` in CSS — same problem, same fix.

Local renders are not bit-exact across machines because of font and Chrome
version differences. Use `--docker` for true reproducibility.

---

## Cheap polish moves

- **Slight scale up on entrance.** `scale: 0.95 → 1` on entries reads as
  "weighty".
- **Y-offset of 30–60px on text reveals.** Pure opacity feels flat.
- **Hold the last frame for 0.5s.** Don't end on a fade-out unless the
  next composition will overlap.
- **Audio ducking under VO.** Set music `data-volume` to 0.2 during voice,
  back to 0.6 in gaps.
- **Stagger on every group.** 0.05–0.10s reads as choreographed.
- **`ease: "power3.out"` everywhere by default.** Reach for it before
  any other easing.
