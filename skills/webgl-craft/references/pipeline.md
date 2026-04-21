# Pipeline and Performance — Assets, Compression, Rendering Budget

This file covers the production pipeline: asset compression, loading
strategy, bundle management, WebGPU/WebGL2 fallback, device-tier
adaptation, and the Lighthouse survival plan.

Performance is not optimization done at the end. It is architecture
decided at the beginning. A site designed without a performance budget
cannot be optimized into one later.

---

## THE PERFORMANCE BUDGET

Set these targets before any asset is created. Every budget is a lie
until it's enforced by tooling.

### Page-level budgets

- **First Contentful Paint (FCP):** < 1.5s on 4G.
- **Largest Contentful Paint (LCP):** < 2.5s on 4G.
- **Time to Interactive (TTI):** < 3.5s on 4G.
- **Total JavaScript bundle (gzipped):** < 500KB at first paint.
- **Total initial network payload:** < 1.5MB for the critical path.

### WebGL-specific budgets

- **Lighthouse Performance score (mobile):** > 75 for hybrid sites, > 60
  for persistent-world sites.
- **Frame rate (hero scene, mid-tier mobile):** > 45fps steady.
- **Shader compilation time (pre-warmed):** < 500ms total.
- **Cold cache scene load:** < 4s on 4G.

### Enforcement

- **Lighthouse CI in the deploy pipeline.** Fail the deploy if scores
  drop. Use `@lhci/cli` with a config that sets the threshold per metric.
- **Bundle size tracking.** Use `@next/bundle-analyzer` or Vite's
  `rollup-plugin-visualizer`. Review on every PR.
- **Performance budgets in Webpack/Vite.** Emit warnings at 80% of
  budget, errors at 100%.

---

## ASSET COMPRESSION PIPELINE

### 3D models — glTF with Draco + Meshopt

glTF 2.0 is the standard. Compress with Draco (mesh) and Meshopt (mesh
+ animation).

**Tooling:**

```bash
# Install gltf-transform
npm install -g @gltf-transform/cli

# Apply aggressive compression
gltf-transform optimize input.glb output.glb \
  --compress meshopt \
  --texture-compress webp
```

For Draco-specific compression:

```bash
gltf-transform draco input.glb output.glb --quantize-position 14
```

Expected size reduction: 8–12x for geometry-heavy models. A 20MB raw
glTF becomes 2MB with Draco + KTX2 textures.

### Textures — KTX2 (Basis Universal)

KTX2 is GPU-native compressed texture format. Unlike PNG/JPEG/WebP, the
GPU reads it directly without CPU-side decompression, reducing both
download size and decode time.

```bash
# Using toktx (from KTX-Software)
toktx --bcmp --clevel 5 --qlevel 255 output.ktx2 input.png
```

Or in gltf-transform:

```bash
gltf-transform ktx input.glb output.glb --filter lanczos3
```

Support check before enabling:

```javascript
ktx2Loader.detectSupport(renderer)
```

Expected size reduction: 4–6x over PNG, 2–3x over JPEG/WebP, with
better GPU performance.

### HDRI — RGBE-encoded .hdr, 1K-2K max

High-dynamic-range environment maps. Use:

- **1K (1024x512)** for indirect lighting and reflections on
  non-reflective surfaces.
- **2K (2048x1024)** for reflective hero surfaces (glass, chrome).
- **4K** is almost never justified. The bandwidth cost dwarfs the visual
  gain.

```javascript
import { RGBELoader } from 'three/addons/loaders/RGBELoader.js'

const loader = new RGBELoader()
loader.load('/env/studio_1k.hdr', (texture) => {
  texture.mapping = THREE.EquirectangularReflectionMapping
  scene.environment = texture
  scene.background = texture
})
```

Convert to pre-filtered cubemap at load time via `PMREMGenerator` for
efficient PBR reflections.

### Video — H.265/HEVC with H.264 fallback

Short loops for hero backgrounds or accent moments.

```html
<video autoplay muted loop playsinline>
  <source src="/video/hero.mp4" type='video/mp4; codecs="hvc1"'>
  <source src="/video/hero_h264.mp4" type="video/mp4">
</video>
```

Attributes that matter:
- `muted` — required for autoplay on iOS.
- `playsinline` — prevents full-screen takeover on iOS.
- `preload="metadata"` — don't preload full video; let the browser
  decide.
- `poster="..."` — a static image for first-frame display while video
  loads.

Use `ffmpeg` to compress:

```bash
# H.265 — modern browsers
ffmpeg -i input.mp4 -c:v libx265 -crf 28 -preset slow \
  -tag:v hvc1 -an hero.mp4

# H.264 — fallback
ffmpeg -i input.mp4 -c:v libx264 -crf 23 -preset slow \
  -an hero_h264.mp4
```

### Audio — AAC in M4A

```bash
ffmpeg -i input.wav -c:a aac -b:a 128k ambient.m4a
```

128kbps AAC is inaudible from source for ambient loops. For music with
full frequency range, 192kbps. Avoid MP3 (larger files, worse quality).

---

## LOADING STRATEGY

### Lazy-load the heavy stuff

The WebGL scene should NOT block the DOM hero. Load order:

1. **Critical CSS + minimal HTML** — renders within 1.5s.
2. **Fonts** — `font-display: swap` to render fallback immediately.
3. **Hero DOM and navigation** — interactive within 2s.
4. **WebGL bundle** — deferred import, loads while user reads hero.
5. **3D assets** — streamed in as scene initializes.
6. **Secondary sections** — lazy-loaded on scroll approach.

Next.js dynamic import:

```javascript
const WebGLHero = dynamic(() => import('@/components/WebGLHero'), {
  ssr: false,
  loading: () => <StaticHeroFallback />,
})
```

### Preload discipline

Use `<link rel="preload">` sparingly. Preload only assets on the critical
path.

```html
<link rel="preload" href="/fonts/display.woff2" as="font"
      type="font/woff2" crossorigin>
<link rel="preload" href="/env/hero_1k.hdr" as="fetch" crossorigin>
```

Do NOT preload:
- Videos (let the browser handle).
- Below-the-fold images.
- 3D models (they're loaded after the DOM hero).
- Multiple HDRIs.

### Progressive mesh loading

For heavy scenes, load a low-poly placeholder first, then swap to the
high-poly version.

```javascript
// Load low-poly
const lowPolyGltf = await loader.loadAsync('/models/hero_low.glb')
scene.add(lowPolyGltf.scene)

// Load high-poly in background, swap when ready
loader.load('/models/hero_high.glb', (gltf) => {
  scene.remove(lowPolyGltf.scene)
  scene.add(gltf.scene)
})
```

### Intersection-based section loading

Load WebGL sections only when they approach the viewport.

```javascript
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      loadSection(entry.target.id)
      observer.unobserve(entry.target)
    }
  })
}, { rootMargin: '100% 0px' })  // start loading when 1 viewport away

document.querySelectorAll('[data-webgl-section]').forEach(el => {
  observer.observe(el)
})
```

---

## DEVICE-TIER ADAPTATION

Not every device deserves the same experience. Detect tier and adapt.

### Tier detection

```javascript
function detectDeviceTier() {
  const memory = navigator.deviceMemory || 4       // GB RAM
  const cores = navigator.hardwareConcurrency || 4  // CPU cores
  const connection = navigator.connection?.effectiveType  // "4g", "3g", ...
  const pixelRatio = Math.min(window.devicePixelRatio, 2)

  if (memory < 4 || cores < 4 || connection === '3g') {
    return 'low'
  }
  if (memory < 8 || cores < 6) {
    return 'mid'
  }
  return 'high'
}

const tier = detectDeviceTier()
```

### Per-tier adaptations

```javascript
const settings = {
  low: {
    pixelRatio: 1,
    particleCount: 1000,
    shadowsEnabled: false,
    postProcessing: ['filmGrain'],  // only cheap effects
    targetFps: 30,
  },
  mid: {
    pixelRatio: 1.5,
    particleCount: 10000,
    shadowsEnabled: true,
    postProcessing: ['bloom', 'filmGrain'],
    targetFps: 60,
  },
  high: {
    pixelRatio: 2,
    particleCount: 50000,
    shadowsEnabled: true,
    postProcessing: ['bloom', 'chromaticAberration', 'filmGrain',
                     'colorGrading'],
    targetFps: 60,
  },
}

const config = settings[tier]
renderer.setPixelRatio(config.pixelRatio)
```

### Adaptive rendering quality

Measure actual frame rate and adapt mid-session:

```javascript
let frameCount = 0
let lastTime = performance.now()
let avgFps = 60

function measureFps() {
  frameCount++
  const now = performance.now()
  if (now - lastTime >= 1000) {
    avgFps = frameCount
    frameCount = 0
    lastTime = now

    // Downgrade if sustained low FPS
    if (avgFps < config.targetFps * 0.7) {
      renderer.setPixelRatio(Math.max(1, renderer.getPixelRatio() - 0.25))
    }
  }
  requestAnimationFrame(measureFps)
}
measureFps()
```

---

## WEBGPU AND TSL

WebGPU is the next-generation graphics API. Advantages over WebGL2:
compute shaders, better performance, more predictable behavior, native
support for modern GPU features.

Browser support (as of 2026): Chrome, Edge, Opera, Safari (stable),
Firefox (flag). Mobile support: Chrome Android, iOS Safari 17+.

### The adoption strategy: write TSL, render on both

Write all NEW shaders in Three.js Shading Language (TSL). TSL compiles
to both WebGL2 (GLSL) and WebGPU (WGSL) from one source. This makes the
WebGL2 → WebGPU transition a renderer swap, not a rewrite.

```javascript
import * as THREE from 'three/webgpu'

const renderer = new THREE.WebGPURenderer({ antialias: true })
await renderer.init()  // async; WebGPU needs adapter setup

// TSL shader code works on both APIs
import { uv, sin, time, vec2 } from 'three/tsl'
```

### Fallback handling

Detect WebGPU support before attempting to use it:

```javascript
async function createRenderer(canvas) {
  if (navigator.gpu) {
    try {
      const renderer = new THREE.WebGPURenderer({ canvas, antialias: true })
      await renderer.init()
      return { renderer, api: 'webgpu' }
    } catch (e) {
      console.warn('WebGPU init failed, falling back to WebGL2', e)
    }
  }
  // WebGL2 fallback
  return {
    renderer: new THREE.WebGLRenderer({ canvas, antialias: true }),
    api: 'webgl2',
  }
}
```

### When NOT to lead with WebGPU

- Sites targeting users on older browsers (enterprise, education).
- Sites where the 5–10% of users without WebGPU would see a degraded
  experience.
- Projects with tight deadlines and no time to handle fallback edge
  cases.

The Shopify Editions Renaissance uses WebGPU. Most portfolios in 2026
should NOT. Ship WebGL2 with TSL shaders; upgrade to WebGPU in v2.

---

## LIGHTHOUSE SURVIVAL

Creative sites often score in the 40–70 range on Lighthouse mobile
Performance. This is survivable for consumer/brand work but unacceptable
for portfolio sites reviewed by hiring managers.

### The non-negotiables for 75+ Performance score

1. **First paint under 1.5s.** DOM hero renders before WebGL.
2. **No render-blocking JavaScript.** All non-critical JS loads
   deferred.
3. **Image optimization.** WebP/AVIF, responsive sizes, lazy loading.
4. **Font loading strategy.** `font-display: swap`, subset to
   characters used.
5. **Third-party scripts audited.** Google Analytics, Hotjar, etc. add
   1–3 seconds; use Partytown or cut them.
6. **Text compression.** Brotli (or gzip fallback) on HTML/CSS/JS.
7. **HTTP/2 or HTTP/3.** Modern hosts provide by default.
8. **Cache-Control headers.** Immutable for hashed assets
   (`max-age=31536000, immutable`).

### Next.js specifics

- Use `next/image` for all images; it handles formats, sizes, lazy
  loading.
- Use `next/font` for font hosting and preloading.
- Enable Brotli in `next.config.js`:

```javascript
module.exports = {
  compress: true,
  images: {
    formats: ['image/avif', 'image/webp'],
  },
}
```

- Mark heavy components as `ssr: false` dynamic imports to keep them
  out of the critical bundle.

### The 90+ path

A 90+ Lighthouse score on a WebGL-heavy site is achievable but requires
discipline:

- Canvas renders placeholder until main thread is idle.
- All fonts self-hosted.
- HDRI loaded after first interaction.
- Third-party scripts: zero or proxied via Partytown.
- Images served from edge CDN with aggressive caching.

---

## THE TWO-TRACK FRAME BUDGET (IMPLEMENTATION)

From `motion-scroll.md` — the Prometheus Fuels technique of running
primary elements at native FPS and secondary elements at 12–15 fps.

Full implementation:

```javascript
class FrameBudget {
  constructor() {
    this.lastPrimary = 0
    this.lastSecondary = 0
    this.primaryInterval = 0          // every frame
    this.secondaryInterval = 1000 / 12  // 12fps
  }

  shouldRenderPrimary(now) {
    this.lastPrimary = now
    return true
  }

  shouldRenderSecondary(now) {
    if (now - this.lastSecondary >= this.secondaryInterval) {
      this.lastSecondary = now
      return true
    }
    return false
  }
}

const budget = new FrameBudget()

function renderLoop(now) {
  if (budget.shouldRenderPrimary(now)) {
    renderer.render(primaryScene, camera)
  }
  if (budget.shouldRenderSecondary(now)) {
    renderer.render(secondaryScene, camera)
  }
  requestAnimationFrame(renderLoop)
}
requestAnimationFrame(renderLoop)
```

See `recipes/two-track-frame-budget.ts` for the full version with
scene layering and composition.

---

## SHADER PRE-WARMING

First-interaction jank is almost always shader compilation. Pre-warm
during load.

```javascript
// Force compilation by rendering once off-screen
function prewarmShaders(renderer, scene, camera) {
  const offscreenTarget = new THREE.WebGLRenderTarget(1, 1)
  renderer.setRenderTarget(offscreenTarget)
  renderer.render(scene, camera)
  renderer.setRenderTarget(null)
  offscreenTarget.dispose()
}

// Call after scene setup, before user interaction
prewarmShaders(renderer, scene, camera)
```

For parallel compilation where supported:

```javascript
const gl = renderer.getContext()
const ext = gl.getExtension('KHR_parallel_shader_compile')
if (ext) {
  // Shaders compile in parallel; poll COMPLETION_STATUS_KHR to know when
  // each program is ready
}
```

---

## THE PIPELINE CHECKPOINT

Before shipping:

1. **Performance budget:** FCP, LCP, TTI, bundle size — all measured
   and enforced in CI.
2. **Asset compression:** glTF + Draco/Meshopt, textures in KTX2, HDRI
   at 1K/2K, video H.265/H.264, audio AAC.
3. **Loading strategy:** DOM hero first, WebGL deferred, 3D assets
   streamed, sections lazy-loaded.
4. **Device-tier adaptation:** detection + per-tier settings + adaptive
   fallback.
5. **WebGPU posture:** write TSL, ship WebGL2, upgrade later.
6. **Lighthouse target:** 75+ for hybrid, 60+ for persistent-world, 90+
   for DOM-first.
7. **Two-track frame budget:** primary/secondary identified and gated.
8. **Shader pre-warming:** applied to every material.
9. **Third-party audit:** analytics, tracking, chat widgets all
   justified or cut.

Meet these and the site will perform at the level the craft demands.
