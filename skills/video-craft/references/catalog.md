# Catalog — Hyperframes Block Library

Hyperframes ships 39 pre-built compositions (blocks) you can drop into any
project. Each block is a fully-realized composition with its own timeline.
Install with `npx hyperframes add <block-name>`, then embed via
`data-composition-src`.

---

## Install pattern

```bash
# From inside your project root
npx hyperframes add data-chart
```

This copies `data-chart.html` into `compositions/`. Then in `index.html`:

```html
<div data-composition-id="data-chart"
     data-composition-src="compositions/data-chart.html"
     data-start="0"
     data-duration="15"
     data-track-index="1"
     data-width="1920"
     data-height="1080"></div>
```

Most blocks expose customization via `data-variable-values` or by editing
the copied file directly. Treat the installed block as a starting scaffold.

---

## Catalog by category

### Data & content

| Block            | Duration | What it does                                              |
| ---------------- | -------- | --------------------------------------------------------- |
| `data-chart`     | 15s      | Animated bar+line chart, staggered reveal, value labels   |
| `flowchart`      | varies   | Connected nodes with sequential reveal                    |

### Social media mockups

Drop-in approximations of platform UI for content-style videos.

| Block               | Use                                    |
| ------------------- | -------------------------------------- |
| `instagram-follow`  | IG follow CTA card                     |
| `tiktok-follow`     | TikTok follow CTA card                 |
| `x-post`            | X / Twitter post mockup                |
| `reddit-post`       | Reddit thread mockup                   |
| `spotify-card`      | Now-playing card                       |
| `app-showcase`      | Generic mobile-app feature showcase    |
| `macos-notification`| macOS-style toast notification         |
| `yt-lower-third`    | YouTube-style lower third              |

### Brand / sting

| Block          | Use                                         |
| -------------- | ------------------------------------------- |
| `logo-outro`   | Animated logo end-card                      |
| `ui-3d-reveal` | UI panel revealing in 3D space              |
| `cinematic-zoom`| Slow push-in on hero subject               |

### Effects (full-screen overlays)

| Block                  | Feel                                         |
| ---------------------- | -------------------------------------------- |
| `glitch`               | Digital glitch / VHS damage                  |
| `light-leak`           | Analog film light leak                       |
| `ripple-waves`         | Concentric ripple displacement               |
| `thermal-distortion`   | Heat-haze warp                               |
| `swirl-vortex`         | Spiral suction                               |
| `chromatic-radial-split`| RGB split radial                            |
| `domain-warp-dissolve` | Procedural noise dissolve                    |
| `gravitational-lens`   | Black-hole spacetime warp                    |
| `sdf-iris`             | Iris-shaped reveal/conceal                   |
| `ridged-burn`          | Paper-edge burn                              |
| `flash-through-white`  | Hard-cut white flash                         |

### Transitions (between scenes)

These are timed cut-points. Place them at the seam between two clips or
two compositions.

| Block                       | Style                                  |
| --------------------------- | -------------------------------------- |
| `transitions-3d`            | 3D card flip / rotation                |
| `transitions-blur`          | Soft blur into next scene              |
| `transitions-cover`         | Solid color wipe                       |
| `transitions-destruction`   | Shatter / break apart                  |
| `transitions-dissolve`      | Crossfade variants                     |
| `transitions-distortion`    | Warp / stretch                         |
| `transitions-grid`          | Grid-tile flip                         |
| `transitions-light`         | Light burst / streak                   |
| `transitions-mechanical`    | Iris, shutter, slat                    |
| `transitions-other`         | Misc: page-curl, peel, crumple         |
| `transitions-push`          | Directional push                       |
| `transitions-radial`        | Circular wipe                          |
| `transitions-scale`         | Scale up/down through                  |
| `whip-pan`                  | Hard whip with motion blur             |
| `cross-warp-morph`          | Cross-dissolve with shape morph        |

---

## Picking a transition

| Brief                              | Reach for                              |
| ---------------------------------- | -------------------------------------- |
| "Snappy, energetic, social"        | `whip-pan`, `transitions-push`         |
| "Cinematic, premium"               | `transitions-blur`, `cinematic-zoom`   |
| "Tech / data product"              | `transitions-grid`, `glitch`           |
| "Editorial, calm"                  | `transitions-dissolve`                 |
| "Brand reveal"                     | `transitions-light`, `flash-through-white` |
| "Sci-fi / experimental"            | `gravitational-lens`, `domain-warp-dissolve` |

Default to `transitions-blur` or `transitions-dissolve` for most narrative
work. Reserve the loud effects (`gravitational-lens`, `glitch`) for one
moment per video — overuse kills perceived production value.

---

## Composing your own block

A custom block is just a composition file in `compositions/` with a
`<template>` wrapper. The catalog blocks are reference implementations —
once you've installed two or three, copy one and edit. Pattern:

```html
<!-- compositions/my-block.html -->
<template id="my-block-template">
  <div data-composition-id="my-block" data-width="1920" data-height="1080">
    <!-- your clips, styles, scripts -->
    <script>
      const tl = gsap.timeline({ paused: true });
      // ... your tweens with absolute positions ...
      window.__timelines["my-block"] = tl;
    </script>
  </div>
</template>
```

Then embed in `index.html` exactly like any catalog block.

---

## Notes on customization

- Most blocks use `data-variable-values` for hot-paths (titles, colors,
  values). Check the top of the installed `.html` for the variable schema.
- For deeper changes, edit the copied composition directly. There is no
  "magic" — it is plain HTML/CSS/JS.
- After editing, re-run `npx hyperframes lint` on the file before render.
