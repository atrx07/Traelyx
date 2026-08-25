# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M5.5 completed on 2026-08-25. Stop at the numbered-substep approval gate; M5.6 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before inspecting, implementing, or substantially preparing M5.6.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Keep the Tecno LH8n +0.03 g Z-axis bias as fixture calibration context only; do not add a production phone-specific offset.

## P1 — M5.6 pending

1. Add replay animation only after authorization and make every camera, marker/path, event, pause, scrub, and speed behavior consume M5.5's single deterministic clock.
2. Preserve M5.5's gap-safe marker interpolation, independent route/event failure, coordinate-free graph/semantics, manual accessibility actions, and offline operation.
3. Preserve M5.4's bounded native route boundary and do not expose M3.7 replay channels or add a new native bridge without a separately governed contract.

## P2 — Analysis foundation

1. Keep M4.1–M4.7 contracts as versioned synthetic baselines until controlled/field fixtures justify new versions.
2. Preserve M3 raw/derived version provenance through later event, scoring, baseline, and explanation outputs.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
