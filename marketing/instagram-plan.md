# SuperAgent — Instagram Marketing Plan

> Goal: turn SuperAgent's own capabilities into a content engine. The product
> renders the videos, drafts the captions, designs the carousels, and tells you
> what worked. You press post.

---

## North-star metric

**One paying user per week from Instagram.** Vanity metrics (followers, likes)
are downstream. Track: `/token-stats` badges shared by other repos and
`bash install-universal.sh` traffic from `instagram.com` referrers.

---

## Audience

You are not selling to the general public. You are selling to:

1. **Senior devs paying $20-200/mo for AI tooling** who already burned themselves
   on rate limits or surprise bills.
2. **Indie hackers / solo founders** stretching every dollar, multiple AI
   subscriptions stacked.
3. **Build-in-public engineers** with their own audiences who repost what
   makes them look smart.

Every post should resonate with at least one of these. If a post doesn't, kill
it before scheduling.

---

## Six content pillars

| # | Pillar | Format | Frequency | Lead skill |
|---|---|---|---|---|
| 1 | **Receipts** — `/token-stats` screenshots, savings badges, one-shot rate | static or carousel | 1×/week | `token-stats` |
| 2 | **Demos** — 7-30 sec product clips showing one skill saving the day | reel | 1-2×/week | `video-craft` |
| 3 | **Comparisons** — vs Cursor / Copilot / Cline / Aider / Continue (one feature at a time) | carousel | 1×/2 weeks | `superagent-compile` (the table) |
| 4 | **Pain memes** — "POV: it's 4pm and your model says wait 5 hours" | reel or static | 1×/week | none — humor |
| 5 | **Educational** — "how multi-agent routing works in 60 seconds" | carousel | 1×/2 weeks | `graphify` (diagrams) |
| 6 | **Behind-the-scenes** — building SuperAgent itself, with this very tool | reel + caption | 1×/2 weeks | `mempalace` (story memory) |

Cadence target: **3-5 posts/week**. Quality dominates frequency. Better to skip
a slot than post mediocre.

---

## Format playbook

### Reels (most reach)
- **Length:** 7-15 sec for receipts/memes, 25-40 sec for demos. Avoid 60+.
- **Hook in frame 1:** text overlay with the strongest claim. No logo intros.
- **Captions on-screen** — Instagram's auto-captions are fine; render burned-in
  via `video-craft` for accessibility + scrollability.
- **Audio:** trending audio for memes; product sound or narration for demos.
- **CTA in last 2 sec:** "link in bio" + on-screen "github.com/animeshbasak/SuperAgent".

### Carousels (highest save rate)
- **6-10 slides.** Each slide self-contained — viewer can leave any time.
- **Slide 1 = thumbnail** with the headline claim. Slide 10 = CTA.
- **One idea per slide.** Don't pack two.
- **Design system:** mono terminal aesthetic for technical posts, brutalist
  text-only slides for opinion posts. Use `ui-ux-pro-max` to lock the system
  before posting #1.

### Static
- Use sparingly. Only for ultra-high-density images: the comparison table from
  the README, a `/token-stats` screenshot, an architecture diagram from
  `graphify`. Static rarely outperforms carousel even at the same content.

---

## Hook formulas (steal these)

- **Pain hook:** "I was paying $200/month for AI tools and *still* hitting rate
  limits. Then I built this:"
- **Receipt hook:** "Saved 229k tokens in one session. Here's the receipt:"
- **Counterintuitive hook:** "I made my AI 75% slower on purpose. Bills dropped
  90%."
- **Comparison hook:** "I compared 8 AI coding tools so you don't have to."
- **Demo hook:** "Watch SuperAgent stop my AI from running `rm -rf` on my repo:"
- **Story hook:** "It's 4pm. Production is broken. My AI says: 'please wait 5
  hours.' Here's what I did:"
- **Numbered hook:** "3 things every Cursor user is paying for and shouldn't:"

Save winning hooks to `mempalace search "viral hook"` so you don't lose them
across sessions. Distill weekly into `~/.superagent/agent-memory/marketing/MEMORY.md`.

---

## Hashtag strategy

Never use the full 30. Pick 8-12 that match the post. Rotate across 3 tiers:

- **Core (always):** `#ai` `#aitools` `#devtools` `#buildinpublic` `#opensource`
- **Topical (5-7):** `#claudecode` `#cursor` `#copilot` `#aiagents` `#llm`
  `#promptengineering` `#cliengineering`
- **Niche (1-2):** `#anthropic` `#openai` `#vibecoding` `#agenticAI`

If a post is a meme, drop the technical niche tags — broad audience.

---

## 4-week launch calendar (template)

| Week | Mon (Receipt) | Wed (Demo) | Fri (Education) | Sun (Pain/BTS) |
|---|---|---|---|---|
| 1 | "I just saved 229k tokens. Receipt:" | "Watch SuperAgent block `rm -rf`" | "What is multi-agent routing? (carousel)" | "POV: it's 4pm and your AI is rate-limited" |
| 2 | "0 rate-limits in 12 sessions. Here's how" | "Same prompt, 7 IDEs, one source of truth" | "3-tier routing in 60 seconds" | "Building SuperAgent with SuperAgent" |
| 3 | "$3.44 saved this week. Receipt:" | "Free local LLM canary preflight" | "Carousel: Cursor vs SuperAgent" | "Why I left $200/mo on the table" |
| 4 | "Bench passed 26/26 again." | "Auto-fallback when limits hit" | "Per-skill agent memory explained" | "What my git hook caught last week" |

Pause and analyze week 5 (which posts saved/shared best) before doubling down.

---

## How to leverage SuperAgent to make every post

This is the unfair advantage. SuperAgent ships your content the same way it
ships your code.

### 1. Pillar-1 receipts (no work)

```bash
/token-stats --badge | pbcopy           # already pasteable markdown
superagent-cost week --json             # weekly $-saved number
superagent-oneshot                      # routing health stat
```

Screenshot the terminal. Caption: "saved 229k tokens this week — here's the
receipt." Done.

### 2. Pillar-2 demos (10 minutes)

```bash
/video-craft "30 second product demo: classify a bug task → safety gate
              catches rm -rf → free local fallback kicks in"
```

`video-craft` authors an HTML composition, renders deterministically via
hyperframes, drops a 30 s 1920×1080 MP4 into `marketing/`. Crop to 1080×1920
for Reels.

### 3. Pillar-3 comparisons (15 minutes)

```bash
/graphify "render the SuperAgent vs everything else table from README as
            10 carousel slides — one column per slide, brutalist black bg"
```

Outputs SVGs you can drop into Canva, Figma, or post directly. The
`ui-ux-pro-max` skill keeps the design system consistent across posts.

### 4. Pillar-4 pain memes (5 minutes)

```bash
/caveman "i was paying 200 a month for AI rate limits. now i pay 0."
```

Caveman compresses to a tight 1-line caption. Pair with a screen recording or
a stock meme. Ship.

### 5. Pillar-5 education (30 minutes)

```bash
/agent-skills:idea-refine "explain 3-tier router so a junior dev gets it"
/graphify "render the explanation as a 7-slide carousel"
```

`idea-refine` runs the divergent → convergent loop. `graphify` lays it out.
You edit, you post.

### 6. Pillar-6 behind-the-scenes (no extra work)

You're already doing the work. Pipe the work into content:

```bash
git log --oneline -10 | head           # recent commit story
mempalace search "what surprised me"   # what the project taught you
superagent-classify "$(git log -1 --pretty=%B)"
```

Caption template: "Today I shipped `<feature>`. Here's what I learned →".

### 7. Closing the loop — `learn` what worked

```bash
/learn add "carousels with terminal screenshots beat static images by 4×"
/learn list
```

Per-project learnings stick across sessions. After ~10 posts, you'll have a
calibrated playbook the model can apply to future drafts.

---

## Captions — a template that works

```
HOOK (one line, painful or surprising)
  ↓
1-3 short sentences with the receipt or insight
  ↓
"Here's how it works:" (one-line teaser of the mechanism)
  ↓
CTA — "Free + open source. Link in bio." or
       "Bench: 26/26. Try it: github.com/animeshbasak/SuperAgent"
  ↓
8-12 hashtags
```

Keep captions under 220 chars to avoid the "more" cut. Save the long-form for
LinkedIn / X.

---

## Cross-post strategy

| Platform | Best for | Action |
|---|---|---|
| Instagram Reels | Reach | Post first |
| Instagram Carousel | Saves | Post second |
| TikTok | Reach (no API drop) | Cross-post Reels with vertical crop |
| YouTube Shorts | Long-tail SEO | Cross-post Reels with full caption |
| X/Twitter | Receipt threads | Tweet the same `/token-stats` screenshot |
| LinkedIn | Senior dev audience | Post the carousel + an essay-length caption |
| HN / Reddit r/LocalLLaMA | First-week launch | Submit when receipts are strong |

Don't cross-post to all 7 from day 1. Master Reels + Carousels first; layer in
the rest at week 4+.

---

## Anti-patterns (don't)

- **Don't promise quality you can't measure.** "saves 95% of tokens" needs a
  badge. "best AI tool" without numbers reads as noise.
- **Don't post your own logo intro.** First 0.5 s = the hook, not your brand.
- **Don't tag-spam.** 30 hashtags screams "I don't know what this is about".
- **Don't repost the README.** Slice it. One feature per post.
- **Don't skip captions just because the visual is strong.** Saves come from the
  caption, not the image.
- **Don't engage in flame wars with Cursor/Copilot fans.** Stay on receipts.

---

## Metrics dashboard (week-end ritual)

```bash
# what shipped this week
git log --since='1 week ago' --oneline | wc -l

# routing health
superagent-oneshot

# token savings worth screenshotting
/token-stats --badge

# what the user learned that could become content
/learn list | tail -10
```

If routing one-shot rate dropped under 80%, fix the brain before posting more
demos — your content will reflect the bugs.

---

## First-week shot list (do this first)

1. **Reel 1:** "I built a router that lives between every AI coding tool. Here
   are the 4 taxes it kills." (30 s, voiceover)
2. **Carousel 1:** "SuperAgent vs everything else" (10 slides — the comparison
   table from the README, one row per slide)
3. **Receipt 1:** terminal screenshot of `/token-stats --badge` after a week
   of use, zero rate limits
4. **Reel 2:** "Watch SuperAgent stop my AI from running `rm -rf`" (15 s,
   screen capture, on-screen text)
5. **Pain meme 1:** "POV: it's 4pm and your model says wait 5 hours" (7 s
   loop)

Schedule across week 1. Reply to every comment within 4 hours of posting. Pin
the receipt post to the profile. By week 2 you'll know which pillar pulls.
