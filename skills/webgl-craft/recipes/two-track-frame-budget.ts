/**
 * TWO-TRACK FRAME BUDGET — primary scene at native FPS, secondary at 12fps
 *
 * Source lineage:
 *   Active Theory / Prometheus Fuels pattern disclosed in the Active Theory
 *   Medium case study: "60 fps main camera and 12 fps handcrafted effects."
 *
 * When to use:
 *   - Any site with an expensive hero scene AND ambient/background elements.
 *   - When profiling shows GPU saturation and reducing particle count or
 *     resolution would be visible.
 *   - When the "secondary" elements are ambient (no user attention on them).
 *
 * When NOT to use:
 *   - Scenes where everything is primary (fighting games, interactive
 *     simulations).
 *   - Scenes where secondary elements are large on screen (they'll read as
 *     laggy).
 *
 * Edit points:
 *   - SECONDARY_FPS: typically 12–15. Below 10 reads as broken; above 20
 *     gives diminishing returns.
 *   - The primary/secondary scene split: design-time decision of which
 *     elements go in which scene.
 *
 * Known trade-offs:
 *   - Requires separating elements into two scenes at authoring time.
 *     Cannot be retrofitted easily.
 *   - Transparent secondary content may flicker at scene boundaries; use
 *     temporal smoothing if visible.
 */

import * as THREE from 'three'

export interface FrameBudgetOptions {
  renderer: THREE.WebGLRenderer
  primaryScene: THREE.Scene
  secondaryScene: THREE.Scene
  camera: THREE.Camera
  secondaryFps?: number
  /** If true, secondary renders to its own target and composites in */
  useRenderTarget?: boolean
}

export class TwoTrackFrameBudget {
  private renderer: THREE.WebGLRenderer
  private primaryScene: THREE.Scene
  private secondaryScene: THREE.Scene
  private camera: THREE.Camera
  private secondaryInterval: number
  private lastSecondaryTime = 0

  private secondaryTarget?: THREE.WebGLRenderTarget
  private compositeScene?: THREE.Scene
  private compositeCam?: THREE.OrthographicCamera
  private compositeMat?: THREE.ShaderMaterial

  constructor(opts: FrameBudgetOptions) {
    this.renderer = opts.renderer
    this.primaryScene = opts.primaryScene
    this.secondaryScene = opts.secondaryScene
    this.camera = opts.camera
    this.secondaryInterval = 1000 / (opts.secondaryFps ?? 12)

    if (opts.useRenderTarget) {
      this.setupRenderTarget()
    }
  }

  private setupRenderTarget() {
    const size = new THREE.Vector2()
    this.renderer.getSize(size)

    this.secondaryTarget = new THREE.WebGLRenderTarget(size.x, size.y, {
      minFilter: THREE.LinearFilter,
      magFilter: THREE.LinearFilter,
      format: THREE.RGBAFormat,
    })

    this.compositeScene = new THREE.Scene()
    this.compositeCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1)

    this.compositeMat = new THREE.ShaderMaterial({
      uniforms: {
        uSecondary: { value: this.secondaryTarget.texture },
      },
      transparent: true,
      vertexShader: /* glsl */ `
        varying vec2 vUv;
        void main() {
          vUv = uv;
          gl_Position = vec4(position.xy, 0.0, 1.0);
        }
      `,
      fragmentShader: /* glsl */ `
        uniform sampler2D uSecondary;
        varying vec2 vUv;
        void main() {
          gl_FragColor = texture2D(uSecondary, vUv);
        }
      `,
    })

    const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.compositeMat)
    this.compositeScene.add(quad)
  }

  /**
   * Call this in your animation loop (requestAnimationFrame).
   * Renders primary every frame, secondary at the configured fps.
   */
  render(now: number) {
    // Primary: every frame, full quality
    this.renderer.render(this.primaryScene, this.camera)

    // Secondary: only at configured interval
    if (now - this.lastSecondaryTime >= this.secondaryInterval) {
      this.lastSecondaryTime = now

      if (this.secondaryTarget && this.compositeScene && this.compositeCam) {
        // Render secondary to its own target; composite in final pass
        this.renderer.setRenderTarget(this.secondaryTarget)
        this.renderer.clear()
        this.renderer.render(this.secondaryScene, this.camera)
        this.renderer.setRenderTarget(null)
      } else {
        // Render directly on top (works when secondary is last-in-depth)
        this.renderer.autoClear = false
        this.renderer.render(this.secondaryScene, this.camera)
        this.renderer.autoClear = true
      }
    }

    // If using render target, composite the cached secondary onto primary
    if (this.compositeScene && this.compositeCam) {
      this.renderer.autoClear = false
      this.renderer.render(this.compositeScene, this.compositeCam)
      this.renderer.autoClear = true
    }
  }

  /** Adjust secondary fps at runtime (e.g., lower when battery-saving) */
  setSecondaryFps(fps: number) {
    this.secondaryInterval = 1000 / Math.max(5, Math.min(60, fps))
  }

  dispose() {
    this.secondaryTarget?.dispose()
    this.compositeMat?.dispose()
  }
}

// ============================================================================
// USAGE EXAMPLE
// ============================================================================

/*
import * as THREE from 'three'

const renderer = new THREE.WebGLRenderer({ antialias: true })
renderer.setSize(window.innerWidth, window.innerHeight)
document.body.appendChild(renderer.domElement)

const camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 1000)

// PRIMARY scene: the hero — camera-aligned, gets user attention
const primaryScene = new THREE.Scene()
primaryScene.add(heroBlackHole)
primaryScene.add(heroLighting)

// SECONDARY scene: ambient — stars, dust, decorative particles
const secondaryScene = new THREE.Scene()
secondaryScene.add(starfield)
secondaryScene.add(dustParticles)
secondaryScene.add(ambientFog)

const budget = new TwoTrackFrameBudget({
  renderer,
  primaryScene,
  secondaryScene,
  camera,
  secondaryFps: 12,
  useRenderTarget: true,
})

function animate(now: number) {
  budget.render(now)
  requestAnimationFrame(animate)
}
requestAnimationFrame(animate)
*/

// ============================================================================
// WHAT GOES IN WHICH SCENE
// ============================================================================
//
// PRIMARY (native FPS):
//   - Hero object (the center of attention)
//   - Direct lighting of the hero
//   - Cursor-responsive effects
//   - Scroll-responsive effects that need smooth tracking
//   - Any element the user is clicking or hovering
//
// SECONDARY (12fps):
//   - Background starfields
//   - Ambient dust/snow/rain particles
//   - Fog volumes
//   - Non-interactive decorative geometry
//   - Instrument panel telemetry (updates visibly quantized anyway)
//   - Slow-moving background video planes
//
// NEVER in secondary:
//   - Anything the user's attention will track
//   - Text (legibility requires smoothness)
//   - Cursor-following elements
//   - Physics simulations the user can affect
