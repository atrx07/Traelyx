# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M4.4 completed on 2026-08-22. Stop at the numbered-substep approval gate; M4.5 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M4.5.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Keep the Tecno LH8n +0.03 g Z-axis bias as fixture calibration context only; do not add a production phone-specific offset.

## P1 — M4.5 pending

1. Do not inspect or implement the Drive DNA subsystem until M4.5 receives explicit authorization.
2. Preserve M4.4's fixed dimension IDs, availability/provisional/full states, contribution audit, fixed-point values, upstream versions, and config snapshot as governed baseline inputs.

## P2 — Analysis foundation

1. Add Drive DNA, baseline lifecycle, and explanation data only in their canonical authorized M4 substeps.
2. Keep M4.1 thresholds as versioned synthetic baselines until controlled/field fixtures justify a new version.
3. Preserve M3 raw/derived version provenance through later event and scoring outputs.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
