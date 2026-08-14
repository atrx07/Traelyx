# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M2 and M2.8 completed on 2026-08-14. Stop at the milestone approval gate; M3 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M3.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Preserve raw Tecno accelerometer values/status unchanged; calibration/confidence work belongs to M3.

## P1 — M3 pending

1. Implement the versioned raw decoder/resampler only after authorization.
2. Add GNSS sanity filtering and distance accumulation with explicit quality handling.
3. Add calibration, orientation/frame confidence, and derived channels without rewriting M2 raw evidence.

## P2 — Analysis foundation

1. Implement timestamp alignment and basic filtering.
2. Implement orientation/calibration path.
3. Implement deterministic baseline events.
4. Implement telemetry confidence.
5. Implement replay data pipeline.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
