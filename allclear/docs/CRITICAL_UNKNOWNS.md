# Critical Unknowns — Resolution (researched 2026-07-27)

The spec names three unknowns that must be resolved before Phase 0 code.
Findings below; each carries a Phase 0 verification step because vendor
pricing pages block automated fetches and third-party figures can drift.

## 1. X / live-search data access and unit cost

**The binding constraint is real, and naive designs blow the budget.**
Target from the spec: ≤ ~$0.05 per user per day.

Current pricing (triangulated across multiple 2026 sources; verify against
the official consoles with real keys as the first Phase 0 task):

| Route | Price | Naive daily cost |
|---|---|---|
| xAI Live Search | $25 / 1,000 sources ($0.025/source) | 20 sources/run ≈ **$0.50/day — 10× over budget** |
| xAI agentic web/X search (newer billing) | $5 / 1,000 calls ($0.005/call) | 10 calls/run ≈ **$0.05/day — at the line** |
| X API v2 pay-per-use (Feb 2026 default; no free tier) | $0.005/post read, 2M reads/mo cap | 10 handles × 5 posts ≈ **$0.25/day — 5× over** |

**Resolution — restructure the source mix so X is a supplement, not the
backbone:**

1. **Free Tier A feeds first.** Most Tier A content never needs X: NWS
   API (weather/flood, free), FDA/USDA recall APIs (free — directly
   covers the tested egg-recall failure), CDC/state health feeds, agency
   websites/RSS/press-release pages, Nixle/alert services. Deterministic
   fetchers, zero marginal cost.
2. **X reserved for what only X has:** agencies that post only there, and
   the chatter sweep (which is Tier C display-only anyway — the cheapest
   content to skip when budget-capped). Incremental reads (`since_id`)
   on low-volume agency accounts, hard per-run call budget in code.
3. **Instrument, don't estimate.** Every Phase 0 run logs actual API
   spend per provider. The 14-day validation reports real cost/user/day.

**Go/no-go rule:** if instrumented cost exceeds $0.05/user/day after the
free-feed restructure, surface it before Phase 1 — per the spec, the
daily model gets rethought rather than quietly eaten as margin.

## 2. Breach-monitoring API terms (HIBP)

**Resolved — viable and cheap at Phase 0/1 scale.**

- Breached-account search API: entry tier ~$4–4.50/month at 10 requests/
  minute; tiers scale by rate limit (high-volume tiers run $300+/month,
  irrelevant at our scale). Annual billing discounts exist.
- March 2026 terms update restricts third-party use and bans building a
  substantially-similar breach database. **Our use — notifying a user
  about breaches of their own verified email — is the intended use case
  and unaffected.** We must not cache/aggregate breach data into our own
  searchable corpus; store only per-user hit records.
- Pwned Passwords API remains free/unlimited (k-anonymity) if ever wanted.
- Breach monitoring is Feature 5 / Phase 1 — **no Phase 0 work needed**
  beyond this terms check. Re-verify exact tier price at signup.

## 3. Liability posture

**Resolved as a design posture (decision, not research):**

- **Information product, not an emergency service.** Stated verbatim
  in-product, in onboarding, and in every report footer: not monitored
  24/7, not a substitute for 911, may miss events.
- **Calibration is the core product risk.** Both failure directions are
  liability: missed events invite blame; over-alerting at scale causes
  harm and is the anti-thesis. The threat-logic rubric, tier caps, and
  anti-confabulation rules are the mitigation, and every one maps to a
  test (see PHASE0_PLAN.md evals).
- **Full audit logs are non-negotiable.** Every run persists complete
  reasoning, searches issued, sources returned, and exclusion reasons —
  the record that the system did the work, and the defense that it did.
- **No prescriptive emergency instructions.** Countermeasures stay
  low-cost/behavioral ("lock vehicles," "avoid X road"), never tactical
  guidance.
- Formal ToS/disclaimer language is a Phase 1 (App Store) task; Phase 0
  is single-user and needs only the report footer.
