# PB Gen — Web

A web version of the **PB Gen** iOS app: an Americano-style pickleball doubles
tournament generator. It creates fair, balanced schedules where players rotate
partners and opponents, tracks scores, and ranks everyone on a live leaderboard.

This is a **static, self-contained web app** — no backend, no build step, no
dependencies. It runs entirely in the browser and stores tournaments in
`localStorage`, so it deploys anywhere that serves static files (GitHub Pages,
Netlify, any web host).

## What it does

- **Create** named tournaments (Americano format; single/double elimination are
  stubbed as "coming soon", matching the iOS app).
- **Details** — add/edit/remove players (min 4), with duplicate-name detection;
  set rounds (1–10) and courts (1–5).
- **Schedule** — expandable per-round cards showing each court's matchup, who's
  resting, and a tap-to-set score picker; add extra rounds on the fly.
- **Leaderboard** — ranked standings with point differential, wins, losses, and
  rests, sortable by Name / Pts / W / L / R.
- **Multi-tournament** management with automatic save and switching.

## Architecture

| File | Responsibility |
|------|----------------|
| `js/engine.js` | Pure logic — seeded RNG, the Americano scheduler (backtracking, play-deficit fairness, rest rotation), and leaderboard scoring. No DOM. |
| `js/store.js` | `localStorage` persistence (multi-tournament). |
| `js/app.js` | UI controller — renders every screen and wires interactions. |
| `css/styles.css` | Design system ported from the SwiftUI app, tuned to Apple's HIG. |
| `tests/engine.test.js` | Zero-dependency test suite for the engine. |

The scheduler is a faithful JavaScript port of the app's
`AmericanoScheduler.swift`, with one improvement: if a round can't be built from
all-unique partnerships it switches to "allow repeats" and retries, instead of
silently producing fewer rounds than requested.

## Run locally

```bash
cd web
python3 -m http.server 8000
# open http://localhost:8000
```

## Test

```bash
node web/tests/engine.test.js
```

The suite sweeps hundreds of player/court/round/seed combinations and checks
structural invariants (everyone plays or rests exactly once per round, correct
match/rest counts), fairness (balanced rests and games played), partnership
variety, additional-round generation, leaderboard math, and determinism.

## Deploy to GitHub Pages

A workflow at `.github/workflows/pages.yml` publishes the `web/` folder to
GitHub Pages on every push to `main`. Enable it under **Settings → Pages →
Build and deployment → Source: GitHub Actions**.
