# Shaders and 3D — WebGL Scene Design

This file covers the WebGL scene itself: materials, post-processing, lighting,
text rendering, particle systems, and the specific signature shader effects
that show up repeatedly in premium creative web.

Read `signature-moves.md` and `architecture.md` before this file. Shader work
without those settled leads to beautiful demos that don't cohere into sites.

---

## MATERIALS — THE DEFAULTS

Three.js materials in order of GPU cost:

- **MeshBasicMaterial** — no lighting, fastest. Use for emissive overlays,
  skyboxes, and any surface where lighting would fight the art direction.
- **MeshLambertMaterial / MeshPhongMaterial** — basic lighting. Rarely the
  right choice in 2026; the aesthetic is dated.
- **MeshStandardMaterial** — PBR (physically based rendering), the right
  default for most geometry. Accepts roughness, metalness, normal maps, and
  environment maps.
- **MeshPhysicalMaterial** — PBR with clearcoat, iridescence, transmission,
  and sheen. Use for glass, coated plastics, lacquered surfaces, iridescent
  materials. Adds ~25% GPU cost over Standard.
- **ShaderMaterial / RawShaderMaterial** — custom. Use when the effect cannot
  be expressed as a PBR parameter combination. Most signature moves require
  this.

The mistake pattern: reaching for `ShaderMaterial` when `MeshPhysicalMaterial`
with carefully chosen parameters would suffice. A clearcoat helmet looks like
a helmet; a shader-only helmet rarely does, because PBR is decades of lighting
research distilled into parameters. Custom shaders should EXTEND physical
rendering, not replace it. Use `onBeforeCompile` to inject shader modifications
into PBR materials while keeping the lighting pipeline intact.

---

## POST-PROCESSING — THE FOUR THAT MATTER

Four post effects appear repeatedly in the reference set. Every other effect
is optional.

**Bloom.** Makes bright pixels bleed into neighbors. The difference between
"a scene with lights" and "a scene with lights that feel cinematic." Use the
`UnrealBloomPass` or `pmndrs/postprocessing`'s `EffectComposer`. Threshold
0.85–0.95, strength 0.4–0.8, radius 0.5–0.8 are reasonable starting points.
Tune by screenshotting a bright frame and checking that only intentionally
bright elements bloom.

**Chromatic Aberration.** RGB channels offset slightly on sampling, producing
a cinematic lens-imperfection look. Use 0.001–0.003 offset (small; easy to
overdo). Radial aberration (offset increases with distance from screen
center) reads as a real lens; uniform aberration reads as a glitch effect.

**Film Grain / Noise.** A screen-space noise overlay at low intensity (0.03–
0.06) unifies the image and masks banding in gradients. This is the single
cheapest "makes it feel premium" effect. Works with any rendering style.

**Color Grading.** A LUT (lookup table) or a manual tonemapping step that
enforces a consistent color palette. `ACESFilmicToneMapping` is the Three.js
default; consider `NeutralToneMapping` for scenes with bright highlights where
ACES crushes detail. For brand-specific grading, author a `.cube` LUT in
DaVinci Resolve or Photoshop and apply via a post pass.

**Effects to use sparingly or never:**
- Depth of Field: expensive, often looks wrong on web screens, rarely adds.
- Motion Blur: almost always wrong on interactive content; reduces legibility.
- SSAO: expensive; cheaper ambient occlusion baked into textures usually
  looks better.
- Screen-space reflections: expensive and noisy; environment maps suffice.
- God rays / volumetric light: occasionally justified in narrative scenes;
  usually decoration.

---

## LIGHTING — MINIMAL IS USUALLY RIGHT

Four-light setups are overkill for most creative web scenes. Use:

- **One directional light** as the key, casting shadows if the scene is
  shadow-relevant.
- **One ambient light or hemisphere light** for fill.
- **An environment map (HDRI)** for PBR reflections. This replaces the need
  for rim lights and bounce lights in most cases.

HDRIs from Poly Haven (polyhaven.com) are free, CC0, and cover most needs.
Use a small (1K-2K) HDRI for indirect lighting and environment reflections.
A 4K HDRI is overkill and adds loading time.

For hero products or objects requiring dramatic lighting, a three-point
setup (key + rim + fill) baked into an HDRI is cleaner than three real lights.

---

## SDF AND MSDF TEXT

Text rendered in the WebGL canvas must use SDF (signed distance field) or
MSDF (multi-channel SDF) atlases. Standard Three.js text geometry
(`TextGeometry`) is for 3D extruded type only; it does not scale and looks
bad at small sizes.

**Use `troika-three-text`.** It's the production-ready path. Accepts a web
font URL, generates an SDF atlas at runtime, renders crisply at any size,
supports variable fonts, and integrates with custom shaders for distortion.

The three moves SDF text enables:

1. **Scramble effects.** Glyph swapping is an atlas lookup change, not a
   reflow. Useful for loading states, hover states, and transition moments.
2. **Shader distortion.** The text can pass through the same lensing,
   refraction, or distortion shader as the rest of the scene, staying
   visually coherent with 3D elements.
3. **Curved or projected text.** SDF text can wrap around geometry, follow
   paths, or sit on 3D surfaces.

**Do not render all UI text as SDF.** Headings, navigation, body copy, and
CTAs belong in the DOM. Only text that participates in the 3D scene — hero
type that distorts with lensing, text wrapping around objects, kinetic
typography moments — justifies SDF rendering.

---

## PARTICLE SYSTEMS

Particle systems fall into three tiers by technique.

**Tier 1: Instanced meshes (`InstancedMesh`).** Up to ~10,000 particles with
individual transforms. Good for debris, falling leaves, orbital bodies. Each
particle is a full mesh with materials and lighting. Update transforms in
`requestAnimationFrame` via `setMatrixAt`.

**Tier 2: Points with custom shader (`Points` + `ShaderMaterial`).** Up to
~100,000 particles. Particles are screen-space points with vertex and
fragment shaders. Cheap, but limited to point rendering (no rotation, no
mesh shape).

**Tier 3: GPGPU (ping-pong FBOs).** Up to ~1,000,000 particles. Particle
state (position, velocity, target) lives in float textures. Each frame, a
render pass reads the current state texture and writes to a scratch texture;
buffers swap. Particles render by reading the state texture from a vertex
shader.

GPGPU is the correct tier when:
- Particles respond to simulation forces (flow fields, attractors,
  repulsors, fluid fields).
- Particles morph between target positions (the Igloo footer pattern).
- Particle count exceeds what CPU can update at 60fps.

Three.js's `GPUComputationRenderer` is the standard helper. For more
control, write the ping-pong system directly: two `WebGLRenderTarget`s with
float textures, a quad mesh with the simulation shader, swap references
each frame.

---

## THE SIGNATURE SHADER PATTERNS

These are the specific shader techniques that produce signature-level effects
in the reference set. Each has a recipe in `recipes/`.

### Gravitational Lensing (Schwarzschild approximation)

A black sphere surrounded by a lensed starfield. Distant light bends around
the sphere's edge, producing the Einstein ring. Used for black-hole heroes
and as a "mass" visualization.

Implementation sketch: a raymarched shader on a full-screen quad samples a
cube environment map. For each pixel, compute the ray from camera through
the pixel. Near the black hole, bend the ray according to a Schwarzschild
approximation (`ray.deflection = 4 * M / (r * c^2)` simplified to a
parameterized curve). Sample the environment map with the deflected ray.
Render the event horizon as a black disk when the ray intersects the
sphere.

A full Kerr (rotating black hole) implementation is ~5x more expensive and
not worth the cost for a hero shader. Schwarzschild is indistinguishable at
web-viewer intuition level.

See `recipes/lensing-shader.ts`.

### Fluid Distortion (cursor mask, reveal effects)

A liquid-blob cursor that drags through screen-space and distorts whatever
is underneath it. The Lando Norris signature.

Implementation sketch: a 2D fluid FBO at reduced resolution (e.g., 256x256
or 512x512). Each frame, inject velocity at the cursor position (with
radius and strength based on cursor speed), advect and diffuse the velocity
field, and output a displacement texture. In the final pass, sample the
scene texture with UV offset by the displacement.

References: `post-fluid-distortion` in OGL examples, Pavel Dobryakov's
WebGL Fluid Simulation (CC-licensed, widely studied). For a cursor-mask
effect rather than whole-screen distortion, the fluid field masks an
alternate rendering — the user sees the "base" scene everywhere except
where the blob is, where the "revealed" layer shows through.

See `recipes/fluid-cursor-mask.ts`.

### Volumetric Clouds (fragment-shader raymarching)

Clouds, fog, smoke, or dust that have depth rather than being flat
billboards. Used for atmosphere, cinematic reveals, and the "renaissance"
metaphor in Shopify's page.

Implementation sketch: on a full-screen quad or a box mesh, raymarch from
camera through a 3D noise function. At each step, accumulate density and
lighting. Output the composited color and alpha. Exit when alpha saturates
or the ray exits a bounding volume.

Cost: high — raymarching is the most expensive technique per pixel. Mitigate
with reduced-resolution render targets (render at 0.5x, upscale with
temporal anti-aliasing) and with low step counts (16–32 steps).

### Photograph-Projected Geometry (2.5D)

Real photography textured onto simple 3D planes, camera-panned through a
depth-ordered scene. The Prometheus Fuels signature.

Implementation sketch: for each "layer" of the scene, author a plane mesh
at a specific depth. Texture the plane with a photograph (potentially with
an alpha mask cutting out foreground elements). Position the planes in
depth. The camera moves through the scene; depth-sorted planes parallax
naturally.

Enhancements: add a subtle screen-space noise shader to break up the
photographic flatness. Add atmospheric fog via depth-based color blending.
Add chromatic aberration post to unify the composite.

This technique has a fixed GPU cost floor because each plane is a textured
quad; scaling to many layers is cheap.

### Procedural Geometry in Containers

Each item (project, product, chapter) is encased in a procedurally
generated geometric shell. The Igloo Inc ice-block signature.

Implementation sketch: author a container SDF (a rough shape the geometry
should fit inside). Run a generation algorithm (diffusion-limited
aggregation, voxel-based growth, Lindenmayer system) that populates
structure inside the SDF. Mesh the result via marching cubes or as
instanced geometry. Apply a refraction material with front-pass/back-pass
rendering, Fresnel rim, and 3D noise for surface detail.

The generation can run offline (baked to glTF) or at runtime (in a worker).
Offline is faster to load; runtime is more flexible.

### Screen-Space Noise on Gradients

A film-grain-style noise overlay applied specifically to gradient fills,
giving them a handcrafted paper-and-ink feel rather than smooth-mathematical
feel. The Prometheus Fuels secondary technique.

Implementation sketch: in the gradient's fragment shader, add a 2D noise
sample (`hash21`, `simplex2D`, or sampled blue-noise texture) multiplied by
a small amplitude (0.02–0.06). For animated grain, offset the sample
coordinate by time.

This is the cheapest "handcrafted" effect available and the single most
underused technique in creative web. It turns flat CSS-style gradients into
material surfaces.

---

## TSL — THREE.JS SHADING LANGUAGE

For any NEW shader work in 2026, write in TSL, not GLSL. TSL compiles to
both WebGL2 (GLSL) and WebGPU (WGSL) from a single JavaScript source. This
eliminates the future rewrite when WebGPU adoption reaches the point where
the WebGL2 fallback can be dropped.

TSL syntax example (simple distortion):

```javascript
import { uv, sin, time, vec2, texture } from 'three/tsl'

const distortedUv = uv().add(vec2(
  sin(time.mul(2).add(uv().y.mul(10))).mul(0.02),
  0
))
const finalColor = texture(myTexture, distortedUv)
```

The same source runs on WebGL2 and WebGPU. Use `WebGPURenderer` with
automatic WebGL2 fallback:

```javascript
import * as THREE from 'three/webgpu'

const renderer = new THREE.WebGPURenderer({ antialias: true })
await renderer.init()  // async; WebGPU needs adapter initialization
```

Exception: when porting an existing public-domain GLSL shader (from
Shadertoy, glslSandbox, or published shader repositories), porting to TSL
is often more work than wrapping the GLSL. Wrap the GLSL in a
`RawShaderMaterial` and leave it as WebGL-only.

---

## ASSET FORMATS

**Models:** glTF 2.0 with Draco (mesh) and Meshopt (mesh + animation)
compression. Draco alone reduces mesh size by ~10x; Meshopt adds animation
compression. Use both. `gltfpack` (Meshopt) and `gltf-transform` (either)
are the standard CLI tools.

**Textures:** KTX2 (Basis Universal) compression. Reduces texture size by
~6x and is GPU-native (no CPU decompression overhead). Use `toktx` or
`basisu` CLI.

**Environment maps (HDRI):** RGBE-encoded `.hdr` at 1K or 2K resolution.
Convert to pre-filtered cube maps at load time via `PMREMGenerator`.

**Video:** H.265/HEVC for modern browsers with H.264 fallback. Vertical
video for mobile hero if mobile is a priority. Keep looping videos under
10s to control bundle size.

**Audio:** AAC in M4A container. Keep ambient loops under 30s; longer
loops can use crossfade seams to avoid repetition detection.

---

## DRACO AND KTX2 IN PRODUCTION

Configure Three.js loaders correctly:

```javascript
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js'
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js'
import { KTX2Loader } from 'three/addons/loaders/KTX2Loader.js'
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js'

const dracoLoader = new DRACOLoader()
dracoLoader.setDecoderPath('/draco/')  // host decoder locally, not jsdelivr

const ktx2Loader = new KTX2Loader()
ktx2Loader.setTranscoderPath('/basis/')
ktx2Loader.detectSupport(renderer)

const gltfLoader = new GLTFLoader()
gltfLoader.setDRACOLoader(dracoLoader)
gltfLoader.setKTX2Loader(ktx2Loader)
gltfLoader.setMeshoptDecoder(MeshoptDecoder)
```

Self-host the Draco and Basis decoders. Loading them from CDN (jsdelivr,
unpkg) adds a third-party network dependency that can break in production.

---

## SHADER PRE-WARMING

First-interaction jank is almost always shader compilation. The fix is to
compile shaders before the user interacts.

**Approach 1 — Compile on load.** After the scene is set up but before the
user can interact, render the scene once off-screen (or at opacity 0) with
all materials visible. This forces the WebGL context to compile all
shaders.

**Approach 2 — Compile during intro.** If there's a loading or intro
animation, render invisible versions of late-appearing materials during
that time. Igloo Inc does this — the intro sequence pre-compiles shaders
that won't be used until several scroll positions in.

**Approach 3 — `KHR_parallel_shader_compile`.** A WebGL extension that
compiles shaders in parallel. Supported in all modern browsers. Use
`renderer.getContext().getExtension('KHR_parallel_shader_compile')` at
init, then check `COMPLETION_STATUS_KHR` per program to know when compile
finishes.

Apply pre-warming to EVERY shader that might cause a visible stall when
first shown. A scene with 20 materials and no pre-warming will have 20
moments of jank. Pre-warming moves all of them to load time, where they
are tolerable.

---

## THE SHADER CHECKPOINT

Before writing shader code, answer:

1. **Does this need to be a custom shader, or can `MeshPhysicalMaterial`
   with parameters do it?** Most scenes want the latter.
2. **If custom, am I writing TSL or GLSL?** Default to TSL for new work.
3. **What post-processing is justified?** Bloom, chromatic aberration,
   film grain, color grading — any others need a reason.
4. **What is the lighting setup?** One directional + HDRI usually suffices.
5. **Which text is in DOM vs. SDF?** Only text that must participate in
   the 3D scene belongs in SDF.
6. **Which particle tier applies?** Instanced / Points / GPGPU — based on
   count and simulation needs.
7. **Is the signature shader identified?** If yes, link to its recipe in
   `recipes/`. If no, pause shader work and revisit `signature-moves.md`.
8. **Is shader pre-warming planned?** Every new material added increases
   the jank surface area; plan pre-warming accordingly.

With these answered, proceed to implementation via recipes.
