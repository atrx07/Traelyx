# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M2.8 was explicitly authorized on 2026-08-12. Implement and validate only the first real-drive fixture/export proof, then stop at the approval gate before M3.

## P0 — M2.8 active

1. Place the updated Tecno under exposed sky and rehearse Start until the UI confirms first GPS fix plus both motion streams; the obstructed-position `finding GPS` hold is already device-validated.
2. Stop/finalize that rehearsal and confirm the separate test evidence does not alter the preserved 3,615-chunk diagnostic field attempt.
3. Repeat the normal 30–60 minute locked-screen motorcycle drive, then inspect its private fixture; do not accept the first 41-minute attempt because GNSS was absent for its first 11m20.2s.

## P1 — Recorder milestone

1. Record the first acceptance-quality privacy-safe real-device `.tripdebug` fixture after visible first-fix confirmation.
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
