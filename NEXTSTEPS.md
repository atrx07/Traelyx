# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M2.8 was explicitly authorized on 2026-08-12. Implement and validate only the first real-drive fixture/export proof, then stop at the approval gate before M3.

## P0 — M2.8 active

1. Restart phase 1 from the clean Tecno baseline: install/permission readiness, then rehearse Start → locked/background recording → Stop/finalize → isolated export/inspect/cleanup.
2. Hand the phone back, stop monitoring while the maintainer performs the normal 30–60 minute motorcycle drive, then inspect the returned fixture without committing precise route data.
3. Record aggregate continuity, corruption/restart, battery, and cleanup evidence; do not treat the recovered 15m42s diagnostic ride as the formal M2.8 fixture.

## P1 — Recorder milestone

1. Record the first formal privacy-safe real-device `.tripdebug` fixture.
2. Verify a locked-screen 30–60 minute trip survives intact and remains exportable/replayable.
3. Document pocket-carried motorcycle placement as uncontrolled/body-relative orientation; do not use this fixture to claim mounted vehicle-frame calibration or scoring validity.

## P2 — Analysis foundation

1. Implement timestamp alignment and basic filtering.
2. Implement orientation/calibration path.
3. Implement deterministic baseline events.
4. Implement telemetry confidence.
5. Implement replay data pipeline.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
