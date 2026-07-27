# BUILD PROMPT — Personal Security Intelligence App (working name: pick one)

You are building a location-based personal security intelligence product.
It began as a set of hand-tuned Grok automation prompts that generate
daily threat reports for one user in NW Austin; those prompts have been
tested against real runs and their failure modes are known. Your job is
to productize the validated design.

Read this entire document before writing any code. Then produce a plan
for Phase 0 and wait for approval before implementing.

---

## PRODUCT THESIS

Gavin de Becker-style threat assessment, automated per user location.
The core insight from testing: users don't need alerts — they need
JUSTIFIED CONFIDENCE THAT QUIET IS REAL. Level 0 with receipts is the
product. The system is strongly biased against alarm; its credibility
comes from reporting NOTHING on ordinary days and proving it did the
work.

The anti-thesis, equally important: the moment the app manufactures
content to fill a slot, it becomes the noise it promised to filter.
Every retention mechanic must be evidence the system worked — never
filler.

---

## ARCHITECTURE — THREE LOOPS

### Loop 1 — Provisioning Agent (once per location, expensive)

Runs at onboarding and on sustained location change (>25 miles, not a
coffee shop). Output is a CONFIG ARTIFACT (JSON), not a report.

Deterministic-first, agent-second:
1. DETERMINISTIC: lat/long → county/jurisdiction via Census/FCC APIs →
   agency list from curated county-to-agency data. Code answers this,
   not an LLM.
2. AGENT (last mile only): for each agency, find and VERIFY its official
   X handle (active, official, posting). Find 3-5 established local news
   outlets. Generate neighborhood-level chatter geo-terms (roads,
   neighborhoods, landmarks within ~5 mi).
3. BACKTEST (mandatory before config ships): find one agency-confirmed
   incident from the past 7 days anywhere in the coverage area. Verify
   the config's search plan would have surfaced it. Caught = validated.
   Missed = named coverage gap; fix before shipping the config.

Known failure this design exists to prevent: during testing, an LLM
confidently returned two different wrong sheriff handles across two
runs, and misclassified a working account as unresolvable. Handle
discovery must be verified against actual account content, never
trusted from model memory.

Config schema (minimum): jurisdiction map; agency handles with
verified-date; news handles; chatter geo-terms; R1/R2 geo boundaries
(R1 ≈ 2 mi, R2 ≈ 5 mi from home point); backtest record.

4. STANDING HAZARD PROFILE (fourth provisioning output, cached, slow
   refresh ~quarterly). Environmental and regional risks that are
   CONDITIONS, not events — they never appear in a 24h search window
   but dominate actual risk: disease vectors (ticks/Lyme, mosquitoes,
   rabies reservoirs), dangerous fauna with real encounter rates, water
   and food safety, environmental hazards (flash flood, heat, rip
   currents, altitude, air quality patterns), and region-typical crime
   patterns. Sources are stable Tier A: CDC travel health notices, WHO,
   State Department, USGS, NWS climatology, park services, state health
   departments.

   HARD REQUIREMENT — base rates, not lists. Every hazard entry must
   carry: prevalence (with a number or an honest "rare"), severity, and
   the one or two behaviors that eliminate most of the risk. "Saltwater
   crocodiles: 1-2 fatal attacks/year nationally, near-zero if you
   don't swim in unsigned waterways" is the product. A catalog of
   everything that can bite you is a fear product and is rejected in
   review. The de Becker calibration discipline applies to hazard
   content exactly as it does to threat levels.

### Loop 2 — Daily Runner (cheap, boring, server-side)

Executes the config's search plan, applies threat logic, emits the
report. The rating rubric, tier caps, and output template are CODE and
structured prompts — never agent improvisation. Deterministic decisions
(routing, thresholds, geo-math, tier caps) live in code; the LLM does
judgment only (relevance, pattern recognition, summarization).

Runs server-side on a scheduler. iOS background execution is unreliable
by design; the phone is display + location + push only.

Two report scopes per user per day:
- LOCAL: agency accounts, news, chatter sweep, conditions
- NATIONAL: transmission-mechanism filtering (see threat logic)

Push notification ONLY when level > 0. A daily "nothing happened" ping
trains deletion.

### Loop 3 — Health Monitor (weekly)

- Every config handle still resolves and posted within a sane window
- Level distribution check: local >15% non-zero days = threshold
  drifted; 0% for 90 days = possibly blind, run a canary
- Gaps identical across consecutive days = dead source
- SYNTHETIC CANARY: pick one known agency-confirmed event anywhere in
  the coverage area this week; confirm the pipeline sees it. This
  detects silent source death — the failure mode that cost half of one
  county's coverage during testing without any error being raised.
- On failure: scoped re-provision of the broken source, not a full
  rebuild.

---

## THREAT LOGIC (validated through live testing — port faithfully)

### Levels
0 NONE (expected most days) · 1 AWARENESS · 2 ELEVATED (1-2 low-cost
countermeasures) · 3 HIGH (active risk at home area) · 4 IMMINENT.
Calibration anchors: 0 is the most common correct output; 3 a few times
a year; 4 rare.

### Source tiers (hard caps, enforced in code)
- A: government/agency primary — can set any level
- B: established news — max level 3
- C: unverified (individual posts, Nextdoor, Ring, scanners,
  aggregators) — NEVER sets or raises the level. Display-only
  ("Chatter"), may corroborate an A/B finding. Only path to a rated
  finding: same theme from 3+ independent observers across 3+ separate
  days, flagged as a candidate with "agency confirmation absent" stated.

### Local relevance: geography AND pattern
Geography: R1/R2 only; beyond R2 excluded unless a hazard physically
reaches R1/R2 or a threat targets the user specifically.
Pattern (need one): same method 3+ in 30 days; residential targeting
trending; method transferable to the user's home; directed threat;
hazard degrading safety at home.
Never rate: crimes between people known to each other; single incidents
without pattern; metro-wide crime news; opinion/politics; engagement
volume as evidence.

### National relevance: transmission mechanism
Report only with a named mechanism: physical reach · infrastructure the
user depends on (grid, water, fuel, telecom, aviation, supply chain,
payments) · digital exposure (their accounts/devices) · travel routes ·
regulatory with direct near-term local effect. "Big story" and "could
escalate" are not mechanisms.

### Anti-confabulation rules (each one exists because the failure
occurred in testing)
- ANTI-PADDING: every reported item must be specific, real, named,
  dated, actually encountered. Never a category ("political stories").
  Never hedged ("possible ground stops"). Empty sections are correct
  output.
- NOISE REASONS: an exclusion must name the mechanism considered and
  why it fails — never a bare "no transmission mechanism." (Tested
  failure: an active egg recall with confirmed Texas retail
  distribution was excluded with an unexamined "no mechanism" claim.)
- MANDATORY CHECK BEFORE EXCLUDING: recalls, contamination, drug
  safety, disease clusters require one search confirming geographic/
  retailer reach before exclusion. Reaches local retail = minimum
  level 1, never noise.
- GAPS ACCOUNTING: every planned search lands in exactly one bucket —
  checked-nothing-posted / checked-nothing-relevant / could-not-reach.
  Compressed display: name exceptions, count the rest. "Unresolvable"
  only if the account genuinely does not exist.
- Search budgets with a hard stop; finishing the report beats
  completeness; budget exhaustion is reported in Gaps.
- Chatter filters: drop if no named location+time; no local account
  history; single post requoted (count original observers, not
  reposts); unverifiable imagery; >24h stale with no agency follow-up.
- Coordinated amplification (identical phrasing, many accounts, short
  window) is manufactured, not corroborated — drop and log it.
- No urgency language without numbers. Ambiguity stays ambiguous.

---

## FEATURES (all retention mechanics are evidence-of-work)

1. QUIET-VERIFIED (core, free — presentation of existing work).
   Level 0 rendered with receipts: sources checked, agencies posting
   normally, baseline note. Quiet-streak counter ("241 quiet days in
   your area"). This is the main screen.

2. NOISE LEDGER (daily). "What's loud today and why none of it reaches
   you." Each item: named story + mechanism considered + why it fails.
   The daily anti-anxiety product; the news cycle supplies material.

3. TEACHABLE MOMENTS (event-anchored, irregular by design). When a real
   event is excluded near the threshold, attach a short lesson: why it
   didn't clear, what a clearing pattern would look like. Never
   generated without a triggering event.

4. FINITE CURRICULUM (6-8 week de Becker sequence: pre-incident
   indicators, JACA, intuition vs checklists). Has an end and a
   completion state. Explicitly NOT an infinite tip feed.

5. PERSONAL BREACH MONITORING. User email/domain watched against breach
   disclosures (HIBP-class API). Event-driven; each hit is genuinely
   theirs. The transmission-mechanism "digital" channel made per-user.
   First feature requiring new engineering.

6. TRAVEL MODE — two layers. (a) Standing hazard profile for the
   destination (see provisioning agent output 4): built once, cached,
   covers the risks tourists never research — disease vectors,
   dangerous wildlife, water safety, environment — every entry with
   base rates and the behavior that removes the risk. (b) Live layer:
   the existing pipeline pointed at the destination for current events,
   weather, outbreaks, disruptions. Paid-tier candidate.

6b. LOCATION BROWSER (Phase 1 screen; the unifying mechanism). Home is
   just a destination with a persistent config, so one screen serves
   three entry points: CURRENT LOCATION (one tap → standing profile +
   live layer for wherever the user is standing — answers "what should
   I actually worry about here?" with no trip planning), HOME (the
   daily report plus the home area's own standing hazard profile —
   most users have never seen the real snake/flood/vector risk of
   their own county), and SAVED/PLANNED places. Teachable-moment
   content anchors to these profiles geographically, not only to
   events.

7. MONTHLY BASELINE REPORT. "Your area vs typical, 90 days." Doubles as
   calibration transparency justifying the Level 0s.

Explicitly rejected — do not build: daily generic tips, gamified safety
checklists, neighborhood safety scores, any content slot that must fill
regardless of events.

---

## PHASES

### Phase 0 — Validation spike (build this first, no mobile code)
Runs on a home server (Mac Mini, existing agent stack available:
Claude Code, MCP servers, LiteLLM, Home Assistant).
- Provisioning agent as a script: location in → verified config JSON
  out, including the backtest. Test it on a location OTHER than the
  home area to prove generality.
- Daily runner as a scheduled job against the chosen LLM/search API.
- Delivery: push (ntfy/Telegram/etc — builder's choice, justify it).
- Health monitor as a weekly job with the canary.
- Standing hazard profile generator: produce the profile for the HOME
  area first — it forces the profile format to be real, and the user
  can judge it against ground truth they actually know. Then one
  additional contrasting region (different climate/fauna) to prove
  generality.
- Log every run's full reasoning and search results for audit.
Success criteria: (a) provisioning produces a validated config for two
different metros without hand-editing; (b) 14 consecutive daily runs
with zero confabulated items (spot-audit against logs); (c) canary
detects a deliberately broken handle within one weekly cycle; (d) home
hazard profile passes the base-rate rule on every entry — any entry
without prevalence + severity + mitigating behavior fails review — and
contains zero fabricated statistics (every number traceable to a Tier A
source in the audit log).

### Phase 1 — iOS app (only after Phase 0 criteria pass)
Swift/SwiftUI client: onboarding + location permission, main screen =
quiet-verified state, report views, location browser (current location
/ home / saved), push. Server keeps all three loops. Curriculum and
noise ledger in-app. Breach monitoring opt-in with clear data handling.

### Phase 2 — Full travel mode (planned trips + live layer), monthly
baseline, paid tier.

---

## CRITICAL UNKNOWNS — resolve before writing Phase 0 code

1. X/live-search data access and unit cost. The consumer Grok app
   bundles X search; an API product must use xAI's API live search or
   X's API directly. VERIFY current pricing. If cost per user per day
   exceeds ~$0.05, the daily model needs rethinking — surface this
   before building. This is likely the binding constraint on the whole
   product.
2. Breach-monitoring API terms (HIBP commercial or equivalent).
3. Liability posture: a safety app that misses events invites blame;
   one that over-alerts causes harm at scale. Calibration is the core
   product risk, not polish. Full audit logs are non-negotiable.
   Include appropriate disclaimers; this is an information product, not
   an emergency service — say so in-app.

## ENGINEERING CONSTRAINTS

- Deterministic decisions in code; LLM for judgment only.
- Smallest change that fully solves; no speculative abstraction; no
  config options without a current need.
- Every threat-logic rule above maps to a test. The anti-confabulation
  rules especially: build eval cases from the documented failures
  (wrong handles, hedged noise items, the recall exclusion) and run
  them against any prompt or model change.
- State a testable success criterion before implementing each
  component. Fail loud: skipped steps and skipped tests are reported,
  never silent.

Begin with: (1) your resolution of the three critical unknowns, (2) a
Phase 0 plan with component breakdown and success criteria, (3) any
questions where missing context would change the design. Wait for
approval before implementing.
