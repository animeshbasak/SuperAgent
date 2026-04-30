# Pipeline — CLI, Render Flags, Golden Tests

The hyperframes CLI is the single entrypoint. This document covers the
commands you will use, the render flag matrix, performance budgets, and a
golden-test pattern for catching regressions.

---

## Commands you will actually use

| Command                       | Use                                                  |
| ----------------------------- | ---------------------------------------------------- |
| `hyperframes doctor`          | Preflight diagnostic — Node, FFmpeg, FFprobe, Chrome |
| `hyperframes init <name>`     | Scaffold project from template                       |
| `hyperframes preview`         | Live preview studio at http://localhost:3002        |
| `hyperframes lint <file>`     | Static-check a composition                           |
| `hyperframes render`          | Render to MP4 / MOV / WebM                           |
| `hyperframes compositions`    | List compositions in current project                 |
| `hyperframes add <block>`     | Install a block from the catalog                     |
| `hyperframes benchmark <file>`| Render-perf benchmark                                |
| `hyperframes info`            | Print version + environment info                     |

Use `npx` prefix if not installed globally.

---

## Render flag matrix

```bash
npx hyperframes render --output out.mp4 [flags...]
```

| Flag                         | Values                | Default                  | Purpose                                                |
| ---------------------------- | --------------------- | ------------------------ | ------------------------------------------------------ |
| `--output`                   | path                  | `renders/<name>.mp4`     | Output file                                            |
| `--format`                   | `mp4` / `mov` / `webm`| `mp4`                    | Container. `mov`/`webm` for transparent video          |
| `--fps`                      | `24` / `30` / `60`    | `30`                     | Frames per second                                      |
| `--quality`                  | `draft` / `standard` / `high` | `standard`        | Encoding preset (CRF + x264 speed)                     |
| `--crf`                      | 0–51                  | (preset)                 | Override CRF directly. Lower = better. Mutex with `--video-bitrate` |
| `--video-bitrate`            | `10M`, `5000k`, etc.  | (preset)                 | Target bitrate. Mutex with `--crf`                     |
| `--workers`                  | `1`–`8` or `auto`     | `auto` (cores/2, max 4)  | Parallel Chrome render workers                         |
| `--max-concurrent-renders`   | `1`–`10`              | `2`                      | Server-level cap when multiple renders queue           |
| `--gpu`                      | flag                  | off                      | GPU encoder (NVENC, VideoToolbox, VAAPI)               |
| `--hdr`                      | flag                  | off                      | Detect HDR sources, output HDR10 (MP4 only)            |
| `--docker`                   | flag                  | off                      | Render in Docker for byte-exact reproducibility        |
| `--quiet`                    | flag                  | off                      | Suppress progress output                               |

### Quality presets

| Preset      | CRF | x264 preset | Wall clock per 30s | Use case                     |
| ----------- | --- | ----------- | ------------------ | ---------------------------- |
| `draft`     | 28  | ultrafast   | ~30s–1min          | Iteration                    |
| `standard`  | 18  | medium      | ~1–3min            | General delivery (default)   |
| `high`      | 15  | slow        | ~3–8min            | Final / archival             |

`standard` is visually lossless at 1080p for most content. Reach for `high`
only when archive/master is the deliverable.

---

## Choosing a mode

| Scenario                        | Command                                                            |
| ------------------------------- | ------------------------------------------------------------------ |
| Iterate quickly                 | `render --quality draft --output out.mp4`                          |
| Final web delivery              | `render --output final.mp4` (defaults to `standard`)               |
| CI / agent / shareable          | `render --docker --output final.mp4`                               |
| Master / archive                | `render --quality high --output master.mp4`                        |
| 9:16 social, smaller file       | `render --video-bitrate 5M --output reel.mp4`                      |
| Transparent overlay             | `render --format mov --output overlay.mov`                         |
| 4K final                        | (set composition root to 3840×2160) `render --quality high --workers 4` |
| HDR delivery                    | `render --hdr --quality high --output hdr.mp4`                     |
| Macbook fans loud, render slow  | `render --workers 1 --quality draft`                               |

---

## Performance budgets

Compute before launching to avoid surprise wall-clock burn:

```
estimated_seconds ≈ (composition_duration_s × fps) / frames_per_second_render_rate
```

Approximate `frames_per_second_render_rate` baselines on an M2 MacBook:

| Composition complexity              | draft   | standard | high   |
| ----------------------------------- | ------- | -------- | ------ |
| Plain text + images, no video       | ~120fps | ~60fps   | ~25fps |
| Single video clip + GSAP            | ~60fps  | ~30fps   | ~15fps |
| Multi-track w/ effects              | ~30fps  | ~15fps   | ~7fps  |
| 4K + multiple video tracks          | ~10fps  | ~5fps    | ~2fps  |

For a 30s composition at 30fps standard with a single video: 900 frames /
30 fps render rate ≈ 30 seconds wall clock. For high quality: ≈ 60 seconds.

Always set `timeout: 600000` (10 min) on Bash render calls for non-trivial
compositions. For quick iteration use `draft`.

---

## Workers — when to tune

Default is `cores / 2` capped at 4. Each worker spawns a separate Chrome
process consuming ~256 MB RAM.

Reduce to `--workers 1` when:
- Composition is shorter than 2 seconds (parallelism overhead exceeds gain).
- Machine has ≤ 8 GB RAM.
- Other heavy processes are running.

Increase to `--workers 4`–`8` when:
- Composition is 30+ seconds.
- Machine has 8+ cores and 16+ GB RAM.
- Dedicated CI runner.

Diminishing returns past 4 on most laptops. Stop adding workers when wall
clock stops dropping.

---

## Concurrent renders

`--max-concurrent-renders` (default 2) caps the producer server's
parallelism when multiple renders are queued (common with AI agents
firing renders in a loop). Each concurrent render still spawns its own
worker pool. To cap total Chrome processes: `concurrent × workers`.

---

## Lint

```bash
npx hyperframes lint ./index.html
npx hyperframes lint ./index.html --json     # machine-readable
npx hyperframes lint ./index.html --verbose  # include info-level findings
```

Catches:
- Missing `data-composition-id` on root.
- Missing `class="clip"` on timed elements.
- Two clips overlapping on the same track.
- Timeline registered with wrong key.
- Common GSAP anti-patterns.

Fix all errors before render. Warnings are usually safe.

---

## Determinism: golden test pattern

For any composition that ships to production, lock a golden frame to detect
regressions:

```bash
# 1. Render once, freeze a key frame at second 5
npx hyperframes render --docker --output golden.mp4
ffmpeg -y -i golden.mp4 -ss 5 -frames:v 1 golden-frame-5s.png

# 2. After any composition edit, re-render and diff
npx hyperframes render --docker --output current.mp4
ffmpeg -y -i current.mp4 -ss 5 -frames:v 1 current-frame-5s.png

# 3. Compare with ImageMagick (or any pixel differ)
compare -metric AE golden-frame-5s.png current-frame-5s.png diff.png
# AE = number of differing pixels. Should be 0 when content is unchanged.
```

Run in `--docker` mode for both renders — local renders vary across machines
because of font and Chrome version differences and will produce false
positives.

---

## ffprobe — verify output

After every render:

```bash
ffprobe -v error \
  -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,duration,codec_name \
  -of default=nw=1 out.mp4
```

Sample expected output for a 1920×1080@30fps 5s composition:

```
codec_name=h264
width=1920
height=1080
r_frame_rate=30/1
duration=5.000000
```

If `duration` is shorter than the GSAP timeline, the timeline did not extend
to cover the longest clip — see `animations.md` § "Timeline duration".

---

## Common pipeline failures

| Symptom                              | Likely cause                                        | Fix                                              |
| ------------------------------------ | --------------------------------------------------- | ------------------------------------------------ |
| `ffmpeg: command not found`          | FFmpeg not installed                                | `brew install ffmpeg` / `apt install ffmpeg`     |
| Render hangs at 0%                   | Missing asset, 404 in preview console               | Open preview, check console                      |
| Output shorter than expected         | GSAP timeline duration < longest clip               | `tl.set({}, {}, <duration>)`                     |
| Black trailing frames                | Last tween fades to opacity 0; timeline overruns    | Trim timeline OR remove fade                     |
| Audio out of sync                    | Script set `currentTime` on `<audio>`               | Remove all media playback in scripts             |
| Different output on each render      | Unseeded `Math.random()` or wall-clock dependency   | Seed RNG or pre-compute random values            |
| Fonts differ between dev and prod    | Local font fallback differs across machines         | Render in `--docker`                             |
| 100% CPU, fans loud                  | Too many workers                                    | `--workers 1` or `2`                             |
| MP4 has no transparency              | MP4 does not support alpha                          | Use `--format mov` or `--format webm`            |
| Render OOM                           | Too many concurrent workers × long composition      | Drop `--workers` or `--max-concurrent-renders`   |
