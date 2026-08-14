# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M3.1 completed on 2026-08-14. Stop at the substep approval gate; M3.2 remains pending explicit maintainer authorization.

## P0 — Approval gate

1. Await explicit maintainer authorization before activating or preparing M3.2.
2. Preserve the accepted private M2.8 fixture locally; do not place its route or raw telemetry in Git or logs.
3. Preserve raw values/status unchanged; M3.1 decoding must remain lossless, resampling must retain provenance, and M3.2 must express filtered-out GNSS evidence explicitly.

## P1 — M3.2 pending

1. Add versioned GNSS input classification for valid, low-accuracy, gap, and impossible-jump evidence.
2. Add confidence-aware distance accumulation that does not count obvious stationary noise or rejected jumps.
3. Preserve original GNSS samples and attach auditable reasons to every exclusion or degradation.

## P2 — Analysis foundation

1. Implement GNSS filtering/distance, then the orientation/calibration path through separately authorized M3 substeps.
2. Implement deterministic baseline events in M4.
3. Implement telemetry confidence and the replay data pipeline in their canonical M3 substeps.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
