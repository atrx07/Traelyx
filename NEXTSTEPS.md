# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M3.6 completed on 2026-08-15. Stop at the substep approval gate; M3.7 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M3.7.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Preserve raw evidence, M3.5 provenance, and M3.6 eligibility unchanged; replay reduction must retain gaps, missingness, and confidence rather than visually smoothing unsupported data.

## P1 — M3.7 pending

1. Add a reduced synchronized display timeline over the versioned derived/confidence frames.
2. Preserve exact replay timestamps, missing intervals, source provenance, and metric eligibility while reducing display density deterministically.
3. Keep replay sampling separate from raw acquisition and analysis sampling; do not rewrite or persist precise source evidence in M3.7.

## P2 — Analysis foundation

1. Implement replay reduction and fixture regression through separately authorized M3 substeps.
2. Implement deterministic baseline events in M4.
3. Feed versioned confidence and eligibility into M4 event/scoring logic when those milestones activate.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
