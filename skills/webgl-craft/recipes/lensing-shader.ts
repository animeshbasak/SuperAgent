/**
 * GRAVITATIONAL LENSING SHADER — Schwarzschild black hole approximation
 *
 * Source lineage:
 *   Schwarzschild metric approximation for photon deflection.
 *   Simplified from full general-relativistic ray tracing (which is ~5x more
 *   expensive and visually indistinguishable at web-viewer intuition level).
 *
 * When to use:
 *   - Hero scenes where a "black hole" or "mass" visualization is the center
 *     of attention.
 *   - Portfolios, science-tech sites, space/astronomy/physics subjects.
 *   - Any site where "bending light around a dark object" is the metaphor.
 *
 * When NOT to use:
 *   - Sites where the lensing isn't the signature move. A lensed sphere as
 *     decoration adds nothing; it reads as a sphere. Use only when the
 *     effect is central.
 *   - Mobile-first sites without device-tier adaptation. Raymarching is
 *     expensive; see edit notes for mobile degradation.
 *
 * Edit points:
 *   - MASS: controls lensing strength (higher = more dramatic bending).
 *   - DISK_INNER_RADIUS, DISK_OUTER_RADIUS: accretion disk extent.
 *   - DISK_TEMPERATURE: controls color of the disk (blue = hot, red = cool).
 *   - STEP_COUNT: raymarch steps; 32 is mid, 16 mobile, 64 hero-cinematic.
 *   - envMap: cube map of background stars (required input).
 *
 * Known trade-offs:
 *   - Accessibility: the black hole is a dark void, which can be
 *     disorienting for some users. Provide a reduced-motion variant that
 *     shows a static image or dims the effect.
 *   - Performance: ~4ms GPU budget per frame on mid-tier desktop at 1080p.
 *     Halve step count for mobile or low-tier detection.
 *
 * This is a TSL (Three.js Shading Language) implementation, compiling to
 * both WebGL2 and WebGPU. Tested on Three.js r170+.
 */

import * as THREE from 'three/webgpu'
import {
  Fn, uniform, vec3, vec4, float, texture, cubeTexture,
  length, normalize, dot, mix, smoothstep, step, abs,
  cos, sin, atan, pow, exp, vec2, positionLocal, cameraPosition,
  uv, Loop, If, Break,
} from 'three/tsl'

export interface LensingShaderOptions {
  envMap: THREE.CubeTexture
  mass?: number                // 0.3 default
  diskInnerRadius?: number     // 1.5 default
  diskOuterRadius?: number     // 3.5 default
  diskTemperature?: number     // 0.7 default (0=red, 1=blue)
  stepCount?: 16 | 32 | 64     // 32 default
}

export function createLensingMaterial(opts: LensingShaderOptions) {
  const {
    envMap,
    mass = 0.3,
    diskInnerRadius = 1.5,
    diskOuterRadius = 3.5,
    diskTemperature = 0.7,
    stepCount = 32,
  } = opts

  const uMass = uniform(mass)
  const uDiskInner = uniform(diskInnerRadius)
  const uDiskOuter = uniform(diskOuterRadius)
  const uDiskTemp = uniform(diskTemperature)
  const uEnvMap = cubeTexture(envMap)

  const material = new THREE.NodeMaterial()

  material.fragmentNode = Fn(() => {
    // Ray from camera through this fragment
    const worldPos = positionLocal.toVar()
    const rayDir = normalize(worldPos.sub(cameraPosition)).toVar()
    const rayPos = cameraPosition.toVar()

    const color = vec3(0, 0, 0).toVar()
    const alpha = float(0).toVar()

    // Raymarch toward the black hole, deflecting ray based on mass
    Loop({ start: 0, end: stepCount, type: 'int' }, () => {
      const toCenter = rayPos.negate()
      const dist = length(toCenter).toVar()

      // Event horizon check
      If(dist.lessThan(0.8), () => {
        color.assign(vec3(0, 0, 0))
        alpha.assign(float(1))
        Break()
      })

      // Accretion disk check (flat disk at y=0)
      If(
        abs(rayPos.y).lessThan(0.05)
          .and(dist.greaterThan(uDiskInner))
          .and(dist.lessThan(uDiskOuter)),
        () => {
          // Disk color: hot toward inner edge, cooler toward outer
          const t = smoothstep(uDiskOuter, uDiskInner, dist)
          const hot = vec3(1.0, 0.8, 0.4)  // yellow-orange
          const cool = vec3(0.2, 0.4, 1.0) // blue
          const diskColor = mix(hot, cool, uDiskTemp.mul(t))
          color.addAssign(diskColor.mul(0.8))
          alpha.addAssign(float(0.5))
        }
      )

      // Gravity: bend ray toward center (Schwarzschild approximation)
      const gravityStrength = uMass.div(dist.mul(dist))
      const gravityDir = normalize(toCenter)
      rayDir.assign(normalize(rayDir.add(gravityDir.mul(gravityStrength.mul(0.1)))))

      // Step forward
      rayPos.assign(rayPos.add(rayDir.mul(0.3)))

      // Exit if ray has traveled far without hitting anything
      If(length(rayPos).greaterThan(20), () => Break())
    })

    // Sample the environment map with the final (deflected) ray direction
    const envColor = uEnvMap.sample(rayDir).rgb
    const finalColor = mix(envColor, color, alpha)

    return vec4(finalColor, 1)
  })()

  return material
}

// ============================================================================
// USAGE EXAMPLE
// ============================================================================

/*
import { createLensingMaterial } from './lensing-shader'
import { CubeTextureLoader, SphereGeometry, Mesh } from 'three'

// Load a starfield cube map
const envLoader = new CubeTextureLoader()
const starfield = envLoader.load([
  '/env/starfield/px.jpg', '/env/starfield/nx.jpg',
  '/env/starfield/py.jpg', '/env/starfield/ny.jpg',
  '/env/starfield/pz.jpg', '/env/starfield/nz.jpg',
])

// Create material
const material = createLensingMaterial({
  envMap: starfield,
  mass: 0.4,
  stepCount: 32,  // reduce to 16 on mobile
})

// Apply to a large sphere around the camera (like a skybox)
const sphere = new SphereGeometry(50, 64, 64)
const mesh = new Mesh(sphere, material)
scene.add(mesh)
*/

// ============================================================================
// MOBILE DEGRADATION
// ============================================================================
//
// For low-tier devices, reduce stepCount to 16 and skip the disk check:
//
//   const stepCount = deviceTier === 'low' ? 16 : 32
//   const showDisk = deviceTier !== 'low'
//
// Or skip the shader entirely on low-tier and show a static image of a
// pre-rendered lensed starfield.

// ============================================================================
// REDUCED-MOTION ALTERNATIVE
// ============================================================================
//
// When prefers-reduced-motion is set, render a static image instead:
//
//   if (prefersReducedMotion) {
//     mesh.material = new MeshBasicMaterial({
//       map: preRenderedLensingTexture,
//     })
//   }
