/**
 * FLUID CURSOR MASK — liquid-blob that reveals an alternate render layer
 *
 * Source lineage:
 *   OGL post-fluid-distortion example pattern; Pavel Dobryakov's WebGL Fluid
 *   Simulation approach simplified for cursor-mask use; related technique
 *   to Lando Norris's helmet-reveal cursor.
 *
 * When to use:
 *   - Sites where the cursor IS the signature move (see signature-moves.md).
 *   - Reveal interactions: the cursor uncovers a hidden layer (different
 *     render of the scene, a photo reveal, a text layer).
 *   - Brand translations: the fluid shape is a physical artifact from the
 *     brand (helmet livery, logo, product silhouette).
 *
 * When NOT to use:
 *   - As a generic premium-cursor effect. Overused and it reads as
 *     "2024 agency cursor" rather than signature.
 *   - On content-heavy sites where the cursor distortion interferes with
 *     reading text.
 *
 * Edit points:
 *   - CURSOR_SIZE: radius of the cursor's influence, in normalized UVs.
 *   - VISCOSITY: how quickly the fluid field settles (0=immediate, 1=sluggish).
 *   - VELOCITY_SCALE: how strongly cursor movement injects velocity.
 *   - FLUID_RESOLUTION: simulation resolution (256 mobile, 512 desktop).
 *   - baseTexture / revealTexture: the two scene layers to composite.
 *
 * Known trade-offs:
 *   - ~2ms GPU budget per frame for the simulation at 512x512.
 *   - Does NOT work on touch devices (no hover state). Add touch interaction
 *     detection and fall back to a tap-reveal variant.
 *   - Accessibility: the cursor-revealed content must also be reachable via
 *     keyboard/screen reader (e.g., a static toggle button that swaps layers).
 */

import * as THREE from 'three'

export interface FluidCursorOptions {
  renderer: THREE.WebGLRenderer
  baseTexture: THREE.Texture
  revealTexture: THREE.Texture
  resolution?: 256 | 512 | 1024
  cursorSize?: number
  viscosity?: number
  velocityScale?: number
}

export class FluidCursorMask {
  private renderer: THREE.WebGLRenderer
  private resolution: number
  private velocityFboA: THREE.WebGLRenderTarget
  private velocityFboB: THREE.WebGLRenderTarget
  private pressureFbo: THREE.WebGLRenderTarget
  private composeScene: THREE.Scene
  private composeCam: THREE.OrthographicCamera
  private composeMat: THREE.ShaderMaterial
  private advectMat: THREE.ShaderMaterial
  private injectMat: THREE.ShaderMaterial
  private quad: THREE.Mesh
  private mouse = new THREE.Vector2(0.5, 0.5)
  private lastMouse = new THREE.Vector2(0.5, 0.5)
  private mouseVelocity = new THREE.Vector2(0, 0)

  constructor(opts: FluidCursorOptions) {
    this.renderer = opts.renderer
    this.resolution = opts.resolution ?? 512

    const rtOpts = {
      type: THREE.HalfFloatType,
      format: THREE.RGBAFormat,
      wrapS: THREE.ClampToEdgeWrapping,
      wrapT: THREE.ClampToEdgeWrapping,
      minFilter: THREE.LinearFilter,
      magFilter: THREE.LinearFilter,
    }

    this.velocityFboA = new THREE.WebGLRenderTarget(this.resolution, this.resolution, rtOpts)
    this.velocityFboB = new THREE.WebGLRenderTarget(this.resolution, this.resolution, rtOpts)
    this.pressureFbo = new THREE.WebGLRenderTarget(this.resolution, this.resolution, rtOpts)

    // Advection shader — moves velocity field along itself (fluid flow)
    this.advectMat = new THREE.ShaderMaterial({
      uniforms: {
        uVelocity: { value: null },
        uDt: { value: 0.016 },
        uDissipation: { value: opts.viscosity ?? 0.98 },
      },
      vertexShader: QUAD_VERT,
      fragmentShader: ADVECT_FRAG,
    })

    // Injection shader — adds velocity at cursor position
    this.injectMat = new THREE.ShaderMaterial({
      uniforms: {
        uVelocity: { value: null },
        uMouse: { value: this.mouse },
        uMouseVel: { value: this.mouseVelocity },
        uRadius: { value: opts.cursorSize ?? 0.08 },
        uStrength: { value: opts.velocityScale ?? 1.5 },
      },
      vertexShader: QUAD_VERT,
      fragmentShader: INJECT_FRAG,
    })

    // Composition shader — samples base and reveal textures using velocity
    // field as a displacement map
    this.composeMat = new THREE.ShaderMaterial({
      uniforms: {
        uBase: { value: opts.baseTexture },
        uReveal: { value: opts.revealTexture },
        uVelocity: { value: null },
      },
      vertexShader: QUAD_VERT,
      fragmentShader: COMPOSE_FRAG,
    })

    this.composeScene = new THREE.Scene()
    this.composeCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1)
    this.quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.composeMat)
    this.composeScene.add(this.quad)

    window.addEventListener('mousemove', this.onMouseMove)
  }

  private onMouseMove = (e: MouseEvent) => {
    const x = e.clientX / window.innerWidth
    const y = 1 - e.clientY / window.innerHeight
    this.lastMouse.copy(this.mouse)
    this.mouse.set(x, y)
    this.mouseVelocity
      .copy(this.mouse)
      .sub(this.lastMouse)
      .multiplyScalar(10) // scale for stronger effect
  }

  step(dt: number) {
    // 1. Advect current velocity field
    this.advectMat.uniforms.uVelocity.value = this.velocityFboA.texture
    this.advectMat.uniforms.uDt.value = dt
    this.quad.material = this.advectMat
    this.renderer.setRenderTarget(this.velocityFboB)
    this.renderer.render(this.composeScene, this.composeCam)

    // 2. Inject cursor velocity into the advected field
    this.injectMat.uniforms.uVelocity.value = this.velocityFboB.texture
    this.injectMat.uniforms.uMouse.value = this.mouse
    this.injectMat.uniforms.uMouseVel.value = this.mouseVelocity
    this.quad.material = this.injectMat
    this.renderer.setRenderTarget(this.velocityFboA)
    this.renderer.render(this.composeScene, this.composeCam)

    // Decay cursor velocity each frame
    this.mouseVelocity.multiplyScalar(0.9)

    this.renderer.setRenderTarget(null)
  }

  /** Call this to render the composited result to screen */
  render() {
    this.composeMat.uniforms.uVelocity.value = this.velocityFboA.texture
    this.quad.material = this.composeMat
    this.renderer.setRenderTarget(null)
    this.renderer.render(this.composeScene, this.composeCam)
  }

  dispose() {
    window.removeEventListener('mousemove', this.onMouseMove)
    this.velocityFboA.dispose()
    this.velocityFboB.dispose()
    this.pressureFbo.dispose()
  }
}

// ============================================================================
// SHADERS
// ============================================================================

const QUAD_VERT = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = vec4(position.xy, 0.0, 1.0);
  }
`

const ADVECT_FRAG = /* glsl */ `
  uniform sampler2D uVelocity;
  uniform float uDt;
  uniform float uDissipation;
  varying vec2 vUv;

  void main() {
    vec2 vel = texture2D(uVelocity, vUv).xy;
    vec2 prevUv = vUv - vel * uDt;
    vec2 advected = texture2D(uVelocity, prevUv).xy;
    gl_FragColor = vec4(advected * uDissipation, 0.0, 1.0);
  }
`

const INJECT_FRAG = /* glsl */ `
  uniform sampler2D uVelocity;
  uniform vec2 uMouse;
  uniform vec2 uMouseVel;
  uniform float uRadius;
  uniform float uStrength;
  varying vec2 vUv;

  void main() {
    vec2 existing = texture2D(uVelocity, vUv).xy;
    float dist = distance(vUv, uMouse);
    float influence = smoothstep(uRadius, 0.0, dist);
    vec2 injected = uMouseVel * uStrength * influence;
    gl_FragColor = vec4(existing + injected, 0.0, 1.0);
  }
`

const COMPOSE_FRAG = /* glsl */ `
  uniform sampler2D uBase;
  uniform sampler2D uReveal;
  uniform sampler2D uVelocity;
  varying vec2 vUv;

  void main() {
    vec2 vel = texture2D(uVelocity, vUv).xy;
    float mask = smoothstep(0.0, 0.3, length(vel));

    // Sample both layers; displace the reveal by the velocity field
    vec3 baseColor = texture2D(uBase, vUv).rgb;
    vec3 revealColor = texture2D(uReveal, vUv + vel * 0.05).rgb;

    vec3 finalColor = mix(baseColor, revealColor, mask);
    gl_FragColor = vec4(finalColor, 1.0);
  }
`

// ============================================================================
// USAGE EXAMPLE
// ============================================================================

/*
import { FluidCursorMask } from './fluid-cursor-mask'

// Prepare the two scene layers as textures (render each to a WebGLRenderTarget)
const baseLayer = renderSceneToTexture(sceneA, camera)
const revealLayer = renderSceneToTexture(sceneB, camera)

const fluid = new FluidCursorMask({
  renderer,
  baseTexture: baseLayer,
  revealTexture: revealLayer,
  cursorSize: 0.1,
  velocityScale: 2.0,
})

// In your animation loop:
function animate() {
  fluid.step(1/60)
  fluid.render()
  requestAnimationFrame(animate)
}
*/

// ============================================================================
// TOUCH FALLBACK
// ============================================================================
//
// On touch devices, the cursor-follow pattern doesn't apply. Two options:
//
// 1. Skip entirely on touch; show only the base layer.
//      if (matchMedia('(hover: none)').matches) return
//
// 2. Tap-reveal variant: a tap at position X injects a strong velocity pulse
//    that decays over ~1 second, producing a one-shot reveal ripple at the
//    tap point.
