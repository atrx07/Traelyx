# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M2 is active and M2.5 Flutter↔Kotlin bridge integration is complete and validated locally and on the Android 14 Tecno device. Do not activate or implement M2.6 without explicit user authorization.

## P0 — M2.6 approval gate

1. Await explicit authorization for M2.6 contextual permissions/onboarding.
2. After authorization, implement only M2.6 against the active M2 execution plan.
3. Preserve the approval gate between every numbered M2 substep.

## P1 — Recorder milestone

1. Add contextual permission onboarding.
2. Add broader service recovery/finalization and native-to-Drift index tests.
3. Record the first real-device `.tripdebug` fixture.
4. Verify a locked-screen 30–60 minute trip survives intact.

## P2 — Analysis foundation

1. Implement timestamp alignment and basic filtering.
2. Implement orientation/calibration path.
3. Implement deterministic baseline events.
4. Implement telemetry confidence.
5. Implement replay data pipeline.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
