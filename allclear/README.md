# allclear

Location-based personal security intelligence. Gavin de Becker-style threat
assessment, automated per user location, strongly biased against alarm.
The product is justified confidence that quiet is real: Level 0 with
receipts.

## Status

**Phase 0 — planning.** No pipeline code yet; awaiting plan approval.

- Spec: [docs/BUILD_PROMPT.md](docs/BUILD_PROMPT.md) (source of truth)
- Critical unknowns resolution: [docs/CRITICAL_UNKNOWNS.md](docs/CRITICAL_UNKNOWNS.md)
- Phase 0 plan: [docs/PHASE0_PLAN.md](docs/PHASE0_PLAN.md)

## Structure (planned)

Phase 0 runs on a home server (Mac Mini) as three scheduled jobs — no
mobile code:

- `provision/` — one-shot per location: verified config JSON + standing
  hazard profile, with mandatory backtest
- `daily/` — scheduled runner: executes the config's search plan, applies
  threat logic (deterministic tier caps in code), emits report, pushes
  only when level > 0
- `health/` — weekly monitor with synthetic canary
- `evals/` — regression cases built from the documented testing failures

## Non-negotiables

- Deterministic decisions in code; LLM for judgment only.
- Empty sections are correct output. No filler, ever.
- Every reported item: specific, real, named, dated, actually encountered.
- Full audit logs on every run.
- Information product, not an emergency service — stated in-product.
