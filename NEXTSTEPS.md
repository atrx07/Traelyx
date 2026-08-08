# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Approval gate

Roadmap step 0.6 and milestone M0 are complete. Do not activate or implement Stage 1 until the user explicitly authorizes the next step.

## P0 — Application foundation (after authorization)

1. Activate the Stage 1 execution plan.
2. Begin roadmap step 1.1, design tokens/theme.
3. Continue through navigation, settings, schema, migrations, and diagnostics only with the required approval between numbered steps.

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
