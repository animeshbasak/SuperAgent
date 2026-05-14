---
name: scraping
---
# scraping

> Web scraping, crawling, and data extraction with anti-bot bypass (Cloudflare Turnstile), stealth headless browsing, JS rendering, and adaptive parsing. Triggers on "scrape", "scraping", "crawl", "crawler", "extract from website", "bypass cloudflare", "anti-bot", "scrapling". Use when the user wants to pull content from a website, especially one that fails to fetch via plain HTTP or has anti-bot protections.

# scraping — SuperAgent wrapper around Scrapling

This skill is a thin SuperAgent-namespaced wrapper around **[Scrapling](https://github.com/D4Vinci/Scrapling)**, an adaptive Web Scraping framework by **D4Vinci**. We do not vendor Scrapling itself — we install it on first use into a per-user Python virtualenv and drive it through `bin/superagent-scrape`.

> Credits and upstream
> - GitHub: <https://github.com/D4Vinci/Scrapling>
> - Discord: <https://discord.gg/EMgGbDceNQ>
> - Docs: <https://scrapling.readthedocs.io/>
>
> All anti-bot bypass capability, the spider framework, the adaptive parser, and the stealth fetchers are Scrapling's work. SuperAgent only provides the routing rule and a thin CLI wrapper so the classifier can dispatch scraping tasks consistently.

## Why route to this skill

Use **scraping** when:

- The user says "scrape", "crawl", "extract from a website", "pull product prices", "grab the article body".
- A `WebFetch` / plain HTTP request returns empty, a CAPTCHA page, or a Cloudflare Turnstile interstitial.
- The site is a modern SPA whose useful content only renders after JavaScript executes.
- The user explicitly mentions Scrapling, anti-bot bypass, or stealth headless browsing.

If the page is a plain static blog or a Markdown file on GitHub, you do not need this skill — use `WebFetch`. Escalate to scraping only when the simpler path fails.

## Setup (one-time, lazy)

The first time `bin/superagent-scrape` runs, it bootstraps a dedicated Python virtualenv at `~/.superagent/scraping/.venv` and installs Scrapling. You can also do it explicitly:

```bash
# Idempotent — skips if already installed
superagent-scrape install
```

What `install` does, mirroring the upstream Scrapling instructions:

1. Creates a venv at `~/.superagent/scraping/.venv` (override with `SCRAPLING_VENV`).
2. Runs `pip install "scrapling[all]>=0.4.7"` inside that venv.
3. Runs `scrapling install --force` inside that venv to pull browser dependencies.

Requires **Python 3.10+**. If `python3` is missing, the wrapper prints a clear error and exits non-zero — it will not silently fall back.

## CLI surface

`bin/superagent-scrape` exposes four subcommands:

| Subcommand | Purpose |
|------------|---------|
| `install` | Bootstrap the venv + install Scrapling + browser deps (idempotent). |
| `fetch <url> [--ai-targeted]` | Plain HTTP `GET` via `scrapling extract get`. Fast path. |
| `browser <url> [--ai-targeted]` | Headless-browser scrape via `scrapling extract fetch` (escalates to `stealthy-fetch` when needed). |
| `status` | Report venv state and `scrapling --version`. |
| `--help` | Print usage. |

### `--ai-targeted` — MANDATORY for AI/agent use

> **IMPORTANT**: When this skill runs from inside an LLM agent (which is every time SuperAgent invokes it), you **MUST** pass `--ai-targeted` to `fetch` and `browser`. This is Scrapling's built-in **prompt-injection protection** — it strips hidden elements and adversarial content from the returned HTML before the agent reads it. For browser commands, `--ai-targeted` also enables ad blocking automatically, which saves tokens. Do not omit it.

## Three reference use cases

### 1. Simple GET — plain HTML page

```bash
superagent-scrape fetch "https://news.ycombinator.com" --ai-targeted
```

This is the fast path. No browser, no JavaScript, no anti-bot evasion. Use it for static HTML, blogs, RSS-adjacent pages, and APIs that return HTML.

### 2. Anti-bot-protected site (Cloudflare Turnstile, etc.)

```bash
superagent-scrape browser "https://protected.example.com/products" --ai-targeted
```

Routes through Scrapling's **stealthy** browser. Cloudflare Turnstile and similar anti-bot interstitials are solved through automation alone — **no third-party solvers, no API keys, no credentials are involved**. Use this when a plain `fetch` returns a challenge page or empty body.

### 3. JS-rendered SPA (React / Vue / Svelte site)

```bash
superagent-scrape browser "https://spa.example.com/dashboard" --ai-targeted
```

Same `browser` subcommand — Scrapling's browser fetcher executes JavaScript, waits for the DOM to settle, then returns the rendered HTML. Use this for any modern web app where the useful content is hydrated client-side.

### Escalation rule of thumb

> Start with `fetch`. If you get empty / challenge / login-wall, escalate to `browser`. Speed difference is small enough that you lose nothing by re-trying.

## Environment overrides

| Var | Purpose | Default |
|-----|---------|---------|
| `SCRAPLING_VENV` | Path to the Scrapling venv | `~/.superagent/scraping/.venv` |

## Safety notes (verbatim from upstream)

1. Cloudflare solving is performed via automation — no external solver services or credentials are required.
2. Proxy usage and CDP mode are optional and user-supplied — this skill does not store secrets.
3. Arguments like `cdp_url`, `user_data_dir`, and `proxy auth` are validated inside Scrapling, but the user should still be aware they may carry credentials when used.

## Routing

The SuperAgent classifier auto-routes any task matching `\b(scrape|scraping|crawl(er|ing)?|extract from (the |a )?website|bypass cloudflare|anti.?bot|scrapling)\b` to a chain of `[scraping]` at `moderate` complexity. See `skills/superagent/brain/rules.yaml`.
