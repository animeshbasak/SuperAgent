---
name: video-craft
---
# video-craft

> 

# Video Craft — HTML Compositions to MP4 via hyperframes

This skill teaches the agent to author hyperframes compositions (HTML + GSAP +
`data-*` timing attributes) and render them deterministically to MP4. The render
pipeline is seek-driven and frame-accurate — preview ≠ render performance, but
preview === render visual output. Treat the composition as the single source of
truth; never try to play media or hide clips in scripts.

---

## When to use

- User asks for a video, MP4, or rendered motion file (any aspect ratio).
- User wants a product ad, explainer, lower-third overlay, animated chart, logo
  sting, social cut, kinetic typography piece, or data-viz video.
- User has assets (images, video, audio, copy, data) and the deliverable is
  "ship me a video file".
- User mentions hyperframes, GSAP timeline, deterministic render, frame
  capture, or composition-to-MP4 pipeline.

**Do NOT use for:** live web pages with scroll animation (use `webgl-craft`),
realtime UI prototypes, or interactive motion. video-craft renders are
non-interactive video files.

---

## Procedure

### 1. Preflight (REQUIRED — never skip)

Both checks must pass before any author/render step. If either fails, stop and
direct the user to install before proceeding.

```bash
# Check hyperframes CLI
hyperframes --version || npx hyperframes --version

# Check FFmpeg (hard dependency — no MP4 without it)
ffmpeg -version | head -1
```

If `hyperframes` is missing:
```bash
npm i -g hyperframes
# or run the bundled installer:
bash bundles/hyperframes/install.sh
```

If `ffmpeg` is missing:
- macOS: `brew install ffmpeg`
- Ubuntu/Debian: `sudo apt install -y ffmpeg`
- Windows: `winget install ffmpeg`

Then run the deeper diagnostic:
```bash
npx hyperframes doctor
```
Expected: green checks for Node 22+, FFmpeg, FFprobe, Chrome.

### 2. Pick the entrypoint

Two paths:

**A. Recipe-first (recommended).** If the user's intent matches a recipe in
`recipes/`, copy it as the starting composition and edit. Recipes:

| Recipe                       | Use when                                                |
| ---------------------------- | ------------------------------------------------------- |
| `hello-world.html`           | Smallest possible composition; verifying the pipeline.  |
| `product-ad-30s.html`        | 30s product video — hero shot, three feature beats, CTA.|
| `data-driven-chart.html`     | Animated bar chart with staggered reveal + value labels.|
| `lower-third-overlay.html`   | Title bar / name plate that slides in over footage.     |

**B. From scratch.** Use `npx hyperframes init <name> --non-interactive --example blank`
and edit `index.html`. Read `references/architecture.md` first to understand the
composition / scene / block taxonomy.

### 3. Author the composition

Read these references before writing HTML:

1. `references/architecture.md` — composition root, nested compositions, tracks,
   z-ordering, `data-*` attributes.
2. `references/animations.md` — GSAP timeline rules (`{ paused: true }`,
   `window.__timelines`, position parameter, deterministic seeking).
3. `references/catalog.md` — the 39 hyperframes block types you can install
   with `npx hyperframes add <block>`.

The three non-negotiable rules:

- **Root** — every composition's outermost element has `data-composition-id`,
  `data-width`, `data-height`.
- **Clips** — every timed element has `class="clip"`, `data-start`,
  `data-duration`, `data-track-index`. Clips on the same track cannot overlap.
- **Timeline** — exactly one `gsap.timeline({ paused: true })` per composition,
  registered as `window.__timelines[<composition-id>] = tl`. The framework
  drives playback; never call `tl.play()`, `media.play()`, or seek manually.

### 4. Lint

```bash
npx hyperframes lint ./index.html
```

Fix all errors. Warnings are usually safe to ship but worth reading.

### 5. Preview before render (REQUIRED)

```bash
npx hyperframes preview
# Opens http://localhost:3002
```

Scrub the timeline. Verify:
- All clips appear at the right time.
- GSAP animations look correct at every keyframe.
- Audio is present where expected.
- No clip is cut off because the timeline is shorter than the longest clip
  (see `references/animations.md` § "Extending timeline duration").

Only proceed to render after preview looks correct. Renders take 30s–10min;
you do not want to discover a typo at frame 4500.

### 6. Render

For iteration:
```bash
npx hyperframes render --output out.mp4 --quality draft
```

For final delivery:
```bash
npx hyperframes render --output final.mp4 --quality high
```

For deterministic / CI / shareable output:
```bash
npx hyperframes render --docker --output final.mp4
```

See `references/pipeline.md` for the full flag matrix (CRF, bitrate, workers,
GPU encoding, HDR, format selection).

**Timeout policy.** Renders are bounded by composition duration × frame cost.
Estimate before launching:
- 5s composition, 30fps, standard quality: ~10–30s wall clock.
- 30s composition, 30fps, high quality: 1–4 minutes.
- 60s+ composition or 60fps or 4K: up to 10 minutes.

When invoking via Bash, set `timeout: 600000` (10 min) for any non-trivial
render. For quick iteration use `--quality draft` to keep wall clock under 60s.

### 7. Verify output

```bash
ffprobe -v error -show_entries stream=width,height,r_frame_rate,duration \
  -of default=nw=1 out.mp4
```

Confirm width/height match the composition root, fps matches `--fps`, and
duration matches the GSAP timeline duration. If duration is short, the
timeline did not extend to cover the longest clip — see
`references/animations.md` § "Extending timeline duration".

---

## Verification

Before claiming the task complete:

- [ ] `hyperframes --version` and `ffmpeg -version` both succeeded in preflight.
- [ ] `npx hyperframes lint` reported zero errors.
- [ ] Preview was opened and visually confirmed at least once.
- [ ] Render command exited 0; output file exists at the requested path.
- [ ] `ffprobe` confirms width × height × fps × duration are as intended.
- [ ] If the user requested a specific aspect ratio (9:16, 1:1, 16:9), the
      composition root's `data-width` and `data-height` reflect it.
- [ ] No script in the composition calls `.play()`, `.pause()`,
      `currentTime =`, or animates `width`/`height`/`top`/`left` directly on
      a `<video>` element. (These are the most common bugs — see
      `references/animations.md` § "What NOT to do".)

---

## Edge cases

- **Render hangs at 0%.** Almost always a missing asset or unresolved
  `data-composition-src`. Check preview console for 404s.
- **Final video is shorter than expected.** GSAP timeline ends before the
  longest media clip. Add `tl.set({}, {}, <duration-in-seconds>)` to extend.
- **Black frames at the end.** Last GSAP tween fades something to opacity 0
  but the timeline keeps going — either trim the timeline or remove the fade.
- **Audio out of sync.** You animated `currentTime` in a script. Remove it;
  the framework owns media playback.
- **Fonts look different in render vs. preview.** Use `--docker` for
  reproducible font rendering across machines.
- **Video element stops painting after animation.** You animated
  `width`/`height` directly on a `<video>`. Wrap in a `<div>` and animate
  the wrapper.
- **`Math.random()` produces different output each render.** It does — that
  breaks determinism. Use a seeded RNG or pre-compute random values.
- **Render uses 100% CPU and laptop fans spin up.** Lower `--workers` to 1
  or 2. Default is half your cores capped at 4; on a hot machine drop it.
- **Need transparent background.** Use `--format mov` or `--format webm`;
  MP4 does not support alpha.

When in doubt, run `npx hyperframes doctor` and `npx hyperframes lint`
before debugging anything else.
