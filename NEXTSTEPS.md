# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M3 completed on 2026-08-21. Stop at the milestone approval gate; M4 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M4 and M4.1.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Keep the Tecno LH8n +0.03 g Z-axis bias as fixture calibration context only; do not add a production phone-specific offset.

## P1 — M4 pending

1. Implement the M4.1 deterministic event taxonomy for strong acceleration/braking, lateral load, abrupt transitions, road impact, and phone movement.
2. Consume versioned M3 confidence and eligibility without allowing missing or invalid evidence to become an event claim.
3. Keep event logic deterministic, auditable, local-first, and independent of ML or mandatory network services.

## P2 — Analysis foundation

1. Implement deterministic baseline events in the separately authorized M4 milestone.
2. Add merge/debounce, integrity, scoring, Drive DNA, baseline lifecycle, and explanation data only in their canonical authorized M4 substeps.
3. Preserve M3 raw/derived version provenance through later event and scoring outputs.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
