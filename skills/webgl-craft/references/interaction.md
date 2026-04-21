# Interaction Surfaces — Cursors, Terminals, Audio, Accessibility

This file covers the direct-manipulation layer: custom cursors, hover
systems, magnetic buttons, AI terminals, keyboard navigation, audio that
responds to state, and accessibility gating.

Interaction surfaces are where sites feel alive. They are also where
accessibility most commonly breaks. Every pattern in this file has an
explicit accessibility gate.

---

## CUSTOM CURSORS

A custom cursor replaces or augments the default OS cursor. Four tiers,
increasing in cost and risk.

### Tier 1: Lerped dot

A small circle that follows the mouse with a spring lag. The baseline
every creative site ships. Cheap, clean, accessible if done right.

```javascript
const cursor = document.querySelector('.cursor')
let mouseX = 0, mouseY = 0
let cursorX = 0, cursorY = 0

window.addEventListener('mousemove', (e) => {
  mouseX = e.clientX
  mouseY = e.clientY
})

function animate() {
  cursorX += (mouseX - cursorX) * 0.15
  cursorY += (mouseY - cursorY) * 0.15
  cursor.style.transform = `translate3d(${cursorX}px, ${cursorY}px, 0)`
  requestAnimationFrame(animate)
}
animate()
```

CSS:

```css
.cursor {
  position: fixed;
  top: 0; left: 0;
  width: 12px; height: 12px;
  border-radius: 50%;
  background: white;
  mix-blend-mode: difference;
  pointer-events: none;
  z-index: 9999;
  transform: translate3d(-50%, -50%, 0);
}

@media (hover: none) {
  .cursor { display: none; }  /* hide on touch */
}

@media (prefers-reduced-motion: reduce) {
  .cursor { transition: none; }
  /* or hide entirely */
}
```

### Tier 2: Contextual cursor (state-aware)

Cursor changes based on what it's hovering. A link makes it expand, an
image makes it show "view," a draggable makes it show arrows.

```javascript
document.querySelectorAll('[data-cursor]').forEach(el => {
  el.addEventListener('mouseenter', () => {
    const state = el.dataset.cursor  // e.g., "drag", "view", "play"
    cursor.classList.add(`cursor--${state}`)
  })
  el.addEventListener('mouseleave', () => {
    cursor.className = 'cursor'
  })
})
```

CSS handles the state-specific sizing, content, and styling.

### Tier 3: Canvas-rendered cursor

The cursor is a WebGL element rendered in an overlay canvas. Enables
shader effects (glow, distortion, particle trails) not achievable in DOM.

Use a thin full-viewport `<canvas>` positioned above the document, with
a Three.js or OGL scene containing a sprite or mesh tracking the cursor
with lerp.

### Tier 4: Signature cursor (Lando Norris tier)

The cursor is the site's signature move. Fluid-distortion masks, reveal
effects, physics simulations. See `recipes/fluid-cursor-mask.ts`.

Reserved for sites where the cursor IS the signature. Not a default.

### Cursor accessibility rules

- **Hide on touch devices** (`@media (hover: none)`). Touch users don't
  have cursors.
- **Preserve keyboard focus indicators.** Custom cursors replace the
  mouse cursor, not the `:focus-visible` outline. Keyboard users must
  still see where focus is.
- **Preserve default cursor on form inputs.** Text fields need the
  I-beam; buttons need the pointer. Use `cursor: auto` on these and
  don't render the custom cursor over them (pointer-events discipline).
- **Honor `prefers-reduced-motion`** by reducing lag to 0 (cursor snaps
  to mouse position) or disabling entirely.
- **Ensure the default cursor is visible as fallback.** Don't set
  `cursor: none` globally on the body; set it only on elements where
  the custom cursor is active.

---

## MAGNETIC BUTTONS

Buttons that subtly pull toward the cursor on approach. A premium
micro-interaction, not a signature move.

```javascript
document.querySelectorAll('.magnetic').forEach(btn => {
  const strength = 0.3
  const bounds = 80  // distance at which magnetism activates

  btn.addEventListener('mousemove', (e) => {
    const rect = btn.getBoundingClientRect()
    const x = e.clientX - rect.left - rect.width / 2
    const y = e.clientY - rect.top - rect.height / 2
    btn.style.transform = `translate(${x * strength}px, ${y * strength}px)`
  })

  btn.addEventListener('mouseleave', () => {
    btn.style.transform = ''
  })
})
```

Smooth the transition with CSS:

```css
.magnetic {
  transition: transform 0.3s cubic-bezier(0.23, 1, 0.32, 1);
}
```

Use sparingly. Magnetic effect on every button reads as "too much." Use
on 1–3 primary CTAs only.

---

## HOVER STATES AND IMAGE PREVIEWS

The "nav menu shows an image when you hover the link" pattern (Lando
Norris's nav, OFF+BRAND's case studies). Adds substantial character with
low code cost.

```javascript
const nav = document.querySelector('.nav')
const preview = document.querySelector('.nav-preview')
const links = document.querySelectorAll('.nav a[data-preview]')

links.forEach(link => {
  link.addEventListener('mouseenter', () => {
    preview.style.backgroundImage = `url(${link.dataset.preview})`
    gsap.to(preview, { opacity: 1, scale: 1, duration: 0.4 })
  })
  link.addEventListener('mouseleave', () => {
    gsap.to(preview, { opacity: 0, scale: 0.9, duration: 0.3 })
  })
})
```

Track the cursor for the preview's position:

```javascript
nav.addEventListener('mousemove', (e) => {
  gsap.to(preview, { x: e.clientX, y: e.clientY, duration: 0.5 })
})
```

---

## AI TERMINAL PATTERNS

LLM-backed terminals are a 2025–2026 signature-move opportunity. The
pattern has three essential parts.

### Part 1: The terminal UI

A fixed-position panel (corner or full-screen modal) with:
- A scrolling output area.
- An input line with caret cursor.
- Status indicators (rate limit, typing, connection state).

Use monospace typography (JetBrains Mono, Berkeley Mono, IBM Plex Mono).
Render streamed tokens as they arrive; typing animations for scripted
messages should match token-by-token pacing.

### Part 2: The streaming backend

Use Server-Sent Events (SSE) or a streaming fetch to receive LLM tokens
as they're generated. The critical UX detail: tokens must render within
~300ms of generation. Anything slower feels broken.

Providers that support sub-second first token:
- **Groq** — fastest first-token latency; Llama 3.3 70B and 4-Scout.
- **Cerebras** — also very fast.
- **OpenAI** — reliable, moderate latency.
- **Anthropic** — Claude, moderate latency.

For a public-facing terminal, Groq is the right default: free tier is
generous, latency sells the UX illusion.

### Part 3: Rate limiting and prompt protection

A public terminal needs three protections:

1. **Rate limiting** per-IP at the edge (Vercel middleware, Cloudflare
   Workers). 10–20 messages per hour is reasonable for a portfolio
   terminal.
2. **Input sanitization** — strip attempts to override the system prompt.
   Use a template prompt that cannot be broken by user input.
3. **Fallback** — if the LLM provider fails, fall back to scripted
   responses. The terminal should never appear broken.

### Part 4: Accessibility

- **Keyboard operable.** Arrow keys scroll history, Tab moves focus in
  and out, Enter submits.
- **Screen-reader support.** Use `role="log"` with `aria-live="polite"`
  on the output area. New tokens announce incrementally.
- **Visible focus indicator** on the input.
- **Reduced motion.** Skip the typing animation on scripted messages;
  show full text immediately.

See `recipes/ai-terminal-widget.tsx` for a complete implementation
including Groq streaming, rate limiting, reduced-motion handling, and
`role="log"` ARIA integration.

---

## AMBIENT AUDIO

Audio that plays in the background, loops cleanly, and ideally responds
to user interaction. The single most abused element in creative web.

### The defaults

- **Off by default.** Autoplay audio is a violation; most browsers block
  it anyway.
- **Prominent toggle.** Top-right corner, clear icon, reachable via
  keyboard.
- **Fade in and out.** Never cut. Use Web Audio API's `GainNode` with
  linearRampToValueAtTime over 400–600ms.
- **Crossfade loop seam.** Even "seamless" loops have detectable seams
  after 30s; overlap two copies of the loop with crossfade.
- **Mute on tab blur.** `visibilitychange` event, ramp gain to 0 when
  document.hidden becomes true.
- **Respect user preference.** Store mute state in localStorage; persist
  across sessions.

```javascript
const audioContext = new (window.AudioContext || window.webkitAudioContext)()
const gainNode = audioContext.createGain()
gainNode.gain.value = 0  // start muted
gainNode.connect(audioContext.destination)

const response = await fetch('/audio/ambient.m4a')
const arrayBuffer = await response.arrayBuffer()
const audioBuffer = await audioContext.decodeAudioData(arrayBuffer)

const source = audioContext.createBufferSource()
source.buffer = audioBuffer
source.loop = true
source.connect(gainNode)
source.start()

function setVolume(value, duration = 0.5) {
  gainNode.gain.cancelScheduledValues(audioContext.currentTime)
  gainNode.gain.setValueAtTime(
    gainNode.gain.value,
    audioContext.currentTime
  )
  gainNode.gain.linearRampToValueAtTime(
    value,
    audioContext.currentTime + duration
  )
}

// Toggle handler
toggleButton.addEventListener('click', () => {
  const muted = gainNode.gain.value === 0
  setVolume(muted ? 0.4 : 0, 0.5)
  localStorage.setItem('audioMuted', !muted)
})

// Tab blur
document.addEventListener('visibilitychange', () => {
  setVolume(document.hidden ? 0 : 0.4, 0.3)
})
```

### Audio reactive to interaction

The Igloo Inc footer pattern: audio volume or filter parameters respond
to simulation state.

```javascript
// In the animation loop, modulate gain based on scroll velocity
const scrollVelocity = Math.abs(lenis.velocity)
const targetGain = 0.3 + Math.min(scrollVelocity / 50, 0.3)
setVolume(targetGain, 0.15)
```

Or modulate a low-pass filter cutoff based on scroll depth, so the sound
opens up as the user progresses through the page.

### Sourcing royalty-free audio

- **Freesound** — CC0 and CC-BY samples, good for specific sounds.
- **Pixabay Music** — free commercial-use music loops.
- **Uppbeat** — free tier with attribution, premium tier without.
- **Splice** — sample library; good for producers who want to assemble
  custom loops.

Avoid any source that requires "license inquiry" — that's legal exposure.

See `recipes/audio-reactive-gain.ts` for the full production setup.

---

## KEYBOARD NAVIGATION

Creative sites routinely fail keyboard navigation. The issues:

- Custom cursors replace mouse cursors, not `:focus-visible` outlines.
  Outlines must remain visible.
- Pinned sections confuse the scroll-restoration behavior browsers apply
  when Tab moves focus. Use `scroll-margin-top` to ensure focused elements
  remain visible below any sticky headers.
- Canvas elements are not keyboard-reachable by default. Add `tabindex="0"`
  and ARIA labels if the canvas is interactive; leave it out of tab order
  if it's purely decorative.
- Modals, menus, and custom widgets must trap focus. Use `focus-trap` or
  implement manually.

### Focus-visible rules

```css
:focus { outline: none; }   /* remove default on all focus */
:focus-visible {             /* restore only for keyboard users */
  outline: 2px solid var(--focus-color);
  outline-offset: 2px;
}
```

This produces the correct UX: mouse clicks don't show focus rings, Tab
key presses do.

### Skip links

For sites with heavy hero animations or slow-loading canvases, add a
"Skip to content" link as the first focusable element.

```html
<a href="#main-content" class="skip-link">Skip to content</a>
```

```css
.skip-link {
  position: absolute;
  left: -9999px;
}
.skip-link:focus {
  left: 1rem;
  top: 1rem;
  z-index: 10000;
}
```

---

## REDUCED MOTION AS A GATE

`prefers-reduced-motion` is the single most important accessibility
media query for creative web. Every motion primitive must honor it.

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

The above CSS is the blunt instrument. The correct approach is to design
a reduced-motion variant explicitly, not to strip all motion uniformly.

JavaScript gating:

```javascript
const prefersReducedMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)'
).matches

if (prefersReducedMotion) {
  // Use static alternatives
  // - No Lenis (native scroll)
  // - No fluid cursor (standard cursor)
  // - No camera paths (instant section changes)
  // - No ambient audio autoplay hint (no pulsing toggle)
  // - Typing animations complete instantly
}
```

---

## MOBILE INTERACTION DEGRADATION

Mobile is not a responsive desktop. Touch interactions fundamentally
differ from mouse interactions.

### Rules for mobile

- **No custom cursor.** Touch users don't see cursors.
- **No hover-dependent interactions.** Replace with tap or always-visible
  state.
- **No magnetic effects.** Tap targets, not cursor-responsive elements.
- **Horizontal scroll often breaks.** Either redesign as vertical stack
  or commit to the swipe UX (with visual affordances).
- **Reduce WebGL complexity.** Lower particle counts, lower-resolution
  render targets, fewer post-processing passes, lower-fps ambient scenes.
- **Video autoplay needs `muted` attribute.** Required by iOS Safari.
- **Native scroll, not Lenis.** Lenis's `smoothTouch: false` preserves
  the system momentum scroll users expect.

### The orientation question

Some sites (Lando Norris) ship an "orientation nag" — a full-screen
message asking users to rotate to landscape. This is defensible for an
experiential brand site where the designed composition requires a wide
aspect ratio. It is not acceptable for a portfolio, product site, or
anything where the audience expects to read on their phone without
friction.

If the site justifies an orientation nag, honor the user's choice: a
"view anyway" button that commits to the portrait experience, even if
degraded.

---

## THE INTERACTION CHECKPOINT

Before implementing interaction surfaces:

1. **Custom cursor tier?** Tier 1 (dot) / 2 (contextual) / 3 (canvas) /
   4 (signature)?
2. **Magnetic buttons — which CTAs?** Limit to 1–3 primary actions.
3. **AI terminal scope?** Widget / full section / signature interaction?
4. **LLM provider?** Groq / OpenAI / Anthropic — default Groq for
   portfolios.
5. **Ambient audio?** Off by default, toggleable, tab-blur-mute.
6. **Audio-reactive to scroll or interaction state?** If yes, what maps
   to what.
7. **Keyboard navigation plan?** Focus-visible rules, skip link, focus
   trap for modals.
8. **Reduced-motion variant?** Designed explicitly, not just stripped.
9. **Mobile interaction plan?** What degrades, what's removed, what's
   replaced.

With these answered, proceed to implementation via recipes.
