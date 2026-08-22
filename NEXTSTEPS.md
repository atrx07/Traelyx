# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M4.5 completed on 2026-08-22. Stop at the numbered-substep approval gate; M4.6 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M4.6.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Keep the Tecno LH8n +0.03 g Z-axis bias as fixture calibration context only; do not add a production phone-specific offset.

## P1 — M4.6 pending

1. Do not inspect or implement personal/vehicle baseline lifecycle until M4.6 receives explicit authorization.
2. Preserve M4.5's Drive DNA version, caller-supplied comparable-cohort boundary, per-dimension full/verified eligibility, robust medians, dispersion audit, source trip IDs/versions, and configuration snapshot as governed lifecycle inputs.

## P2 — Analysis foundation

1. Add personal/vehicle baseline lifecycle and explanation data only in their canonical authorized M4 substeps.
2. Keep M4.1 thresholds as versioned synthetic baselines until controlled/field fixtures justify a new version.
3. Preserve M3 raw/derived version provenance through later event and scoring outputs.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
