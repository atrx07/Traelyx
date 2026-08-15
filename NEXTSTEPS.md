# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M3.4 completed on 2026-08-15. Stop at the substep approval gate; M3.5 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M3.5.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Preserve raw evidence and M3.4 frame provenance unchanged; M3.5 must propagate missingness, degradation, stale course, and unobservable orientation instead of fabricating derived motion values.

## P1 — M3.5 pending

1. Add versioned filtered speed and longitudinal/lateral/vertical acceleration channels over supported M3.4 frames.
2. Add jerk, yaw/heading-change, and moving/stopped channels with explicit units, timestamps, and source provenance.
3. Keep every channel deterministic and auditable, with quality/missingness propagated from M3.1–M3.4 evidence.

## P2 — Analysis foundation

1. Implement derived channels, confidence, replay reduction, and fixture regression through separately authorized M3 substeps.
2. Implement deterministic baseline events in M4.
3. Implement telemetry confidence and the replay data pipeline in their canonical M3 substeps.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
