/**
 * BARBA-STYLE PAGE TRANSITIONS — Next.js App Router + Framer Motion
 *
 * Source lineage:
 *   Barba.js pattern (persistent canvas, DOM swap with enter/leave animations)
 *   adapted to the React ecosystem. Used in Lando Norris and OFF+BRAND sites.
 *   The React equivalent of Barba's classic "wrapper swap with transitions."
 *
 * When to use:
 *   - Hybrid sites where the WebGL canvas persists across routes but the
 *     DOM content swaps with animated transitions.
 *   - Sites where navigation should feel cinematic, not abrupt.
 *   - Any site using the persistent-canvas-r3f recipe.
 *
 * When NOT to use:
 *   - SEO-critical sites where JS-driven transitions might break crawler
 *     behavior. Next.js App Router handles this correctly, but plain SPAs
 *     with client-side routing break SEO without care.
 *   - Simple portfolios where instant page changes are fine.
 *
 * Edit points:
 *   - exit / enter animation variants: tune duration, easing, direction.
 *   - The canvas transition effect: what the WebGL layer does during the swap.
 *   - mode="wait" vs mode="sync": whether exit completes before enter starts.
 *
 * Known trade-offs:
 *   - Transitions add ~400–800ms of perceived navigation delay. Users
 *     accept this as cinematic; tighten to 300ms if it feels sluggish.
 *   - Accessibility: prefers-reduced-motion skips transitions entirely.
 */

// ============================================================================
// app/template.tsx — wraps every route with transition logic
// ============================================================================

'use client'

import { AnimatePresence, motion } from 'framer-motion'
import { usePathname } from 'next/navigation'
import { useEffect } from 'react'
import { useSceneStore } from './providers'

const pageVariants = {
  initial: { opacity: 0, y: 20 },
  enter: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.6, ease: [0.22, 1, 0.36, 1] },
  },
  exit: {
    opacity: 0,
    y: -20,
    transition: { duration: 0.4, ease: [0.64, 0, 0.78, 0] },
  },
}

export default function Template({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const setTransitionProgress = useSceneStore((s) => s.setTransitionProgress)

  // Trigger a canvas-side transition effect during route change
  useEffect(() => {
    setTransitionProgress(0)
    const t = setTimeout(() => setTransitionProgress(1), 600)
    return () => clearTimeout(t)
  }, [pathname, setTransitionProgress])

  return (
    <AnimatePresence mode="wait" initial={false}>
      <motion.div
        key={pathname}
        variants={pageVariants}
        initial="initial"
        animate="enter"
        exit="exit"
      >
        {children}
      </motion.div>
    </AnimatePresence>
  )
}

// ============================================================================
// components/Scene.tsx — canvas reacts to transition state
// ============================================================================

'use client'

import { useFrame } from '@react-three/fiber'
import { useRef } from 'react'
import * as THREE from 'three'
import { useSceneStore } from '@/app/providers'

export function TransitionAwareScene() {
  const meshRef = useRef<THREE.Mesh>(null)
  const transitionUniform = useRef({ value: 1 })

  useFrame((state) => {
    const { transitionProgress } = useSceneStore.getState()

    // Smoothly interpolate to current transition value
    transitionUniform.current.value +=
      (transitionProgress - transitionUniform.current.value) * 0.08

    if (meshRef.current) {
      const mat = meshRef.current.material as THREE.ShaderMaterial
      if (mat?.uniforms?.uTransition) {
        mat.uniforms.uTransition.value = transitionUniform.current.value
      }

      // Example: scale dip during transition
      const scale = 0.9 + transitionUniform.current.value * 0.1
      meshRef.current.scale.setScalar(scale)
    }
  })

  return (
    <mesh ref={meshRef}>
      <icosahedronGeometry args={[1, 3]} />
      <shaderMaterial
        uniforms={{
          uTransition: { value: 1 },
          uTime: { value: 0 },
        }}
        vertexShader={/* glsl */ `
          uniform float uTransition;
          uniform float uTime;
          varying vec3 vNormal;

          void main() {
            vNormal = normal;

            // During transition (uTransition → 0), distort geometry outward
            float distortion = (1.0 - uTransition) * 0.3;
            vec3 pos = position + normal * distortion * sin(uTime * 3.0);

            gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
          }
        `}
        fragmentShader={/* glsl */ `
          uniform float uTransition;
          varying vec3 vNormal;

          void main() {
            vec3 baseColor = vec3(0.29, 0.62, 1.0);  // Interstellar signal blue

            // Dim during transition for a "held breath" moment
            vec3 color = baseColor * (0.5 + uTransition * 0.5);

            gl_FragColor = vec4(color, 1.0);
          }
        `}
      />
    </mesh>
  )
}

// ============================================================================
// REDUCED-MOTION VARIANT
// ============================================================================

'use client'

import { useReducedMotion } from 'framer-motion'

export function TemplateWithReducedMotion({
  children,
}: {
  children: React.ReactNode
}) {
  const pathname = usePathname()
  const shouldReduceMotion = useReducedMotion()

  const variants = shouldReduceMotion
    ? {
        initial: { opacity: 0 },
        enter: { opacity: 1, transition: { duration: 0.01 } },
        exit: { opacity: 0, transition: { duration: 0.01 } },
      }
    : pageVariants

  return (
    <AnimatePresence mode="wait" initial={false}>
      <motion.div
        key={pathname}
        variants={variants}
        initial="initial"
        animate="enter"
        exit="exit"
      >
        {children}
      </motion.div>
    </AnimatePresence>
  )
}

// ============================================================================
// MANUAL TRIGGER — start a transition before navigation completes
// ============================================================================
//
// For cases where you want the canvas transition to start BEFORE the route
// actually changes (so the visual feels anticipatory), intercept the link
// click:
//
//   import { useRouter } from 'next/navigation'
//
//   const router = useRouter()
//
//   const handleClick = (e: React.MouseEvent, href: string) => {
//     e.preventDefault()
//     setTransitionProgress(0)  // start canvas effect
//     setTimeout(() => router.push(href), 300)  // navigate after delay
//   }
//
//   <a href="/projects" onClick={(e) => handleClick(e, '/projects')}>
//     Projects
//   </a>

// ============================================================================
// CANVAS TRANSITION IDEAS
// ============================================================================
//
// The transition uniform (0 during swap, 1 otherwise) can drive:
//
//   - Geometry scale/distortion (as shown above)
//   - Bloom intensity spike (momentary flare)
//   - Chromatic aberration ramp (glitch feel)
//   - Color desaturation (held-breath feel)
//   - Camera shake amplitude
//   - Particle emission rate
//
// Pick ONE effect per site. Multiple transition effects at once feels
// chaotic and undercuts the cinematic intent.

// ============================================================================
// NEXT.JS NOTES
// ============================================================================
//
// - template.tsx re-renders on every route change (unlike layout.tsx).
//   This is what enables AnimatePresence to detect the swap.
//
// - If using loading.tsx, ensure the loading state also participates in
//   AnimatePresence or it will flash between states.
//
// - The persistent canvas should live in layout.tsx (above template.tsx)
//   so it doesn't remount during transitions.
