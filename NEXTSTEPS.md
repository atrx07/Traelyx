# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## P0 — Bootstrap

1. Use the resolved identity for future scaffolding: repository/Flutter project `traelyx` and Android namespace/application ID `io.github.atrx07.traelyx`.
2. Initialize Git repository and Flutter Android project.
3. Install root/nested `AGENTS.md` files from this pack.
4. Establish formatting, linting, test commands, and CI.
5. Add Drift/SQLite foundation and migration test harness.
6. Add Kotlin native bridge skeleton and foreground-service proof of concept.

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
