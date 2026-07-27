# Phase 0 Plan — Validation Spike

Target: home server (Mac Mini, existing stack: Claude Code, MCP servers,
LiteLLM, Home Assistant). No mobile code. Python 3.12 + cron/launchd —
boring on purpose; the novelty budget is spent on threat logic, not
infrastructure.

**Status: awaiting approval. No implementation until approved.**

## Components (build order)

### 0. Shared foundation
- `schema/config.schema.json` — the config artifact contract:
  jurisdiction map, agency handles + verified-date + verification
  evidence, news handles, chatter geo-terms, R1/R2 boundaries (2 mi /
  5 mi haversine from home point), backtest record, standing hazard
  profile. JSON Schema, validated on every read and write.
- `audit/` — append-only JSONL run logs: every prompt, search issued,
  raw result, decision, exclusion reason, and per-provider API spend.
- `costmeter` — per-run spend tracking (resolves Critical Unknown 1
  empirically).
- **Success criterion:** a hand-written invalid config is rejected with
  a named field error; a sample run produces a log from which the full
  decision path can be reconstructed without re-running.

### 1. Provisioning agent (`provision/`)
CLI: `provision --lat --lon [--label]` → validated config JSON.
- **Deterministic first:** lat/lon → county/place via Census geocoder +
  FCC Area API (both free, no key); county → agency list from curated
  seed data (start: the two test metros, format generalizes).
- **Agent last-mile:** verify each agency's X handle against actual
  account content — recent posts must match the agency's jurisdiction
  and voice. A handle is `verified` only with evidence recorded
  (post excerpt + date), else `unresolved` with reason. Never from
  model memory (the two-wrong-sheriffs failure). Find 3–5 established
  local news outlets; generate chatter geo-terms (roads, neighborhoods,
  landmarks ≤ ~5 mi).
- **Backtest (blocking):** find one agency-confirmed incident from the
  past 7 days in the coverage area; prove the config's search plan
  surfaces it. Miss = named coverage gap; config does not ship.
- **Standing hazard profile generator:** Tier A sources only (CDC, WHO,
  State Dept, USGS, NWS climatology, park services, state health).
  Every entry must carry prevalence (number or honest "rare") +
  severity + the 1–2 behaviors that remove most risk. Entries missing
  any of the three are rejected by a code-level validator, not by
  reviewer vigilance. Built first for the HOME area (judged against
  ground truth the user knows), then one contrasting region.
- **Success criterion:** spec criterion (a) — validated configs for two
  different metros with zero hand-editing; every handle carries
  verification evidence; backtest recorded in the config.

### 2. Daily runner (`daily/`)
Scheduled job: config in → report out → push if level > 0.
- **Code, not improvisation:** tier caps (A any level, B ≤ 3, C never
  rates), R1/R2 geo-math, level thresholds, search budgets with hard
  stop, output template — all deterministic. LLM (via LiteLLM) does
  relevance judgment, pattern recognition, summarization only.
- **Source order per CRITICAL_UNKNOWNS.md:** free Tier A feeds (NWS,
  FDA/USDA recalls, agency web/RSS) first; budgeted X/live-search for
  X-only agencies and the chatter sweep.
- Two scopes: LOCAL (agencies, news, chatter, conditions) and NATIONAL
  (transmission-mechanism filter — named mechanism or it's noise, and
  the noise reason must name the mechanism considered and why it
  fails).
- Mandatory-check gate in code: recalls/contamination/drug-safety/
  disease items cannot be excluded without a logged reach-confirmation
  search (the egg-recall failure, made structurally impossible).
- Gaps accounting: every planned search lands in exactly one bucket
  (checked-nothing-posted / checked-nothing-relevant / could-not-reach).
- Report renders the quiet-verified state: receipts, gaps, noise
  ledger, quiet-streak counter. Empty sections stay empty.
- **Delivery: ntfy** (self-hosted or ntfy.sh). Justification: zero
  account/bot setup, one HTTP POST, native iOS app for later, priority
  levels map to threat levels, trivially replaceable behind a
  `notify()` seam. Telegram adds a bot dependency for formatting we
  don't need — reports over ~4 KB land as a link/attachment either way.
- **Success criterion:** spec criterion (b) — 14 consecutive daily runs,
  zero confabulated items on spot-audit against logs; plus instrumented
  cost/user/day reported with go/no-go against the $0.05 target.

### 3. Health monitor (`health/`)
Weekly job against the audit logs + live checks.
- Handle liveness (resolves + posted within sane window), level
  distribution drift (>15% non-zero local days; 0% for 90 days →
  canary), identical consecutive gaps = dead source.
- **Synthetic canary:** pick one known agency-confirmed event from the
  week; confirm the pipeline sees it (the silent-source-death failure).
- On failure: scoped re-provision of the broken source only.
- **Success criterion:** spec criterion (c) — a deliberately broken
  handle (test fixture) is detected within one weekly cycle and
  produces a scoped re-provision request, not a full rebuild.

### 4. Evals (`evals/`)
Regression cases from the documented failures, run on any prompt or
model change:
- wrong-sheriff-handle (handle discovery must produce evidence or
  `unresolved`)
- hedged-noise-item ("possible ground stops" style output → fail)
- egg-recall exclusion (recall with confirmed local retail reach
  excluded as "no mechanism" → fail; must rate ≥ 1)
- padding (category items, filler in empty sections → fail)
- coordinated-amplification (identical phrasing/many accounts/short
  window counted as corroboration → fail)
- **Success criterion:** all eval cases pass before any 14-day run
  counts toward criterion (b).

## Phase 0 exit criteria (from spec, restated testable)
(a) two metros provisioned, zero hand-edits · (b) 14 consecutive clean
daily runs, spot-audited · (c) canary catches a planted broken handle in
one cycle · (d) home hazard profile: every entry has prevalence +
severity + mitigation, every number traceable to a Tier A source in the
audit log · (e — added) instrumented cost/user/day reported against the
$0.05 target.

## Questions before implementation
1. **Home point:** spec says NW Austin — confirm, and provide the actual
   home lat/lon (or a nearby offset point you're comfortable using).
2. **Second test metro** for generality: any preference? (Contrasting
   climate/fauna wanted for the hazard profile — e.g., Seattle, Denver,
   or Miami. Default: Denver.)
3. **LLM/search keys:** which do you have or want to fund — xAI API
   (live X search), X API v2 pay-per-use, or neither yet? Phase 0 can
   start on free Tier A feeds + your existing LiteLLM models and add X
   coverage when keys exist; the backtest will honestly report X-only
   agencies as a coverage gap until then.
4. **Delivery endpoint:** ntfy.sh topic (simplest) or self-hosted ntfy
   on the Mac Mini? Any objection to ntfy at all?
5. **Repo home:** does allclear live long-term in this repo (currently
   a scratch Xcode project) or should it move to a dedicated repo before
   Phase 1?
