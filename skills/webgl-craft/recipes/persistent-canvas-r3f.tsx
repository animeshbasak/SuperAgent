/**
 * PERSISTENT CANVAS ACROSS ROUTES — Next.js 15 App Router + React Three Fiber
 *
 * Source lineage:
 *   Active Theory Hydra pattern (Prometheus Fuels), Barba.js pattern (Lando Norris).
 *
 * When to use:
 *   - Hybrid or Persistent-World architectures where the WebGL scene should
 *     survive route changes without remounting.
 *   - Sites with a continuous scene (e.g., a camera flying through a world)
 *     where discrete page navigations would break the illusion.
 *
 * When NOT to use:
 *   - DOM-first sites (overkill).
 *   - Sites where each route is a genuinely different scene. Use per-route
 *     <Canvas> mounts instead.
 *
 * Edit points:
 *   - CAMERA_POSITIONS: one 3D position per route.
 *   - TRANSITION_DURATION: how long camera-move takes between routes.
 *   - The <Scene /> component: swap for your own scene.
 *
 * Known trade-offs:
 *   - The canvas stays mounted even on routes that don't use it. Acceptable
 *     cost for continuity.
 *   - Requires careful state management (Zustand below) to avoid React
 *     re-render storms from scroll state.
 *
 * File layout:
 *   app/layout.tsx          ← mounts the Canvas once
 *   app/providers.tsx       ← Zustand store + route listener
 *   app/page.tsx            ← route-specific DOM content
 *   app/projects/page.tsx   ← route-specific DOM content
 *   components/Scene.tsx    ← the WebGL scene (camera, meshes, etc)
 */

// ============================================================================
// app/layout.tsx
// ============================================================================

import { Providers } from './providers'
import { PersistentCanvas } from '@/components/PersistentCanvas'

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <Providers>
          {/* Canvas mounted at layout level — survives page changes */}
          <PersistentCanvas />

          {/* DOM content layered above the canvas */}
          <main className="relative z-10">{children}</main>
        </Providers>
      </body>
    </html>
  )
}

// ============================================================================
// components/PersistentCanvas.tsx
// ============================================================================

'use client'

import { Canvas } from '@react-three/fiber'
import { Scene } from './Scene'

export function PersistentCanvas() {
  return (
    <div
      className="fixed inset-0 z-0"
      style={{ pointerEvents: 'none' }}
      aria-hidden="true"
    >
      <Canvas
        camera={{ position: [0, 0, 5], fov: 45 }}
        dpr={[1, 2]}
        gl={{ antialias: true, alpha: true }}
      >
        <Scene />
      </Canvas>
    </div>
  )
}

// ============================================================================
// app/providers.tsx — scene state and route listener
// ============================================================================

'use client'

import { create } from 'zustand'
import { usePathname } from 'next/navigation'
import { useEffect } from 'react'

// Camera target positions per route. Edit this for your site's architecture.
const CAMERA_POSITIONS: Record<string, [number, number, number]> = {
  '/': [0, 0, 5],
  '/projects': [3, 1, 2],
  '/about': [-2, 2, 3],
  '/contact': [0, -1, 6],
}

const TRANSITION_DURATION = 1.2 // seconds

interface SceneState {
  targetPosition: [number, number, number]
  transitionProgress: number
  setTargetPosition: (p: [number, number, number]) => void
  setTransitionProgress: (p: number) => void
}

export const useSceneStore = create<SceneState>((set) => ({
  targetPosition: CAMERA_POSITIONS['/'],
  transitionProgress: 1,
  setTargetPosition: (p) => set({ targetPosition: p, transitionProgress: 0 }),
  setTransitionProgress: (p) => set({ transitionProgress: p }),
}))

export function Providers({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const setTargetPosition = useSceneStore((s) => s.setTargetPosition)

  useEffect(() => {
    const target = CAMERA_POSITIONS[pathname] ?? CAMERA_POSITIONS['/']
    setTargetPosition(target)
  }, [pathname, setTargetPosition])

  return <>{children}</>
}

// ============================================================================
// components/Scene.tsx — the WebGL scene
// ============================================================================

'use client'

import { useFrame } from '@react-three/fiber'
import { useRef } from 'react'
import { Mesh, Vector3 } from 'three'
import { useSceneStore } from '@/app/providers'

export function Scene() {
  const meshRef = useRef<Mesh>(null)
  const targetPositionVec = useRef(new Vector3())

  useFrame((state) => {
    const { targetPosition } = useSceneStore.getState()
    targetPositionVec.current.set(...targetPosition)

    // Lerp camera toward target — the "route transition" visualization
    state.camera.position.lerp(targetPositionVec.current, 0.05)
    state.camera.lookAt(0, 0, 0)

    // Hero mesh rotates
    if (meshRef.current) {
      meshRef.current.rotation.y = state.clock.elapsedTime * 0.2
    }
  })

  return (
    <>
      <ambientLight intensity={0.3} />
      <directionalLight position={[5, 5, 5]} intensity={1} />

      <mesh ref={meshRef}>
        <icosahedronGeometry args={[1, 2]} />
        <meshStandardMaterial color="#4a9eff" wireframe />
      </mesh>
    </>
  )
}

// ============================================================================
// USAGE NOTES
// ============================================================================
//
// 1. DOM content for each route goes in app/[route]/page.tsx as normal.
//    The canvas stays mounted; only the DOM content swaps.
//
// 2. To add page transitions on the DOM layer, wrap {children} in
//    Framer Motion's <AnimatePresence mode="wait">.
//
// 3. For scroll-driven camera moves instead of route-driven, replace
//    the pathname effect with a GSAP ScrollTrigger that updates
//    targetPosition on scroll progress.
//
// 4. The canvas has pointerEvents: 'none' so DOM content remains
//    interactive. If the canvas itself needs interaction (e.g.,
//    orbit controls), set pointer-events: auto on interactive elements
//    via CSS, not on the wrapper.
//
// 5. Accessibility: the canvas has aria-hidden="true". Any text
//    content must exist in the DOM for screen readers.
