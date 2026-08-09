# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M1 and all six Application Foundation substeps are complete and validated locally, on the Android 14 Tecno device, and in GitHub Actions. Do not activate or implement M2 without explicit user authorization.

## P0 — M2 activation gate

1. Await explicit authorization to activate M2 Native Recording Engine.
2. After authorization, create/activate the M2 execution plan and begin only M2.1.
3. Preserve the approval gate between every numbered M2 substep.

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
