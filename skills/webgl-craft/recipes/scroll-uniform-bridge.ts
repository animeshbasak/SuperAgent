/**
 * SCROLL-TO-UNIFORM BRIDGE — GSAP ScrollTrigger → Three.js shader uniform
 *
 * Source lineage:
 *   Standard 2024+ pattern for hybrid WebGL sites. Used in Shopify Editions,
 *   Prometheus Fuels, and most Awwwards-tier hybrid sites.
 *
 * When to use:
 *   - Any time scroll progress needs to drive a WebGL value: camera
 *     position, material parameter, post-processing intensity, particle
 *     emission rate.
 *   - Whenever the DOM and WebGL layers must stay in sync during scroll.
 *
 * When NOT to use:
 *   - Non-scroll-driven effects (mouse-driven, time-driven, event-driven).
 *     Use refs and per-frame updates directly.
 *
 * Edit points:
 *   - The uniform paths: map scroll progress to specific uniforms.
 *   - ScrollTrigger's start/end: anchor points for each transition.
 *   - The scrub value: 0 (tight) to 2 (elastic) depending on feel.
 *
 * Known trade-offs:
 *   - Requires Lenis + GSAP ScrollTrigger. See motion-scroll.md for setup.
 *   - On rapid scroll, scrub=1 lags visibly. Use scrub=true (no lag) for
 *     tight coupling, scrub=1 for cinematic feel.
 */

import { gsap } from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

gsap.registerPlugin(ScrollTrigger)

/**
 * Binds a scroll range to one or more shader uniforms.
 *
 * @param trigger - CSS selector for the scroll-anchoring element
 * @param uniforms - uniform objects to update { value: number }
 * @param opts - ScrollTrigger configuration
 */
export function bindScrollToUniforms(
  trigger: string,
  uniforms: { [key: string]: { value: number } },
  opts: {
    start?: string
    end?: string
    scrub?: boolean | number
    ranges?: { [key: string]: [number, number] } // uniform name → [start, end]
  } = {}
) {
  const {
    start = 'top top',
    end = 'bottom bottom',
    scrub = 1,
    ranges = {},
  } = opts

  const tl = gsap.timeline({
    scrollTrigger: {
      trigger,
      start,
      end,
      scrub,
    },
  })

  Object.entries(uniforms).forEach(([name, uniform]) => {
    const [rangeStart, rangeEnd] = ranges[name] ?? [0, 1]
    tl.fromTo(
      uniform,
      { value: rangeStart },
      { value: rangeEnd, ease: 'none' },
      0
    )
  })

  return tl
}

// ============================================================================
// SIMPLE USAGE — single uniform tracking scroll progress
// ============================================================================

/*
import { ShaderMaterial } from 'three'

const material = new ShaderMaterial({
  uniforms: {
    uProgress: { value: 0 },  // 0 → 1 across the section
  },
  // ... vertex/fragment shaders
})

bindScrollToUniforms('.hero-section', {
  uProgress: material.uniforms.uProgress,
})
*/

// ============================================================================
// ADVANCED USAGE — per-uniform ranges, multiple phases
// ============================================================================

/*
bindScrollToUniforms('.narrative-section', {
  uCameraZ: material.uniforms.uCameraZ,
  uMass: material.uniforms.uMass,
  uBloom: material.uniforms.uBloom,
}, {
  start: 'top top',
  end: '+=300%',  // 3 viewports of pin
  scrub: 1,
  ranges: {
    uCameraZ: [5, -10],     // camera pulls away
    uMass: [0, 0.5],        // black hole grows
    uBloom: [0.3, 1.2],     // bloom intensifies
  },
})
*/

// ============================================================================
// MULTI-PHASE TIMELINE (non-linear scroll progress per uniform)
// ============================================================================

/**
 * For multi-phase effects where each uniform follows a non-linear path,
 * author a full GSAP timeline instead of using the simple helper.
 */
export function multiPhaseScrollTimeline(
  trigger: string,
  material: { uniforms: Record<string, { value: number }> }
) {
  const tl = gsap.timeline({
    scrollTrigger: {
      trigger,
      start: 'top top',
      end: '+=400%',
      scrub: 1,
      pin: true,
    },
  })

  // Phase 1: 0–25% — hero revealed
  tl.fromTo(material.uniforms.uReveal, { value: 0 }, { value: 1 }, 0)

  // Phase 2: 25–50% — mass grows
  tl.fromTo(material.uniforms.uMass, { value: 0 }, { value: 0.4 }, 1)

  // Phase 3: 50–75% — camera rotates
  tl.fromTo(
    material.uniforms.uCameraRotation,
    { value: 0 },
    { value: Math.PI * 2 },
    2
  )

  // Phase 4: 75–100% — fade out
  tl.fromTo(material.uniforms.uReveal, { value: 1 }, { value: 0 }, 3)

  return tl
}

// ============================================================================
// REDUCED-MOTION HANDLING
// ============================================================================

/**
 * Wrap all scroll-to-uniform bindings in a matchMedia check so
 * reduced-motion users get static uniforms.
 */
export function bindScrollToUniformsWithReducedMotion(
  trigger: string,
  uniforms: { [key: string]: { value: number } },
  opts: Parameters<typeof bindScrollToUniforms>[2] = {}
) {
  ScrollTrigger.matchMedia({
    '(prefers-reduced-motion: no-preference)': () => {
      bindScrollToUniforms(trigger, uniforms, opts)
    },
    '(prefers-reduced-motion: reduce)': () => {
      // Set uniforms to their mid-point (or end-state) and leave them
      Object.entries(uniforms).forEach(([name, uniform]) => {
        const [, end] = opts.ranges?.[name] ?? [0, 1]
        uniform.value = end
      })
    },
  })
}

// ============================================================================
// CLEANUP ON UNMOUNT (React)
// ============================================================================

/*
import { useEffect } from 'react'

useEffect(() => {
  const ctx = gsap.context(() => {
    bindScrollToUniforms('.hero', { uProgress: material.uniforms.uProgress })
  })
  return () => ctx.revert()
}, [])
*/
