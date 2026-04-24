# India Energy Lockdown Indicator — File № 003

A live dashboard tracking the probability of an India energy lockdown in the next 30 days. Re-scored every 6 hours from primary news, market data, and government statements.

**Status (2026-04-23):** YELLOW · ~28% · "targeted energy measures probable; full lockdown unlikely."

---

## What's in this folder

| File | Purpose |
|---|---|
| `dashboard.html` | The live dashboard — open in any browser |
| `state.json` | Current indicator state — read by dashboard, written by update script |
| `history.jsonl` | Append-only log of every update (powers the trend chart) |
| `THESIS_2026-04-23.md` | Full data audit and probability case |
| `THE_STORY.md` | Ship-ready narrative for publishing |
| `sources.json` | 38+ sourced URLs, trust-tier classified |
| `scripts/update-indicator.sh` | The worker — fetches RSS + market data, re-scores, writes state |
| `scripts/com.lockdown-indicator.plist` | launchd job definition (every 6 hrs) |
| `scripts/install.sh` | One-command install/uninstall of the launchd job |

---

## Quick start

### 1. Install dependencies (one time)
```bash
brew install jq
```
(`curl` and `python3` ship with macOS.)

### 2. Run the updater once manually
```bash
cd /Users/hiteshmalviya/Downloads/india-energy-thesis
./scripts/update-indicator.sh --force
```
This will fetch live RSS feeds and market data, score the indicator, and write a fresh `state.json` + `history.jsonl` line.

### 3. Open the dashboard
```bash
open dashboard.html
```
The dashboard auto-refreshes from `state.json` every 60 seconds.

### 4. Install the launchd job (every 6 hours)
```bash
./scripts/install.sh install
```
Runs at 00:15, 06:15, 12:15, 18:15 local time. To check status:
```bash
launchctl print "gui/$(id -u)/com.lockdown-indicator.update" | head
tail -f scripts/update.log
```

To uninstall:
```bash
./scripts/install.sh uninstall
```

---

## How the indicator works

The score is built from **6 escalation triggers** (max 115 points) and **secondary signals** (max 10 points), normalised to 0–100%.

| Trigger | Max pts | What it measures |
|---|---|---|
| T1 · Strait of Hormuz status | 20 | Open / restricted / closed (RSS keyword density) |
| T2 · Iran strikes Saudi/UAE oil infra | 20 | None / threats / confirmed / sustained |
| T3 · Brent crude price | 15 | <$90 / $90-110 / $110-130 / $130-150 sustained / >$150 |
| T4 · US ground escalation | 15 | None / buildup / kinetic / open ground war |
| T5 · India SPR days remaining | 15 | >60 / 45-60 / 30-45 / <30 |
| T6 · Indian refinery attack | 30 | None / threats / attempted / successful |
| +S · Secondary signals | ±10 | Govt denial language, LPG delays, INR-USD stress |

### Verdict bands

| Band | Range | Meaning |
|---|---|---|
| **GREEN** | 0–14% | Status quo, no formal restrictions |
| **YELLOW** | 15–34% | Targeted measures probable (LPG quotas, WFH, weekend curbs) |
| **ORANGE** | 35–59% | State-level energy emergencies likely; aviation curbs |
| **RED** | 60–100% | Full nationwide lockdown probable within 30 days |

### Outcomes distribution

Each band maps to a probability distribution across four 30-day outcomes (status quo / targeted / state emergency / full lockdown). The dashboard shows the current distribution.

---

## When to manually override

The script is designed to front-run consensus, but keyword-matching has limits. Edit `state.json` directly when:

- Breaking news the keyword scanner missed (e.g. a refinery attack that hasn't hit Google News yet but is on Bloomberg terminal)
- A government statement that materially changes the picture
- Market data the script failed to fetch (check `scripts/update.log` for "fetch failed" warnings)

After a manual edit, append a corresponding line to `history.jsonl` so the trend chart stays consistent.

---

## What the script does (per run)

1. Checks freshness (skips if last run was <5 hrs ago, unless `--force`)
2. Fetches Google News RSS for 7 specific queries (Hormuz, Saudi/UAE strikes, Brent price, US ground war, India SPR, Indian refinery, India lockdown LPG)
3. Fetches Brent crude price from Investing.com + TradingEconomics
4. Parses RSS, extracts headlines, runs regex pattern matches against trigger states
5. Computes weighted score, maps to band + verdict
6. Writes `state.json` (overwrites) + appends to `history.jsonl`
7. Logs to `scripts/update.log`

Script is **idempotent** — re-running won't double-count history (one append per run).

---

## Defensive notes

- **Do not publish a single update as "the truth."** The indicator is a moving instrument; its value is the *trend*, not the snapshot. A single 6-hr reading is noisy.
- **Source URLs decay.** Run `bryanjohnson-v3/scripts/wayback-snapshot.sh` against `sources.json` periodically to preserve the citation trail.
- **Government statements move the dial.** Watch for press releases from PIB, MoPNG, MEA — these change the secondary signals even when the underlying triggers are dormant.
- **Refinery attacks are the asymmetric risk.** A successful strike on Reliance Jamnagar would push the indicator past 60% within 72 hours regardless of other triggers. T6 carries the largest single weight (30 pts) for this reason.

---

## Roadmap

**Done (v1.0):**
- Dashboard with live state, trend chart, trigger cards, signal cards
- Worker script with 6-hour launchd schedule
- Manual override mechanism
- Source ledger with trust tiers

**Next (v1.1):**
- Email/Slack alert when band changes (GREEN → YELLOW → ORANGE → RED)
- Wayback snapshot integration for source URLs
- More sophisticated price feeds (CFTC COT, futures curve)
- Twitter/X auto-post when band changes

**Next (v1.2):**
- Per-state India dashboard (Maharashtra, TN, Gujarat, Karnataka, Delhi)
- LPG-specific sub-indicator (the genuine soft spot)
- Backtest on prior energy crises (1973, 1979, 1990)

---

## Honesty caveat

This dashboard is a **decision support tool**, not a prediction guarantee. The probability is a structured judgment based on the inputs the script can fetch — it will miss things, get keyword-matches wrong, and need human review. Treat it as a faster pair of eyes, not an oracle.

Same discipline as the bryanjohnson v3 dossier: every number traces to a source, manual overrides are visible, and "UNVERIFIED" is a valid output.
