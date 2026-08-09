# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Approval gate

Roadmap substep M1.2 is complete. Do not implement M1.3 until the user explicitly authorizes the next substep.

## P0 — M1 Application Foundation

1. After authorization, begin M1.3 local settings with explicit secure/non-secure boundaries.
2. Continue through schema, migrations, and diagnostics only with the required approval between numbered substeps.

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
