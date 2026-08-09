# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M1.5 is implemented and validated locally and on the Android 14 Tecno device. Complete the checkpoint push and exact-HEAD GitHub Actions gate; do not begin M1.6.

## P0 — M1 Application Foundation

1. Push the bounded M1.5 migration-harness checkpoint and verify exact-HEAD GitHub Actions.
2. Mark M1.5 complete only after all required gates pass.
3. Stop and await explicit authorization for M1.6 diagnostics shell.

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
