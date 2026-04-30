# Architecture — Composition / Scene / Block Taxonomy

A hyperframes project is a tree of HTML compositions. The CLI walks the tree,
seeks each composition's GSAP timeline frame-by-frame, captures pixels with
Chrome's `BeginFrame` API, and pipes them into FFmpeg. Understanding the tree
is the foundation for everything else.

---

## The three layers

```
Project          ← directory; meta.json + index.html + assets + compositions/
  └── Composition   ← <div data-composition-id> with width/height + GSAP timeline
        ├── Clip        ← <video> | <img> | <audio> on a track
        ├── Clip
        └── Composition  ← nested via data-composition-src OR inline
```

| Layer       | What it is                          | Owns                                         |
| ----------- | ----------------------------------- | -------------------------------------------- |
| Project     | Directory with `meta.json`          | Asset paths, root composition, agent skills  |
| Composition | One HTML doc with a GSAP timeline   | Width, height, duration, all child clips     |
| Scene       | Logical chunk inside a composition  | Convention — usually a track or sub-comp     |
| Block       | Pre-built composition from catalog  | A reusable unit you `add` and embed          |
| Clip        | One element on the timeline         | `data-start`, `data-duration`, track index   |

---

## Project layout

```
my-video/
├── meta.json                  # name, id, created date
├── index.html                 # root composition — entrypoint
├── compositions/
│   ├── intro.html             # nested composition
│   ├── lower-third.html
│   └── outro.html
└── assets/
    ├── hero.mp4
    ├── logo.png
    └── soundtrack.mp3
```

Scaffold with `npx hyperframes init <name> --non-interactive --example blank`.

---

## The composition root

Every composition needs a root element with these three attributes:

```html
<div id="root"
     data-composition-id="root"
     data-width="1920"
     data-height="1080">
  ...
</div>
```

| Attribute              | Required | Purpose                                            |
| ---------------------- | -------- | -------------------------------------------------- |
| `data-composition-id`  | Yes      | Unique key. Must match `window.__timelines[<id>]`. |
| `data-width`           | Yes      | Output canvas width in px.                         |
| `data-height`          | Yes      | Output canvas height in px.                        |
| `data-start`           | No       | Start time within parent (only for nested).        |
| `data-track-index`     | No       | Z-order within parent (only for nested).           |

Common aspect ratios:

| Ratio  | Width | Height | Use case                       |
| ------ | ----- | ------ | ------------------------------ |
| 16:9   | 1920  | 1080   | YouTube, web, default          |
| 9:16   | 1080  | 1920   | TikTok, Reels, Shorts          |
| 1:1    | 1080  | 1080   | Instagram feed                 |
| 4:5    | 1080  | 1350   | Instagram portrait             |
| 16:9   | 3840  | 2160   | 4K delivery                    |

---

## Clips — the timed elements

A clip is any HTML element with timing attributes and `class="clip"`:

```html
<h1 id="title" class="clip"
    data-start="0"
    data-duration="5"
    data-track-index="0">
  Hello
</h1>

<video id="hero" class="clip"
       data-start="2"
       data-duration="8"
       data-track-index="1"
       src="assets/hero.mp4"></video>

<audio id="music" class="clip"
       data-start="0"
       data-track-index="2"
       data-volume="0.4"
       src="assets/soundtrack.mp3"></audio>
```

| Attribute            | Type            | Notes                                               |
| -------------------- | --------------- | --------------------------------------------------- |
| `data-start`         | seconds OR id   | Absolute or `intro + 2` for relative timing         |
| `data-duration`      | seconds         | Required for `<img>`. Optional for `<video>/<audio>` (defaults to source). |
| `data-track-index`   | integer         | Higher number = in front. Same track = no overlap.  |
| `data-media-start`   | seconds         | Trim point — where the source media starts playing  |
| `data-volume`        | 0–1             | For `<video>` and `<audio>`                         |
| `data-has-audio`     | boolean         | Hint that a `<video>` has an audio track            |

The `class="clip"` is REQUIRED for any timed element — without it the runtime
cannot manage visibility lifecycle. Static decoration (a background gradient
that lasts the whole video) does not need it.

---

## Tracks — the z-axis

`data-track-index` is both a stacking order and a non-overlap constraint:

```
Track 2  [─── music (full duration) ───]
Track 1            [── hero video ──]
Track 0  [── title 5s ──][── caption 5s ──]   (cannot overlap on same track)
```

- Higher index = rendered on top.
- Two clips with the same track index cannot occupy the same time range.
- Use a separate track per simultaneous element (background, foreground,
  overlay, audio).

---

## Relative timing

Instead of absolute seconds, a clip can reference another clip's id:

```html
<video id="intro" data-start="0" data-duration="10" data-track-index="0" src="..."></video>
<video id="main"  data-start="intro" data-duration="20" data-track-index="0" src="..."></video>
<video id="outro" data-start="main + 1" data-duration="5" data-track-index="0" src="..."></video>
```

`main` starts at second 10 (when intro ends). `outro` starts at second 31 (1
second after main ends). Edit intro's duration and everything downstream
shifts automatically.

Forms:
- `<id>` — start when that clip ends.
- `<id> + N` — start N seconds after.
- `<id> - N` — start N seconds before (overlap; requires different track).

Constraints: same-composition only, no cycles, the referenced clip must have
a known duration.

---

## Nested compositions

Two ways to nest:

### External file (preferred for reuse)

`index.html`:
```html
<div id="el-5"
     data-composition-id="intro-anim"
     data-composition-src="compositions/intro-anim.html"
     data-start="0"
     data-track-index="3"></div>
```

`compositions/intro-anim.html`:
```html
<template id="intro-anim-template">
  <div data-composition-id="intro-anim" data-width="1920" data-height="1080">
    <div class="title">Welcome!</div>
    <style>
      [data-composition-id="intro-anim"] .title { font-size: 72px; color: white; }
    </style>
    <script>
      const tl = gsap.timeline({ paused: true });
      tl.from(".title", { opacity: 0, y: -50, duration: 1 });
      window.__timelines["intro-anim"] = tl;
    </script>
  </div>
</template>
```

External composition files MUST wrap their content in a `<template>` tag.

### Inline (one-offs)

```html
<div id="root" data-composition-id="root" data-width="1920" data-height="1080">
  <div id="el-5"
       data-composition-id="intro-anim"
       data-start="0" data-track-index="3"
       data-width="1920" data-height="1080">
    <div class="title">Welcome!</div>
  </div>
  <script>
    const introTl = gsap.timeline({ paused: true });
    introTl.from(".title", { opacity: 0, y: -50, duration: 1 });
    window.__timelines["intro-anim"] = introTl;
  </script>
</div>
```

Inline compositions do NOT use `<template>`.

### Variables for nested compositions

Pass per-instance values with `data-variable-values`:

```html
<div data-composition-id="card"
     data-composition-src="compositions/card.html"
     data-variable-values='{"title":"Hello","color":"#ff4d4f"}'
     data-start="0" data-track-index="1"></div>
```

Inside `compositions/card.html` the script reads them off the host element and
applies them manually. There is no automatic binding.

---

## Two layers — declarative vs. scripted

Every composition has two layers, and they have non-overlapping responsibilities:

| Declarative (HTML + `data-*`)                | Scripted (GSAP, canvas, SVG)              |
| -------------------------------------------- | ----------------------------------------- |
| What plays, when, on which track             | Visual animation of properties            |
| Media playback (play/pause/seek)             | Property tweens (opacity, x, y, scale...) |
| Clip visibility (show/hide)                  | Timeline choreography                     |
| Composition nesting                          | Effects, transitions, distortion          |

If a script tries to control playback or visibility, the framework will fight
it and the render will desync. Read `animations.md` § "What NOT to do" for
the specific anti-patterns.

---

## Where to read next

- `animations.md` — GSAP rules, deterministic seeking, easing.
- `catalog.md` — the 39 ready-to-install blocks.
- `pipeline.md` — CLI flags, render modes, golden tests.
