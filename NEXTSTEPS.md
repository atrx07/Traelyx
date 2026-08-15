# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M3.3 completed on 2026-08-15. Stop at the substep approval gate; M3.4 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M3.4.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Preserve raw values/status unchanged; M3.4 must consume versioned calibration and retain explicit orientation/device-movement uncertainty without relabeling device axes as vehicle axes prematurely.

## P1 — M3.4 pending

1. Detect device orientation and movement that invalidates prior orientation assumptions.
2. Fix and document the world/navigation convention before transforming device-frame evidence.
3. Produce device/world/vehicle frame outputs only with explicit transform quality and unsupported-state evidence.

## P2 — Analysis foundation

1. Implement the orientation/frame-transform path, then derived channels through separately authorized M3 substeps.
2. Implement deterministic baseline events in M4.
3. Implement telemetry confidence and the replay data pipeline in their canonical M3 substeps.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
