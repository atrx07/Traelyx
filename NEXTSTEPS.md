# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M3.7 completed on 2026-08-16. Stop at the substep approval gate; M3.8 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M3.8.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Keep the Tecno LH8n +0.03 g Z-axis bias as fixture calibration context only; do not add a production phone-specific offset.

## P1 — M3.8 pending

1. Add the governed deterministic fixture regression corpus for straight, corner, brake, pothole, phone-move, and GNSS-loss cases.
2. Exercise the M3.1–M3.7 pipeline with explicit expected channels, missingness, confidence, eligibility, and replay outcomes.
3. Keep private route/raw fixture evidence out of Git and logs; commit only governed synthetic or anonymized fixtures permitted by repository policy.

## P2 — Analysis foundation

1. Implement fixture regression in the separately authorized M3.8 substep.
2. Implement deterministic baseline events in M4.
3. Feed versioned confidence and eligibility into M4 event/scoring logic when those milestones activate.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
