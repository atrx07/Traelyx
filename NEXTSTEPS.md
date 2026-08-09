# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M1.3 is complete and validated locally, on the Android 14 Tecno device, and in GitHub Actions. Do not begin M1.4 without explicit user authorization.

## P0 — M1 Application Foundation

1. Await explicit authorization for M1.4 Drift schema version 1.
2. After authorization, implement and validate M1.4 as one bounded substep.
3. Continue through migrations and diagnostics only with the required approval between numbered substeps.

## P1 — Recorder milestone

1. Define telemetry binary/chunk encoding from `TELEMETRY_SPEC.md`.
2. Implement GNSS acquisition with authoritative timestamps and quality fields.
3. Implement IMU acquisition with authoritative timestamps.
4. Implement crash-safe buffering and trip lifecycle.
5. Record first real-device `.tripdebug` fixture.
6. Verify a locked-screen 30–60 minute trip survives intact.

## P2 — Analysis foundation

1. Implement timestamp alignment and basic filtering.
2. Implement orientation/calibration path.
3. Implement deterministic baseline events.
4. Implement telemetry confidence.
5. Implement replay data pipeline.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
