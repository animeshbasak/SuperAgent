# Signature Moves — The Framework

The single most transferable lesson from every site in the reference set:
**signature interactions beat signature stacks.** This file gives the framework for
identifying, designing, and protecting a site's one signature move.

Read this before any architectural or shader decision. The signature move is the
lens through which every other choice is evaluated.

---

## WHAT A SIGNATURE MOVE IS

A signature move is ONE interaction or visual gesture that:

1. **Literalizes the site's subject.** It translates the thing the site is about
   into a WebGL or motion interaction. Lando Norris's helmet livery becomes the
   cursor mask. Igloo's ice-company name becomes the project container geometry.
   Shopify's Renaissance metaphor becomes the bloom-and-cloud shader stack.
   Prometheus's "fuel from thin air" becomes the photograph-projected 2.5D world.

2. **Is the thing users describe to other users.** When someone shares the site,
   they don't say "it has nice animations" — they say "the cursor is this liquid
   thing that reveals his helmet." If you can't write a one-sentence description
   that would make someone else want to see the site, there is no signature move.

3. **Would make the site unrecognizable if removed.** Strip the ice-block
   containers from Igloo and you have a competent WebGL portfolio. Strip the
   liquid cursor from Lando and you have a well-made Webflow site. The signature
   move is the load-bearing element.

4. **Is executed with disproportionate technical depth relative to the rest.**
   The signature move gets 40% of the build time. Everything else gets the
   remaining 60%. Sites fail when build time is distributed evenly across effects.

---

## THE IDENTIFICATION PROCESS

Before any build, run this sequence. If the answers don't produce a clear
signature move candidate, pause the build and keep working the brief.

### Step 1: What is the site's literal subject?

Not "a portfolio" or "a product site." The specific noun. A Formula 1 driver. An
ice company. A synthetic fuel company. A commerce platform's AI-era release. A
computational biologist. A perfume house. A typeface.

### Step 2: What is the subject's physical or conceptual artifact?

What does the subject look like, touch, smell, sound like? A helmet. A block of
ice. A Mustang on Route 66. A Renaissance painting. A microscope slide. A bottle
and its pour. A character in a specific weight.

### Step 3: Can that artifact become an interaction?

This is the creative leap. The test: can the artifact be touched with the cursor,
arranged by scroll, revealed by hover, distorted by audio, assembled by click? If
yes, that is the signature move candidate.

### Step 4: Does the interaction require WebGL, or would DOM suffice?

If DOM suffices, use DOM. WebGL is only justified when the interaction requires
GPU-accelerated math (distortion, 3D transforms, shader-driven reveals, particle
systems with more than a few hundred elements, real-time lighting).

### Step 5: What is the fallback?

Every signature move needs a degraded version for: mobile, low-power devices, and
users with `prefers-reduced-motion`. If there is no acceptable fallback, the move
is too fragile.

---

## EXAMPLES OF SIGNATURE MOVES WORKED FROM SCRATCH

These are illustrative walkthroughs of how the identification process applies to
different brief types.

### Brief: AI engineer's portfolio

- **Subject:** an engineer who builds AI systems.
- **Artifact:** the AI itself. Conversation. A terminal. A thinking process.
- **Interaction:** an ambient AI that lives in the site and responds to context,
  with scroll position feeding the AI's attention. Scrolling Mission Log triggers
  passive commentary. Typing to the AI pauses scroll and expands the terminal to
  full-screen interrogation mode.
- **WebGL needed?** The terminal itself is DOM. The ambient presence — a subtle
  visualizer reacting to the AI's reasoning state — is WebGL (a particle field
  or a shader-driven sphere whose parameters bind to token generation rate).
- **Fallback:** the terminal works without the WebGL visualizer; reduced motion
  users get a static terminal with no ambient visuals.

### Brief: perfume house launch

- **Subject:** a perfume.
- **Artifact:** the bottle, the liquid, the pour.
- **Interaction:** scroll is the pour. The bottle tips as the user scrolls, and
  a volumetric liquid simulation pours from bottle to glass, with the viscosity
  and color changing per fragrance scrolled to.
- **WebGL needed?** Yes — fluid simulation requires GPU compute.
- **Fallback:** a 6-frame video loop of a prerecorded pour per fragrance.

### Brief: independent type foundry

- **Subject:** a typeface family.
- **Artifact:** the letterforms themselves.
- **Interaction:** each letterform is a 3D extrusion the user can orbit, with
  weight and slant controlled by mouse Y and mouse X. Hovering a letter in body
  text on the marketing page triggers a 3D reveal of that glyph in full-screen.
- **WebGL needed?** Yes — variable font animation in 3D space isn't DOM-achievable.
- **Fallback:** hovering a letter triggers an inline animated SVG of the same
  glyph rotating in 2D.

### Brief: climate-tech company (satellites, emissions monitoring)

- **Subject:** a satellite network monitoring emissions.
- **Artifact:** the satellite, the Earth, the plume, the data.
- **Interaction:** the site IS a satellite's perspective. The hero is a live
  view from a satellite orbiting a procedurally textured Earth, and scroll
  triggers "pass events" where the camera swings low over a city and the shader
  overlays the measured emission plume in chromatic false-color.
- **WebGL needed?** Yes — orbital math and shader overlays.
- **Fallback:** a prerecorded orbital flythrough video with scroll-scrubbed
  playback.

---

## WHAT SIGNATURE MOVES ARE NOT

Eliminate these from candidate lists. They are common and they do not perform as
signature moves in the reference set:

- **A custom cursor that is merely a dot with lerp.** Every site has this.
  Table stakes, not signature.
- **A hero headline that reveals character by character.** Also table stakes.
- **A grain/noise overlay.** A production texture, not a signature.
- **A color-inverting cursor mix-blend-mode circle.** 2019's signature move, now
  generic.
- **Horizontal scroll for its own sake.** A layout choice, not a signature.
  Horizontal scroll is a signature only when the horizontal axis means something
  (a timeline, a filmstrip, a journey).
- **Dark mode with neon accents.** Aesthetic direction, not a signature move.
- **An "enter site" intro animation.** Almost always a waste of the user's time
  and a negative signal in modern review.

If the proposed signature move is on this list, it is not a signature move.
Keep working.

---

## THE 40/60 BUILD-TIME RULE

Budget 40% of total build time to the signature move, 60% to everything else.
This feels wrong the first time. It produces the right result.

Concretely, for a 3-week portfolio build:

- Week 1 prototypes the signature move in isolation, to the point where it
  feels right standalone. No site, no sections, no navigation — just the move.
  If it doesn't feel right after a week, the move is wrong. Go back to
  identification.
- Weeks 2–3 build the rest of the site around the proven move.

Sites that budget evenly (20% hero, 20% projects, 20% about, 20% contact, 20%
polish) consistently produce "good-looking portfolios" that don't stand out.
Sites that budget 40% to ONE gesture consistently produce award-winning work.

---

## PROTECTING THE MOVE DURING BUILD

Once the signature move is identified, these rules protect it from the
incremental drift that kills most signature moves by launch:

**Never add a second signature-level interaction.** If a new idea emerges that
feels signature-tier, it is a candidate for the NEXT project, not this one.
Two signature moves on one site dilute both. Sites that try to have three or
four end up with none.

**Never reduce the signature move's build budget to add secondary features.**
If the schedule tightens, cut features from the 60% side. The signature move's
budget is non-negotiable because it is load-bearing.

**Test the signature move on a stranger.** Before launch, show the site to
someone who doesn't know the brief. Ask them to describe what they saw.
If they describe the signature move unprompted, it works. If they describe
general aesthetic qualities ("looks cool," "nice animations"), the move is
not landing and needs more iteration, not more features.

**Never let the signature move break on mobile in a way that removes it.**
Mobile fallback can be simpler, but it must be recognizably the same gesture.
If mobile gets "a static image instead of the fluid cursor," mobile users see
a different site and judge it accordingly.

---

## THE SIGNATURE-MOVE CHECKPOINT

Before any code is written on a new project, complete this checkpoint in writing.
If any answer is "I'm not sure," the build is not ready to start.

1. **In one sentence, what is this site's signature move?**
   "On [specific site], the [specific interaction] translates [subject's artifact]
   into a [WebGL/motion] gesture such that users describe it as [one memorable
   phrase]."

2. **What is it literalizing?** The subject, in one noun.

3. **What is the WebGL / math core of the move?** One sentence describing the
   technique (fluid distortion FBO, raymarched SDF, GPGPU particle morph,
   photograph-projected plane, MSDF text distortion, etc.).

4. **What is the mobile fallback?** One sentence.

5. **What is the `prefers-reduced-motion` fallback?** One sentence.

6. **What is the keyboard-accessible equivalent?** One sentence.

7. **What is the graceful degradation if WebGL fails entirely?** One sentence.

8. **What is the 60% of the site that this move does NOT need to cover?** A list.
   These are the areas where you will deliberately be conventional, so the move
   can be disproportionate.

If all seven are filled in with specifics, proceed. If any is vague, the move
is not yet identified.

---

## CLOSING: WHY THIS MATTERS

Premium creative web is not won by technique accumulation. It is won by a
single, well-defended gesture that makes the site worth remembering. Every
reference file in this skill is in service of executing that gesture well.

If this skill is ever reduced to a single sentence, it is this: **identify the
gesture, protect its build budget, let the rest of the site be a frame around
it.**
