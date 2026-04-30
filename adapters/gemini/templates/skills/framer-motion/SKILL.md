---
name: framer-motion
description: Build production-grade React animation with framer-motion (`motion` API). Triggers on "framer motion", "animate this component", "animate presence", "page transition", "layout animation", "spring animation", "drag/gesture", "scroll-linked animation", "stagger children", "exit animation", "shared layout". Use for component-level motion in a React/Next.js codebase. Routes alongside `ui-ux-pro-max` for design coherence and `webgl-craft` only when the motion is cinematic / 3D.
---

# framer-motion

Component-level motion intelligence for React. Covers the seven primitives
that ship most of the value in real apps:

1. **`<motion.*>` primitive** — declarative animate / initial / exit.
2. **`AnimatePresence`** — exit animations for unmounting components.
3. **Variants** — orchestrated animation states with `staggerChildren`.
4. **Layout animations** — `layout` / `layoutId` for shared element transitions.
5. **Gestures** — `whileHover`, `whileTap`, `drag`, `dragConstraints`.
6. **Scroll-linked motion** — `useScroll`, `useTransform`, `useMotionValue`.
7. **Springs vs tweens** — when to use which transition shape.

## When to use

- User types "use framer-motion to …", "animate this", "add a page transition",
  "stagger these list items", "when the modal closes …", "make this draggable".
- User asks for **named patterns**: shared layout animation, hero image
  morphing into a card, scroll-driven parallax, swipeable carousel,
  orchestrated reveal, micro-interaction on hover/tap.
- Codebase already imports `framer-motion` or `motion/react` (check
  `package.json`).

**Do NOT use for:**
- 3D / WebGL / shader-based motion → `webgl-craft`.
- Static layout / typography / color decisions → `ui-ux-pro-max`.
- Rendered video output (HTML → MP4) → `video-craft`.
- CSS-only transitions / Tailwind `transition-*` utilities — those don't
  need framer-motion.

## Procedure

### 1. Confirm the dependency

```bash
grep -E '"(framer-motion|motion)":' package.json || true
```

- Already installed → continue.
- Missing → install with the project's package manager:
  - `pnpm add framer-motion` (or `motion` for v12+)
  - `npm i framer-motion`
  - `yarn add framer-motion`
- App Router projects: most motion components must run client-side. Add
  `'use client'` at the top of any file using `motion.*`, `AnimatePresence`,
  `useScroll`, etc.

### 2. Pick the primitive — decision table

| User intent                                    | Primitive                                         |
| ---------------------------------------------- | ------------------------------------------------- |
| Fade / slide on mount                          | `<motion.div initial animate transition>`         |
| Fade / slide on unmount                        | wrap in `<AnimatePresence>` + `exit={...}`        |
| Modal / drawer open ↔ close                    | `AnimatePresence` + `exit` + `mode="wait"` if needed |
| Route / page transition (App Router)           | `template.tsx` + `AnimatePresence` (`mode="wait"`) wrapping `{children}` keyed by pathname |
| List reveal one-by-one                         | parent variants + `staggerChildren` + child variants |
| Hero image morphs into a detail card           | `layoutId="hero"` on both elements                |
| Reorder grid / list smoothly                   | `layout` prop on each item                        |
| Hover / tap micro-interaction                  | `whileHover` / `whileTap`                         |
| Draggable card, swipeable                      | `drag` / `dragConstraints` / `dragElastic`        |
| Scroll progress bar                            | `useScroll().scrollYProgress` → `motion.div` width |
| Parallax / pin-on-scroll                       | `useScroll({ target, offset })` + `useTransform`  |
| Spring-feel (squishy)                          | `transition={{ type: "spring", stiffness, damping }}` |
| Smooth ease (no bounce)                        | `transition={{ duration, ease: [0.16, 1, 0.3, 1] }}` |

### 3. Lock the timing language

Use **one** of these three transition presets across the codebase. Don't
invent new easings ad-hoc — it produces an inconsistent feel.

```ts
// utils/motion.ts
export const easeOut: Transition  = { duration: 0.4, ease: [0.16, 1, 0.3, 1] };
export const easeOutSlow: Transition = { duration: 0.7, ease: [0.16, 1, 0.3, 1] };
export const spring: Transition   = { type: "spring", stiffness: 380, damping: 32, mass: 0.7 };
```

Reach for `spring` when the element responds to user input (drag, hover,
tap). Reach for `easeOut` for entry/exit. Reach for `easeOutSlow` for hero
or page-level reveals.

### 4. Variants — only when there's orchestration

Variants pay off when:

- A parent triggers child animations (`staggerChildren`, `delayChildren`).
- The same element animates through three or more named states.

For two-state component-level animation, inline `initial / animate /
transition` props are simpler and easier to read.

```tsx
const list = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.06, delayChildren: 0.1 } }
};
const item = {
  hidden: { opacity: 0, y: 16 },
  show:   { opacity: 1, y: 0, transition: easeOut }
};
```

### 5. AnimatePresence — exact rules

- Direct children of `<AnimatePresence>` MUST have a unique, stable `key`
  prop — otherwise exit animations don't fire.
- Use `mode="wait"` when the new element should mount only after the old
  one finishes exiting (page transitions).
- Use `mode="popLayout"` when items leave inside a flex/grid layout — it
  briefly removes them from layout flow so siblings don't jump.
- `initial={false}` on the parent skips the very-first mount animation
  (avoids a flash on hydration).

### 6. Layout animations — gotchas

- `layout` works on properties FLIP can interpolate (transform/opacity).
  It does NOT work on `width: auto` → `width: 200px` directly. Wrap the
  changing element or animate explicit numeric values.
- `layoutId` requires the same string on the source and target. They must
  exist in the same `<LayoutGroup>` (or globally if not nested).
- Layout animation respects `transition`. Pair with a spring for tactile
  feel.

### 7. Performance — only animate cheap properties

Animate `transform` (`x`, `y`, `scale`, `rotate`) and `opacity`. Avoid
animating `width`, `height`, `top`, `left`, `box-shadow`, `filter` in hot
paths — they trigger layout / paint and tank framerate on lower-end
devices. When you must animate a non-transform property, use `layout` and
let framer-motion FLIP the change.

For lists with many animated children, set `style={{ willChange: "transform, opacity" }}`
on items only while they're animating, not permanently — `willChange`
forces a compositor layer and over-using it costs memory.

### 8. App Router page transitions — minimal recipe

```tsx
// app/template.tsx
'use client';
import { motion, AnimatePresence } from "framer-motion";
import { usePathname } from "next/navigation";

export default function Template({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <AnimatePresence mode="wait" initial={false}>
      <motion.div
        key={pathname}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -8 }}
        transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
      >
        {children}
      </motion.div>
    </AnimatePresence>
  );
}
```

`template.tsx` (not `layout.tsx`) is the right file — Next remounts
templates on every navigation, which is what makes the exit animation
fire.

### 9. Accessibility — never ignore

Every animation must respect `prefers-reduced-motion`. framer-motion gives
you `useReducedMotion()`:

```tsx
const reduce = useReducedMotion();
<motion.div animate={{ y: reduce ? 0 : 16 }} />
```

Or globally cap durations to 0 with a `MotionConfig` wrapper. Bouncy
springs and large translations are the worst offenders for vestibular
sensitivity — disable them under reduced-motion, don't just shorten them.

## Verification

Before claiming a framer-motion task complete:

- [ ] Component file starts with `'use client'` if it uses motion APIs in
      App Router.
- [ ] Exit animation lives inside `<AnimatePresence>` with a stable `key`.
- [ ] Animated properties are transform / opacity (or `layout` is used).
- [ ] `useReducedMotion` is honored — no large unguarded translations.
- [ ] Transition shape matches the codebase preset (don't invent easings).
- [ ] `npm run typecheck` passes (framer-motion has strict variant types).

## Edge cases

- **Hydration mismatch** — `initial={false}` on the outermost
  `AnimatePresence` skips the SSR-vs-client first-render diff.
- **Items pop out of layout on exit** — switch `mode="wait"` →
  `mode="popLayout"`.
- **`layoutId` morph jumps** — both elements must mount within the same
  layout group, and the morph properties must be transform-compatible.
- **Drag against scroll** — set `dragDirectionLock` and constrain on the
  axis you want; otherwise touch users can't scroll past the draggable.
- **Hover stuck on touch devices** — `whileHover` fires on touch-down on
  some browsers. Pair with `whileTap` and add a media-query guard.
- **Bundle size concern** — import from `framer-motion/dom` for
  non-React-DOM use (rare); for React, the v11+ tree-shaking is good
  enough that explicit dynamic imports usually aren't needed.

## References

- Official: https://www.framer.com/motion/
- v12 (rebranded to `motion`): https://motion.dev/
- App Router patterns: see `template.tsx` recipe above.
