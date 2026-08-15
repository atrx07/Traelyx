# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M3.2 completed on 2026-08-15. Stop at the substep approval gate; M3.3 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M3.3.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Preserve raw values/status unchanged; decoding must remain lossless, resampling must retain provenance, and GNSS filtering must retain every original fix with explicit decisions and evidence.

## P1 — M3.3 pending

1. Add versioned stationary and bias calibration for the accelerometer and gyroscope.
2. Expose calibration quality and insufficiency explicitly instead of hiding unreliable or unavailable evidence.
3. Preserve the Tecno fixture's raw accelerometer status and measured bias evidence unchanged.

## P2 — Analysis foundation

1. Implement calibration, then the orientation/frame-transform path through separately authorized M3 substeps.
2. Implement deterministic baseline events in M4.
3. Implement telemetry confidence and the replay data pipeline in their canonical M3 substeps.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
