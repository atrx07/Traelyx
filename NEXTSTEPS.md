# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M3.5 completed on 2026-08-15. Stop at the substep approval gate; M3.6 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M3.6.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Preserve raw evidence and M3.5 derived-channel provenance unchanged; M3.6 must weaken or exclude low-quality evidence rather than fabricate confidence or precision.

## P1 — M3.6 pending

1. Add interpretable GNSS, IMU, calibration, orientation, device-movement, and clock-confidence subcomponents.
2. Aggregate downstream eligibility without claiming more precision than the evidence supports.
3. Preserve versioned reasons and upstream provenance so low-quality data is weakened or excluded auditably and deterministically.

## P2 — Analysis foundation

1. Implement confidence, replay reduction, and fixture regression through separately authorized M3 substeps.
2. Implement deterministic baseline events in M4.
3. Implement telemetry confidence and the replay data pipeline in their canonical M3 substeps.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
