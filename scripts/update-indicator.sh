#!/usr/bin/env bash
# India Lockdown Indicator — auto-update worker (pure bash, zero deps)
# Re-scores the lockdown probability every 6 hours from primary sources.
# Reads keywords from RSS feeds + market data, advances trigger states,
# writes new state.json + appends to history.jsonl.
#
# Usage:
#   ./scripts/update-indicator.sh           # normal run
#   ./scripts/update-indicator.sh --dry-run # show would-do without writing
#   ./scripts/update-indicator.sh --force   # ignore last-update freshness check
#
# Dependencies: curl, awk, sed, grep — all bundled with macOS.
# No Python, no jq, no Homebrew required.
#
# Cron / launchd: see scripts/com.lockdown-indicator.plist

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$ROOT/state.json"
HISTORY="$ROOT/history.jsonl"
LOG="$ROOT/scripts/update.log"
DRY_RUN=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
  esac
done

ts_iso()       { date -u +%Y-%m-%dT%H:%M:%SZ; }
ts_iso_plus6() { date -u -v+6H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "+6 hours" +%Y-%m-%dT%H:%M:%SZ; }
log()          { echo "[$(ts_iso)] $*" | tee -a "$LOG"; }

log "=== update-indicator START (dry_run=$DRY_RUN force=$FORCE) ==="

# Freshness check — extract captured_at from state.json without jq.
# Works on both BSD/macOS (date -j -u -f) and GNU/Linux (date -u -d) for portability.
if [ -f "$STATE" ] && [ "$FORCE" -eq 0 ]; then
  last_iso=$(grep -E '"captured_at"' "$STATE" | head -1 | sed -E 's/.*"captured_at"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
  if [ -n "${last_iso:-}" ]; then
    # Try BSD/macOS first, fall back to GNU/Linux date parser
    last_epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_iso" +%s 2>/dev/null \
              || date -u -d "$last_iso" +%s 2>/dev/null \
              || echo 0)
    now_epoch=$(date -u +%s)
    age_hours=$(( (now_epoch - last_epoch) / 3600 ))
    if [ "$age_hours" -ge 0 ] && [ "$age_hours" -lt 5 ]; then
      log "Last update was ${age_hours}h ago; skipping (use --force to override)."
      exit 0
    fi
  fi
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 11.0; rv:127.0) Gecko/20100101 Firefox/127.0"

fetch_rss() {
  local query="$1" out="$2"
  log "fetch RSS: $query"
  curl -sSL --max-time 30 -A "$UA" \
    "https://news.google.com/rss/search?q=${query}&hl=en" \
    -o "$out" 2>/dev/null || log "WARN: RSS fetch failed for $query"
}

fetch_html() {
  local url="$1" out="$2"
  log "fetch HTML: $url"
  curl -sSL --max-time 30 -A "$UA" "$url" -o "$out" 2>/dev/null || log "WARN: HTML fetch failed for $url"
}

fetch_rss "Strait+of+Hormuz+blockade+April+2026"            "$TMP/hormuz.rss"
fetch_rss "Iran+strikes+Saudi+UAE+oil+infrastructure"       "$TMP/saudi_uae.rss"
fetch_rss "Brent+crude+oil+price+spot"                      "$TMP/brent.rss"
fetch_rss "US+ground+troops+Iran+war+invasion"              "$TMP/us_ground.rss"
fetch_rss "India+strategic+petroleum+reserve+depleted"      "$TMP/india_spr.rss"
fetch_rss "India+refinery+attack+Reliance+Jamnagar"         "$TMP/india_refinery.rss"
fetch_rss "India+lockdown+LPG+rationing+Hardeep+Puri"       "$TMP/india_lockdown.rss"
fetch_rss "India+petrol+diesel+price+April+2026"            "$TMP/india_fuel.rss"
fetch_rss "India+LPG+cylinder+price+shortage"               "$TMP/india_lpg.rss"
fetch_rss "Russia+India+oil+imports+2026"                   "$TMP/russia_india.rss"
fetch_rss "OPEC+production+cut+April+2026"                  "$TMP/opec.rss"
fetch_rss "Bangladesh+energy+crisis+fuel+rationing"         "$TMP/bangladesh.rss"
fetch_rss "Pakistan+four+day+workweek+energy+crisis"        "$TMP/pakistan.rss"
fetch_rss "Iran+ceasefire+April+2026+ships+seized"          "$TMP/ceasefire.rss"
fetch_rss "EIA+STEO+Brent+forecast+2026"                    "$TMP/eia_forecast.rss"
fetch_rss "INR+rupee+dollar+exchange+rate+April+2026"       "$TMP/inr_usd.rss"
fetch_rss "Reliance+Jamnagar+BPCL+IOC+HPCL+stock+2026"      "$TMP/refiner_stocks.rss"
fetch_rss "aviation+fuel+ATF+jet+kerosene+India"            "$TMP/atf.rss"
# Oil price — multiple fallback sources
fetch_html "https://www.investing.com/commodities/brent-oil"              "$TMP/brent.html"
fetch_html "https://tradingeconomics.com/commodity/brent-crude-oil"       "$TMP/brent_te.html"
fetch_html "https://www.marketwatch.com/investing/future/brent%20crude"   "$TMP/brent_mw.html"
fetch_html "https://finance.yahoo.com/quote/BZ%3DF/"                      "$TMP/brent_yahoo.html"
# WTI: try multiple sources (Yahoo URL-encoded, plain, MarketWatch, Investing, TradingEconomics)
fetch_html "https://finance.yahoo.com/quote/CL%3DF/"                      "$TMP/wti_yahoo.html"
fetch_html "https://finance.yahoo.com/quote/CL=F/"                        "$TMP/wti_yahoo2.html"
fetch_html "https://www.marketwatch.com/investing/future/crude%20oil%20-%20electronic" "$TMP/wti_mw.html"
fetch_html "https://www.investing.com/commodities/crude-oil"              "$TMP/wti_invest.html"
fetch_html "https://tradingeconomics.com/commodity/crude-oil"             "$TMP/wti_te.html"
# Prediction markets — Polymarket is regulatory-blocked from India; using Manifold (accessible) as proxy.
fetch_html "https://api.manifold.markets/v0/search-markets?term=iran&limit=15"            "$TMP/manifold_iran.json"
fetch_html "https://api.manifold.markets/v0/search-markets?term=oil%20price&limit=12"     "$TMP/manifold_oil.json"
fetch_html "https://api.manifold.markets/v0/search-markets?term=india%20politics&limit=15" "$TMP/manifold_india.json"

# ----- Helpers -----

# Extract <title> from each <item> in Google News RSS.
# IMPORTANT: skip the channel-level <title> (which is the search query string).
# Use RS="<item>" so the first record is everything before items (channel/header) — drop it.
extract_titles() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk 'BEGIN{RS="<item>"} NR>1 {
    gsub(/\n/, " ")
    if (match($0, /<title>(<!\[CDATA\[)?[^<]*/)) {
      t = substr($0, RSTART+7, RLENGTH-7)
      gsub(/^<!\[CDATA\[/, "", t)
      gsub(/\]\]>$/, "", t)
      gsub(/&amp;/, "\\&", t)
      gsub(/&#39;/, "\047", t)
      gsub(/&quot;/, "\"", t)
      print t
    }
  }' "$file" 2>/dev/null | head -30
}

# Escape evidence strings for JSON (needed before build_news_feed is called)
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r'; }

# Hedge words that demote a "confirmed event" to "threat / hypothetical / forecast"
HEDGE_RE='(threat|warns?|intent|may( |t)|could|would|might|if[ ,]|potential|hypothetical|forecast|simul|fear[s ]|rumor|speculat|consider|plan to|propos|expects?|likely|risk of|brace|prepare|warning|considering|denies|denied|debunk|false|baseless|no lockdown)'

# Count headlines in file matching ANY of the regex patterns (positional args).
# Filters OUT hedged headlines — only counts unhedged "confirmed event" matches.
match_count() {
  local file="$1"; shift
  local count=0
  if [ -f "$file" ]; then
    local titles
    titles=$(extract_titles "$file")
    while IFS= read -r pat; do
      [ -z "$pat" ] && continue
      local n
      n=$(echo "$titles" | grep -i -E "$pat" | grep -i -v -E "$HEDGE_RE" | wc -l | tr -d ' ')
      count=$((count + n))
    done < <(printf '%s\n' "$@")
  fi
  echo "$count"
}

# Count headlines that match BOTH the pattern AND a hedge word — indicates "threat / hypothetical".
match_threat() {
  local file="$1"; shift
  local count=0
  if [ -f "$file" ]; then
    local titles
    titles=$(extract_titles "$file")
    while IFS= read -r pat; do
      [ -z "$pat" ] && continue
      local n
      n=$(echo "$titles" | grep -i -E "$pat" | grep -i -E "$HEDGE_RE" | wc -l | tr -d ' ')
      count=$((count + n))
    done < <(printf '%s\n' "$@")
  fi
  echo "$count"
}

# Extract first matching headline (for evidence text). Includes hedged hits — used for display.
first_match() {
  local file="$1"; shift
  if [ -f "$file" ]; then
    local titles
    titles=$(extract_titles "$file")
    while IFS= read -r pat; do
      [ -z "$pat" ] && continue
      local hit
      hit=$(echo "$titles" | grep -i -E "$pat" | head -1 || true)
      if [ -n "$hit" ]; then
        echo "$hit"
        return 0
      fi
    done < <(printf '%s\n' "$@")
  fi
  echo ""
}

# Extract oil price from HTML — try multiple patterns, multiple sources, first success wins.
# Valid range: $60-$200/bbl.
extract_price_from_html() {
  local file="$1"
  [ -f "$file" ] || return 1
  # Try several patterns in order
  local extracted
  # Pattern 1: $XXX.XX style
  extracted=$(grep -oE '\$[ ]?[0-9]{2,3}\.[0-9]{1,2}' "$file" 2>/dev/null \
              | tr -d '$ ' \
              | awk '{ if ($1+0 >= 60 && $1+0 <= 200) print }' \
              | head -30 \
              | sort -n)
  # Pattern 2: Yahoo-style quote data attribute
  if [ -z "$extracted" ]; then
    extracted=$(grep -oE '"regularMarketPrice":\{"raw":[0-9]{2,3}\.[0-9]{1,4}' "$file" 2>/dev/null \
                | grep -oE '[0-9]{2,3}\.[0-9]{1,4}' \
                | awk '{ if ($1+0 >= 60 && $1+0 <= 200) print }' \
                | head -5)
  fi
  # Pattern 3: JSON-LD / generic number near "Brent"
  if [ -z "$extracted" ]; then
    extracted=$(grep -oE '(Brent|WTI)[^0-9]{0,40}[0-9]{2,3}\.[0-9]{1,2}' "$file" 2>/dev/null \
                | grep -oE '[0-9]{2,3}\.[0-9]{1,2}' \
                | awk '{ if ($1+0 >= 60 && $1+0 <= 200) print }' \
                | head -10)
  fi
  [ -z "$extracted" ] && return 1
  local cnt mid
  cnt=$(echo "$extracted" | wc -l | tr -d ' ')
  mid=$(( (cnt + 1) / 2 ))
  echo "$extracted" | sed -n "${mid}p"
}

extract_brent_price() {
  local price=""
  for f in "$TMP/brent_yahoo.html" "$TMP/brent.html" "$TMP/brent_te.html" "$TMP/brent_mw.html"; do
    price=$(extract_price_from_html "$f" 2>/dev/null || true)
    if [ -n "$price" ]; then
      echo "$price"
      return 0
    fi
  done
  echo ""
}

extract_wti_price() {
  local price=""
  for f in "$TMP/wti_yahoo.html" "$TMP/wti_yahoo2.html" "$TMP/wti_invest.html" "$TMP/wti_te.html" "$TMP/wti_mw.html"; do
    price=$(extract_price_from_html "$f" 2>/dev/null || true)
    if [ -n "$price" ]; then
      echo "$price"
      return 0
    fi
  done
  echo ""
}

# Build a news feed: pull top headlines from all RSS files, tag each with trigger,
# dedupe by title prefix, output as JSON array. Used by dashboard's live news feed.
build_news_feed() {
  local out=""
  local count=0
  local max=50
  local seen_file="$TMP/_seen_titles"
  : > "$seen_file"

  # Map RSS file -> trigger tag -> severity -> source label
  # Format: filename|trigger|severity|category
  local -a feeds=(
    "hormuz.rss|hormuz|high|war"
    "saudi_uae.rss|iran_strikes_gulf|critical|war"
    "us_ground.rss|us_ground|high|war"
    "ceasefire.rss|ceasefire|medium|war"
    "india_refinery.rss|indian_refinery|critical|india"
    "india_spr.rss|india_spr|high|india"
    "india_lockdown.rss|india_lockdown|high|india"
    "india_fuel.rss|india_fuel|medium|india"
    "india_lpg.rss|india_lpg|high|india"
    "russia_india.rss|russia_india|medium|india"
    "bangladesh.rss|bangladesh|medium|regional"
    "pakistan.rss|pakistan|medium|regional"
    "atf.rss|aviation|medium|india"
    "brent.rss|oil_price|medium|market"
    "opec.rss|opec|medium|market"
    "eia_forecast.rss|eia_forecast|medium|market"
    "inr_usd.rss|inr_usd|low|market"
    "refiner_stocks.rss|refiner_stocks|low|market"
  )

  for feed in "${feeds[@]}"; do
    local fn="${feed%%|*}"
    local rest="${feed#*|}"
    local trig="${rest%%|*}"
    rest="${rest#*|}"
    local sev="${rest%%|*}"
    local cat="${rest#*|}"
    local file="$TMP/$fn"
    [ -f "$file" ] || continue

    local titles
    titles=$(extract_titles "$file" | head -4)
    while IFS= read -r title; do
      [ -z "$title" ] && continue
      [ "$count" -ge "$max" ] && break 2

      # Dedupe key: lowercased first 60 chars of title (catches near-dupes across feeds)
      local dkey
      dkey=$(echo "$title" | tr 'A-Z' 'a-z' | cut -c1-60)
      if grep -qF "$dkey" "$seen_file" 2>/dev/null; then
        continue
      fi
      echo "$dkey" >> "$seen_file"

      # Extract source from " - SOURCE" suffix
      local src="unknown"
      if echo "$title" | grep -qE ' - [A-Za-z][^-]*$'; then
        src=$(echo "$title" | sed -E 's/.* - ([^-]+)$/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        title=$(echo "$title" | sed -E 's/ - [^-]*$//')
      fi
      local title_esc src_esc
      title_esc=$(esc "$title")
      src_esc=$(esc "$src")
      if [ "$count" -gt 0 ]; then out+=","; fi
      out+=$'\n    {"trigger":"'"$trig"'","severity":"'"$sev"'","category":"'"$cat"'","source":"'"$src_esc"'","title":"'"$title_esc"'"}'
      count=$((count+1))
    done <<< "$titles"
  done
  echo "$out"
}

# ----- Score each trigger -----

# T1: Hormuz status — count of "closed/blockade/seized/attack" headlines
HORMUZ_HITS=$(match_count "$TMP/hormuz.rss" \
  "hormuz.*(closed|shut|blockad|seized|attacked|mined)" \
  "iran.*seiz.*ship" \
  "strait.*of.*hormuz.*disrupt" \
  "iran.*blockad" )
HORMUZ_OPEN=$(match_count "$TMP/hormuz.rss" \
  "hormuz.*(reopen|fully open|resume)" \
  "ceasefire.*hold" )
HORMUZ_EV=$(first_match "$TMP/hormuz.rss" \
  "hormuz.*(closed|shut|blockad|seized|attacked|mined)" \
  "iran.*seiz.*ship" )
if [ "$HORMUZ_HITS" -ge 5 ]; then
  T1_SCORE=18; T1_STATE="sustained_blockade"
elif [ "$HORMUZ_HITS" -ge 2 ]; then
  T1_SCORE=12; T1_STATE="intermittent_blockade"
elif [ "$HORMUZ_OPEN" -ge 2 ] && [ "$HORMUZ_HITS" -eq 0 ]; then
  T1_SCORE=3;  T1_STATE="mostly_open"
else
  T1_SCORE=8;  T1_STATE="uncertain"
fi
[ -z "$HORMUZ_EV" ] && HORMUZ_EV="no fresh closure headlines this cycle"

# T2: Iran strikes Saudi/UAE oil infra (confirmed events only; hedged headlines counted as threats)
SAUDI_CONFIRMED=$(match_count "$TMP/saudi_uae.rss" \
  "iran.*(strik|attack|missile|drone|hit).*(saudi|uae|abqaiq|ras tanura|ghawar|kuwait)" \
  "(saudi|uae).*oil.*(facility|infrastructure|refinery).*hit" )
SAUDI_THREATS=$(match_threat "$TMP/saudi_uae.rss" \
  "iran.*(strik|attack|missile|threat).*(saudi|uae)" \
  "saudi.*evacuat" )
SAUDI_EV=$(first_match "$TMP/saudi_uae.rss" \
  "iran.*(strik|attack|missile|drone).*(saudi|uae|abqaiq|ras tanura|ghawar)" \
  "iran.*threat.*(saudi|uae)" )
if [ "$SAUDI_CONFIRMED" -ge 1 ]; then
  T2_SCORE=18; T2_STATE="confirmed_strikes"
elif [ "$SAUDI_THREATS" -ge 1 ]; then
  T2_SCORE=8;  T2_STATE="threats_only"
else
  T2_SCORE=5;  T2_STATE="no_strikes_yet"
fi
[ -z "$SAUDI_EV" ] && SAUDI_EV="no Saudi/UAE strike headlines"

# T3: Brent price
BRENT=$(extract_brent_price)
if [ -z "$BRENT" ]; then
  T3_SCORE=4; T3_STATE="price_fetch_failed"
  T3_EV="could not extract Brent price from web sources"
else
  # Integer comparison via awk
  T3_SCORE=$(awk -v p="$BRENT" 'BEGIN{
    if (p+0 < 90) print 0
    else if (p+0 < 110) print 4
    else if (p+0 < 130) print 8
    else if (p+0 < 150) print 13
    else print 15
  }')
  T3_STATE="brent_$(printf %.0f "$BRENT")"
  T3_EV="Brent spot ~\$${BRENT}/bbl extracted from market data"
fi

# T4: US ground escalation (confirmed events only — excludes "would invade" / "could invade" hypotheticals)
US_GROUND=$(match_count "$TMP/us_ground.rss" \
  "us.*(troops|marines|soldiers).*(landed|invaded|killed|crossed).*iran" \
  "us (ground )?invasion of iran (begins|starts|launched|underway)" \
  "us.*soldier.*killed.*iran" )
US_BUILDUP=$(match_count "$TMP/us_ground.rss" \
  "us.*(deploy|reinforc|carrier|aircraft).*(middle east|gulf|persian gulf)" )
US_EV=$(first_match "$TMP/us_ground.rss" \
  "us.*(ground|land).*(troop|invas|war).*iran" \
  "us.*(deploy|reinforc|carrier).*middle east" )
if [ "$US_GROUND" -ge 1 ]; then
  T4_SCORE=13; T4_STATE="ground_kinetic"
elif [ "$US_BUILDUP" -ge 1 ]; then
  T4_SCORE=6;  T4_STATE="buildup"
else
  T4_SCORE=3;  T4_STATE="naval_only"
fi
[ -z "$US_EV" ] && US_EV="no US ground escalation headlines"

# T5: India SPR days remaining
SPR_LOW=$(match_count "$TMP/india_spr.rss" \
  "india.*(spr|reserve).*(below|under|less than)[[:space:]]+(30|20|15|10)" \
  "india.*(strategic|petroleum).*reserve.*depleted" )
SPR_EV=$(first_match "$TMP/india_spr.rss" \
  "india.*(spr|reserve).*(below|under|less than)[[:space:]]+(30|20|15|10)" )
if [ "$SPR_LOW" -ge 1 ]; then
  T5_SCORE=13; T5_STATE="below_30_days"
else
  T5_SCORE=0;  T5_STATE="above_60_days"
fi
[ -z "$SPR_EV" ] && SPR_EV="Govt baseline 74-day cover; no contradiction in headlines"

# T6: Indian refinery attack — heaviest weight. Confirmed events only; threats counted separately.
REFINERY_HIT=$(match_count "$TMP/india_refinery.rss" \
  "(jamnagar|vadinar|paradip|mathura|panipat|kochi|numaligarh|barauni|haldia).*(refinery|plant).*(attacked|bombed|on fire|exploded|hit by drone|hit by missile|struck by)" \
  "(reliance|nayara|ioc|hpcl|bpcl).*(refinery|plant).*(attacked|bombed|on fire|exploded|hit by drone|hit by missile|struck by)" \
  "india.*refinery.*(attacked|bombed|exploded|hit by drone|hit by missile|on fire)" )
REFINERY_THREAT=$(match_threat "$TMP/india_refinery.rss" \
  "(jamnagar|vadinar|paradip|mathura|panipat|kochi|numaligarh|reliance|nayara|ioc|hpcl|bpcl).*(refinery|plant|target)" \
  "india.*(refinery|oil infra).*(threat|target)" )
REFINERY_EV=$(first_match "$TMP/india_refinery.rss" \
  "(jamnagar|vadinar|paradip|mathura|panipat|kochi|numaligarh|barauni|haldia).*(refinery|plant).*(attack|hit|fire|blast|explosion|bomb|drone|missile)" \
  "(reliance|nayara|ioc|hpcl|bpcl).*(refinery|plant).*(attack|hit|fire|blast|explosion|bomb|drone|missile)" \
  "india.*(refinery|oil infra).*threat" )
if [ "$REFINERY_HIT" -ge 1 ]; then
  T6_SCORE=30; T6_STATE="successful_attack"
elif [ "$REFINERY_THREAT" -ge 1 ]; then
  T6_SCORE=5;  T6_STATE="threats"
else
  T6_SCORE=0;  T6_STATE="none"
fi
[ -z "$REFINERY_EV" ] && REFINERY_EV="no Indian refinery attack headlines"

# Secondary signals
LPG_DELAYS=$(match_count "$TMP/india_lockdown.rss" \
  "lpg.*(shortage|delay|rationing|cylinder|cap|hoarding|cap.*supply|supply.*cap)" )
LPG_DELAYS_LPG=$(match_count "$TMP/india_lpg.rss" \
  "lpg.*(shortage|delay|rationing|cylinder|cap|hoarding|cap.*supply|supply.*cap|closures)" )
LPG_DELAYS=$(( LPG_DELAYS + LPG_DELAYS_LPG ))
GOVT_DENIAL=$(match_count "$TMP/india_lockdown.rss" \
  "(no lockdown|lockdown.*false|lockdown.*ruled out|hardeep puri.*denies)" )
SEC_SCORE=0
SEC_NOTES=""
if [ "$GOVT_DENIAL" -ge 1 ]; then
  SEC_SCORE=$((SEC_SCORE - 2))
  ev=$(first_match "$TMP/india_lockdown.rss" "(no lockdown|lockdown.*false|lockdown.*ruled out|hardeep puri.*denies)")
  SEC_NOTES="govt denial: ${ev}"
fi
if [ "$LPG_DELAYS" -ge 1 ]; then
  SEC_SCORE=$((SEC_SCORE + 3))
  ev=$(first_match "$TMP/india_lockdown.rss" "lpg.*(shortage|delay|rationing|cylinder)")
  SEC_NOTES="${SEC_NOTES}${SEC_NOTES:+; }LPG: ${ev}"
fi
[ -z "$SEC_NOTES" ] && SEC_NOTES="neutral"
SEC_DISPLAY=$(( SEC_SCORE > 0 ? SEC_SCORE : 0 ))
[ "$SEC_DISPLAY" -gt 10 ] && SEC_DISPLAY=10

# ----- Aggregate -----
RAW=$(( T1_SCORE + T2_SCORE + T3_SCORE + T4_SCORE + T5_SCORE + T6_SCORE + SEC_DISPLAY ))
MAX=125
PROB=$(( RAW * 100 / MAX ))
[ "$PROB" -gt 100 ] && PROB=100

if   [ "$PROB" -lt 15 ]; then BAND="GREEN";  VERDICT="Status quo: high prices, no formal restrictions"
elif [ "$PROB" -lt 35 ]; then BAND="YELLOW"; VERDICT="Targeted energy measures probable within 30 days; full lockdown unlikely"
elif [ "$PROB" -lt 60 ]; then BAND="ORANGE"; VERDICT="State-level energy emergencies likely; aviation curbs probable"
else                          BAND="RED";    VERDICT="Full nationwide lockdown probable within 30 days"
fi

# Outcome distribution by band
case "$BAND" in
  GREEN)  O1=70; O2=22; O3=6;  O4=2 ;;
  YELLOW) O1=45; O2=38; O3=13; O4=4 ;;
  ORANGE) O1=20; O2=38; O3=30; O4=12 ;;
  RED)    O1=5;  O2=20; O3=35; O4=40 ;;
esac

# Trigger watchlist booleans (true / false in JSON)
if [ "$T1_STATE" = "sustained_blockade" ] && [ "$HORMUZ_HITS" -ge 8 ]; then b_hormuz_30plus=true; else b_hormuz_30plus=false; fi
if [ "$SAUDI_CONFIRMED" -ge 1 ]; then b_saudi_strike=true; else b_saudi_strike=false; fi
b_brent_130=false
if [ -n "$BRENT" ]; then
  brent_check=$(awk -v p="$BRENT" 'BEGIN{ if (p+0 >= 130) print "yes" }')
  if [ "$brent_check" = "yes" ]; then b_brent_130=true; fi
fi
if [ "$US_GROUND" -ge 1 ]; then b_us_ground=true; else b_us_ground=false; fi
if [ "$SPR_LOW" -ge 1 ]; then b_spr_low=true; else b_spr_low=false; fi
if [ "$REFINERY_HIT" -ge 1 ]; then b_refinery=true; else b_refinery=false; fi

# Headline signal colours
sig_color() {  # args: score max  -> green/amber/red
  awk -v s="$1" -v m="$2" 'BEGIN{
    if (m == 0) { print "amber"; exit }
    r = s/m
    if (r < 0.30) print "green"
    else if (r < 0.66) print "amber"
    else print "red"
  }'
}
SIG_HORMUZ_C=$(sig_color "$T1_SCORE" 20)
SIG_BRENT_C=$(sig_color "$T3_SCORE" 15)
SIG_SPR_C=$(sig_color "$T5_SCORE" 15)
SIG_GOVT_C=$([ "$GOVT_DENIAL" -ge 1 ] && echo green || echo amber)
SIG_BRENT_VAL="\$${BRENT:-fetch failed}/bbl"
SIG_SPR_VAL=$([ "$T5_STATE" = "below_30_days" ] && echo "<30 days" || echo "~74 days")
SIG_GOVT_VAL=$([ "$GOVT_DENIAL" -ge 1 ] && echo "Firm" || echo "Stable")

NOW=$(ts_iso)
NEXT=$(ts_iso_plus6)

# ----- Extended data collection for rich dashboard -----

# WTI price
WTI=$(extract_wti_price)
BRENT_WTI_SPREAD=""
if [ -n "$BRENT" ] && [ -n "$WTI" ]; then
  BRENT_WTI_SPREAD=$(awk -v b="$BRENT" -v w="$WTI" 'BEGIN{printf "%.2f", b-w}')
fi

# 24h price delta — read previous Brent from current state.json before overwriting
PREV_BRENT=""
PREV_TS=""
if [ -f "$STATE" ]; then
  PREV_BRENT=$(grep -E '"brent_spot_usd"' "$STATE" | head -1 | sed -E 's/.*"brent_spot_usd"[[:space:]]*:[[:space:]]*([0-9.]+|null).*/\1/')
  PREV_TS=$(grep -E '"captured_at"' "$STATE" | head -1 | sed -E 's/.*"captured_at"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
fi
BRENT_DELTA_PCT=""
if [ -n "$BRENT" ] && [ -n "$PREV_BRENT" ] && [ "$PREV_BRENT" != "null" ]; then
  BRENT_DELTA_PCT=$(awk -v c="$BRENT" -v p="$PREV_BRENT" 'BEGIN{ if (p+0 > 0) printf "%+.2f", ((c+0 - p+0) / (p+0)) * 100 }')
fi

# News feed (live headlines with trigger tags)
NEWS_FEED=$(build_news_feed)

# Prediction markets (Manifold; Polymarket itself is regulatory-blocked from India)
manifold_or_empty() {
  local file="$1"
  if [ -f "$file" ] && head -c 1 "$file" 2>/dev/null | grep -q '\['; then
    cat "$file"
  else
    printf '[]'
  fi
}
build_prediction_markets() {
  printf '{\n'
  printf '    "primary_source_blocked": true,\n'
  printf '    "primary_source_name": "Polymarket",\n'
  printf '    "primary_source_block_reason": "Polymarket and Kalshi are regulatory-blocked from Indian ISPs (RBI / MeitY restrictions on real-money prediction markets). We surface equivalent prediction-market data from Manifold Markets, which is accessible and tracks the same underlying questions.",\n'
  printf '    "displayed_source_name": "Manifold Markets",\n'
  printf '    "displayed_source_url": "https://manifold.markets",\n'
  printf '    "iran_war": '
  manifold_or_empty "$TMP/manifold_iran.json"
  printf ',\n'
  printf '    "oil": '
  manifold_or_empty "$TMP/manifold_oil.json"
  printf ',\n'
  printf '    "india": '
  manifold_or_empty "$TMP/manifold_india.json"
  printf '\n  }'
}
PREDICTION_MARKETS=$(build_prediction_markets)

# ----- Static structured data (manually curated v1; auto-update later) -----

WAR_TIMELINE='[
    {"date":"2026-02-28","event":"US + Israel launch air war on Iran; supreme leader Ali Khamenei killed","severity":"critical","source":"Al Jazeera / CNN"},
    {"date":"2026-03-01","event":"Iran retaliates with missile + drone barrage on Israel, US bases, Gulf states","severity":"critical","source":"NPR / NBC"},
    {"date":"2026-03-05","event":"Iran announces Strait of Hormuz closure; 21+ merchant ship attacks begin","severity":"high","source":"Reuters"},
    {"date":"2026-03-09","event":"Bangladesh shuts universities, begins nationwide fuel rationing","severity":"high","source":"Al Jazeera"},
    {"date":"2026-03-12","event":"India Petroleum Min. Puri: 70% of crude imports already shifted off Hormuz","severity":"medium","source":"The Researchers"},
    {"date":"2026-03-27","event":"India cuts petrol excise ₹13→₹3, diesel ₹10→0; govt denies lockdown","severity":"medium","source":"Al Jazeera / DD News"},
    {"date":"2026-04-14","event":"IEA OMR: global supply down 10.1 mb/d to 97 mb/d — largest disruption in history","severity":"high","source":"IEA"},
    {"date":"2026-04-18","event":"Iran declares full Hormuz closure after ceasefire talks stall","severity":"high","source":"CNN"},
    {"date":"2026-04-21","event":"Trump extends ceasefire with Iran; US naval blockade of Iranian ports continues","severity":"medium","source":"CNN / NBC"},
    {"date":"2026-04-22","event":"Iran seizes 2 ships (MSC Francesca, Epaminondas) mid-ceasefire","severity":"high","source":"NPR / CNBC"},
    {"date":"2026-04-23","event":"Iran strikes hit UAE, Kuwait, Lebanon oil infra despite ceasefire","severity":"critical","source":"India Today"}
  ]'

REGIONAL_MONITOR='[
    {"country":"Bangladesh","status":"FULL ENERGY LOCKDOWN","measures":"Universities shut · nationwide fuel rationing + fuel cards · govt offices 9am-4pm · banks close 4pm · malls close 6pm · 3,000 fuel stations under security","severity":"red","import_dep_pct":95},
    {"country":"Pakistan","status":"4-DAY WORKWEEK","measures":"Government offices only · conserving electricity · no full lockdown yet","severity":"amber","import_dep_pct":82},
    {"country":"Sri Lanka","status":"FUEL QUOTAS","measures":"Rationing · restricted fuel sales · hoarding prevention","severity":"amber","import_dep_pct":99},
    {"country":"Myanmar","status":"FUEL QUOTAS","measures":"Restricted fuel sales","severity":"amber","import_dep_pct":85},
    {"country":"Bhutan","status":"FUEL QUOTAS","measures":"Restricted fuel sales","severity":"amber","import_dep_pct":100},
    {"country":"Philippines","status":"4-DAY WORKWEEK","measures":"Some government offices","severity":"amber","import_dep_pct":70},
    {"country":"South Africa","status":"FUEL QUOTAS","measures":"Anti-hoarding measures","severity":"amber","import_dep_pct":75},
    {"country":"Kenya","status":"FUEL QUOTAS","measures":"Rationing","severity":"amber","import_dep_pct":100},
    {"country":"Slovakia","status":"FUEL QUOTAS","measures":"Restricted sales","severity":"amber","import_dep_pct":82},
    {"country":"Slovenia","status":"FUEL QUOTAS","measures":"Restricted sales","severity":"amber","import_dep_pct":95},
    {"country":"India","status":"NO LOCKDOWN · fiscal absorption","measures":"Petrol excise ₹13→₹3 · diesel ₹10→0 · 74-day strategic cover · 70% crude off Hormuz · Russia +94% MoM","severity":"green","import_dep_pct":85}
  ]'

INDIA_ENERGY='{
    "imports_mix_pct": {"russia": 37, "iraq": 18, "saudi": 15, "uae": 9, "us": 7, "other": 14},
    "imports_total_mbd": 5.4,
    "imports_off_hormuz_pct": 70,
    "fuel_excise": {"petrol_inr_per_l": 3, "diesel_inr_per_l": 0, "excise_cut_date": "2026-03-27"},
    "strategic_reserves": {"days_cover": 74, "crude_days": 60, "commercial_days": 14, "lpg_days": 5},
    "govt_stance": "explicit lockdown denial · fiscal absorption · Russia surge · fuel price stabilised",
    "ministers_on_record": ["Hardeep Singh Puri (Petroleum)", "Nirmala Sitharaman (Finance)"],
    "consumer_impact": "LPG cylinder delivery delays reported in multiple cities · restaurant menu cuts · power scarcity spikes · aviation fuel curbs possible"
  }'

# Pretty trigger state name
T1_STATE_PRETTY=$(echo "$T1_STATE" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')

# ----- Write state.json via printf (avoids bash 3.2 heredoc paren bugs) -----
HEADLINE=""
if [ "$PROB" -lt 60 ]; then
  HEADLINE="India is rationing the next 30 days from above, not below"
else
  HEADLINE="India approaches full lockdown threshold"
fi

# Pre-escape evidence strings
H_EV=$(esc "$HORMUZ_EV")
S_EV=$(esc "$SAUDI_EV")
B_EV=$(esc "$T3_EV")
U_EV=$(esc "$US_EV")
P_EV=$(esc "$SPR_EV")
R_EV=$(esc "$REFINERY_EV")
N_EV=$(esc "$SEC_NOTES")
V_EV=$(esc "$VERDICT")
HD=$(esc "$HEADLINE")

build_state() {
  printf '{\n'
  printf '  "schema_version": 1,\n'
  printf '  "captured_at": "%s",\n' "$NOW"
  printf '  "next_update_at": "%s",\n' "$NEXT"
  printf '  "update_method": "automated_rss_market_scrape",\n'
  printf '  "lockdown_probability_pct": %d,\n' "$PROB"
  printf '  "verdict_band": "%s",\n' "$BAND"
  printf '  "verdict_label": "%s",\n' "$V_EV"
  printf '  "weighted_scores": {\n'
  printf '    "hormuz_status": {"score": %d, "max": 20, "state": "%s", "evidence": "%s"},\n' "$T1_SCORE" "$T1_STATE" "$H_EV"
  printf '    "iran_strikes_gulf": {"score": %d, "max": 20, "state": "%s", "evidence": "%s"},\n' "$T2_SCORE" "$T2_STATE" "$S_EV"
  printf '    "brent_price": {"score": %d, "max": 15, "state": "%s", "evidence": "%s"},\n' "$T3_SCORE" "$T3_STATE" "$B_EV"
  printf '    "us_ground_escalation": {"score": %d, "max": 15, "state": "%s", "evidence": "%s"},\n' "$T4_SCORE" "$T4_STATE" "$U_EV"
  printf '    "india_spr_days": {"score": %d, "max": 15, "state": "%s", "evidence": "%s"},\n' "$T5_SCORE" "$T5_STATE" "$P_EV"
  printf '    "indian_refinery_attack": {"score": %d, "max": 30, "state": "%s", "evidence": "%s"},\n' "$T6_SCORE" "$T6_STATE" "$R_EV"
  printf '    "secondary_signals": {"score": %d, "max": 10, "state": "computed", "evidence": "%s"}\n' "$SEC_DISPLAY" "$N_EV"
  printf '  },\n'
  printf '  "raw_score": %d,\n' "$RAW"
  printf '  "max_score": %d,\n' "$MAX"
  printf '  "normalized_pct": %d,\n' "$PROB"
  printf '  "headline_signals": [\n'
  printf '    {"id":"hormuz_status","label":"Strait of Hormuz","value":"%s","trend":"flat","color":"%s"},\n' "$T1_STATE_PRETTY" "$SIG_HORMUZ_C"
  printf '    {"id":"brent_price","label":"Brent Crude spot","value":"%s","trend":"watch","color":"%s"},\n' "$SIG_BRENT_VAL" "$SIG_BRENT_C"
  printf '    {"id":"india_spr_days","label":"India strategic cover","value":"%s","trend":"stable","color":"%s"},\n' "$SIG_SPR_VAL" "$SIG_SPR_C"
  printf '    {"id":"russia_imports","label":"Russia oil to India","value":"+94%% MoM Mar, 2.06 mb/d","trend":"up","color":"green"},\n'
  printf '    {"id":"lpg_storage","label":"India LPG strategic storage","value":"5 days only","trend":"flat","color":"red"},\n'
  printf '    {"id":"govt_position","label":"Govt lockdown denial","value":"%s","trend":"flat","color":"%s"}\n' "$SIG_GOVT_VAL" "$SIG_GOVT_C"
  printf '  ],\n'
  printf '  "trigger_watchlist_status": {\n'
  printf '    "hormuz_closed_30plus_continuous_days": %s,\n' "$b_hormuz_30plus"
  printf '    "iran_strikes_saudi_or_uae_oil_infra": %s,\n' "$b_saudi_strike"
  printf '    "brent_above_130_sustained_2_weeks": %s,\n' "$b_brent_130"
  printf '    "us_ground_war_escalation": %s,\n' "$b_us_ground"
  printf '    "india_spr_below_30_days": %s,\n' "$b_spr_low"
  printf '    "attack_on_indian_refinery": %s\n' "$b_refinery"
  printf '  },\n'
  printf '  "thesis": {\n'
  printf '    "headline": "%s",\n' "$HD"
  printf '    "outcomes_30d": {\n'
  printf '      "status_quo": %d,\n' "$O1"
  printf '      "targeted_measures": %d,\n' "$O2"
  printf '      "state_emergencies": %d,\n' "$O3"
  printf '      "full_lockdown": %d\n' "$O4"
  printf '    }\n'
  printf '  },\n'
  printf '  "oil_market": {\n'
  printf '    "brent_spot_usd": %s,\n' "${BRENT:-null}"
  printf '    "wti_spot_usd": %s,\n' "${WTI:-null}"
  printf '    "brent_wti_spread_usd": %s,\n' "${BRENT_WTI_SPREAD:-null}"
  printf '    "brent_delta_pct_since_last": %s,\n' "${BRENT_DELTA_PCT:-null}"
  printf '    "previous_brent_usd": %s,\n' "${PREV_BRENT:-null}"
  printf '    "previous_capture_at": "%s",\n' "${PREV_TS:-}"
  printf '    "eia_q2_forecast_brent_usd": 115,\n'
  printf '    "supply_disruption_mbd": 10.1,\n'
  printf '    "global_supply_mbd": 97,\n'
  printf '    "hormuz_share_of_supply_pct": 20\n'
  printf '  },\n'
  printf '  "war_timeline": %s,\n' "$WAR_TIMELINE"
  printf '  "regional_monitor": %s,\n' "$REGIONAL_MONITOR"
  printf '  "india_energy": %s,\n' "$INDIA_ENERGY"
  printf '  "news_feed": [%s\n  ],\n' "$NEWS_FEED"
  printf '  "prediction_markets": %s,\n' "$PREDICTION_MARKETS"
  printf '  "history_pointer": "history.jsonl"\n'
  printf '}\n'
}

if [ "$DRY_RUN" -eq 1 ]; then
  log "DRY RUN, would write:"
  build_state
  log "no files written"
else
  build_state > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  # Also write state.js for file:// dashboard (browsers block fetch() on file://)
  printf 'window.STATE = ' > "$STATE.js.tmp"
  cat "$STATE" >> "$STATE.js.tmp"
  printf ';\n' >> "$STATE.js.tmp"
  mv "$STATE.js.tmp" "$ROOT/state.js"

  printf '{"ts":"%s","prob":%d,"band":"%s","method":"automated_rss_market_scrape","note":"raw %d/%d; brent=%s; refinery_attack=%s"}\n' \
    "$NOW" "$PROB" "$BAND" "$RAW" "$MAX" "${BRENT:-na}" "$b_refinery" >> "$HISTORY"

  # Rebuild history.js as a JS array from history.jsonl (file:// safe loader)
  {
    printf 'window.HISTORY = [\n'
    awk 'NR>1{print ","} {print}' "$HISTORY"
    printf '];\n'
  } > "$ROOT/history.js"

  log "wrote state.json + state.js (prob=$PROB% band=$BAND raw=$RAW/$MAX) and appended history.jsonl + history.js"

  # Auto-deploy to Vercel (lockdownindia.vercel.app) after each successful update.
  # Token is stored in macOS Keychain — never in this script.
  if command -v security >/dev/null 2>&1; then
    VERCEL_TOKEN=$(security find-generic-password -a "$USER" -s "lockdown-indicator-vercel-token" -w 2>/dev/null || true)
    if [ -n "${VERCEL_TOKEN:-}" ]; then
      VERCEL_BIN=""
      for candidate in "/Users/$USER/.hermes/node/lib/node_modules/vercel/dist/index.js" "$(command -v vercel 2>/dev/null)"; do
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then VERCEL_BIN="$candidate"; break; fi
      done
      log "deploying to Vercel (lockdownindia.vercel.app)..."
      cd "$ROOT"
      if [ -n "$VERCEL_BIN" ] && echo "$VERCEL_BIN" | grep -q "\.js$"; then
        deploy_out=$(VERCEL_TELEMETRY_DISABLED=1 node "$VERCEL_BIN" deploy --prod --yes --name=lockdownindia --token="$VERCEL_TOKEN" 2>&1 | tail -3)
      else
        deploy_out=$(VERCEL_TELEMETRY_DISABLED=1 npx --yes vercel deploy --prod --yes --name=lockdownindia --token="$VERCEL_TOKEN" 2>&1 | tail -3)
      fi
      log "vercel deploy: $deploy_out"
    else
      log "WARN: no Vercel token in Keychain (key 'lockdown-indicator-vercel-token') — skipping deploy. To enable: security add-generic-password -a \$USER -s lockdown-indicator-vercel-token -w YOUR_TOKEN -U"
    fi
  fi
fi

log "=== update-indicator END ==="
