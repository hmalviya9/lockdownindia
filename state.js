window.STATE = {
  "schema_version": 1,
  "captured_at": "2026-04-24T06:59:21Z",
  "next_update_at": "2026-04-24T12:59:21Z",
  "update_method": "automated_rss_market_scrape",
  "lockdown_probability_pct": 16,
  "verdict_band": "YELLOW",
  "verdict_label": "Targeted energy measures probable within 30 days; full lockdown unlikely",
  "weighted_scores": {
    "hormuz_status": {"score": 8, "max": 20, "state": "uncertain", "evidence": "no fresh closure headlines this cycle"},
    "iran_strikes_gulf": {"score": 5, "max": 20, "state": "no_strikes_yet", "evidence": "no Saudi/UAE strike headlines"},
    "brent_price": {"score": 4, "max": 15, "state": "price_fetch_failed", "evidence": "could not extract Brent price from web sources"},
    "us_ground_escalation": {"score": 3, "max": 15, "state": "naval_only", "evidence": "no US ground escalation headlines"},
    "india_spr_days": {"score": 0, "max": 15, "state": "above_60_days", "evidence": "Govt baseline 74-day cover; no contradiction in headlines"},
    "indian_refinery_attack": {"score": 0, "max": 30, "state": "none", "evidence": "no Indian refinery attack headlines"},
    "secondary_signals": {"score": 0, "max": 10, "state": "computed", "evidence": "neutral"}
  },
  "raw_score": 20,
  "max_score": 125,
  "normalized_pct": 16,
  "headline_signals": [
    {"id":"hormuz_status","label":"Strait of Hormuz","value":"Uncertain","trend":"flat","color":"amber"},
    {"id":"brent_price","label":"Brent Crude spot","value":"$fetch failed/bbl","trend":"watch","color":"green"},
    {"id":"india_spr_days","label":"India strategic cover","value":"~74 days","trend":"stable","color":"green"},
    {"id":"russia_imports","label":"Russia oil to India","value":"+94% MoM Mar, 2.06 mb/d","trend":"up","color":"green"},
    {"id":"lpg_storage","label":"India LPG strategic storage","value":"5 days only","trend":"flat","color":"red"},
    {"id":"govt_position","label":"Govt lockdown denial","value":"Stable","trend":"flat","color":"amber"}
  ],
  "trigger_watchlist_status": {
    "hormuz_closed_30plus_continuous_days": false,
    "iran_strikes_saudi_or_uae_oil_infra": false,
    "brent_above_130_sustained_2_weeks": false,
    "us_ground_war_escalation": false,
    "india_spr_below_30_days": false,
    "attack_on_indian_refinery": false
  },
  "thesis": {
    "headline": "India is rationing the next 30 days from above, not below",
    "outcomes_30d": {
      "status_quo": 45,
      "targeted_measures": 38,
      "state_emergencies": 13,
      "full_lockdown": 4
    }
  },
  "oil_market": {
    "brent_spot_usd": null,
    "wti_spot_usd": null,
    "brent_wti_spread_usd": null,
    "brent_delta_pct_since_last": null,
    "previous_brent_usd": 106.44,
    "previous_capture_at": "2026-04-24T01:13:12Z",
    "eia_q2_forecast_brent_usd": 115,
    "supply_disruption_mbd": 10.1,
    "global_supply_mbd": 97,
    "hormuz_share_of_supply_pct": 20
  },
  "war_timeline": [
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
  ],
  "regional_monitor": [
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
  ],
  "india_energy": {
    "imports_mix_pct": {"russia": 37, "iraq": 18, "saudi": 15, "uae": 9, "us": 7, "other": 14},
    "imports_total_mbd": 5.4,
    "imports_off_hormuz_pct": 70,
    "fuel_excise": {"petrol_inr_per_l": 3, "diesel_inr_per_l": 0, "excise_cut_date": "2026-03-27"},
    "strategic_reserves": {"days_cover": 74, "crude_days": 60, "commercial_days": 14, "lpg_days": 5},
    "govt_stance": "explicit lockdown denial · fiscal absorption · Russia surge · fuel price stabilised",
    "ministers_on_record": ["Hardeep Singh Puri (Petroleum)", "Nirmala Sitharaman (Finance)"],
    "consumer_impact": "LPG cylinder delivery delays reported in multiple cities · restaurant menu cuts · power scarcity spikes · aviation fuel curbs possible"
  },
  "news_feed": [
  ],
  "history_pointer": "history.jsonl"
}
;
