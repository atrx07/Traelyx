# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M6 is active. M6.1–M6.6 are complete. M6.7 requires explicit authorization.

## P0 — Wait at the M6.7 approval gate

1. M6.6 is complete: immutable local analysis, separate ranking consent, server validation, friend-only comparisons by vehicle class, account guards and withdrawal.
2. All 260 Flutter / 222 native tests, local and hosted SQL tests, and debug/release builds pass. GitHub CI run 36250004115 passes every gate for implementation commit `728254f`.
3. The normal signed-in app is restored. Physical synthetic analysis and live empty comparison reload pass; all 7,546 original raw files / 59,570 KiB remain. No personal trip was uploaded, and synthetic hosted/device data was removed.
4. Wait for explicit authorization before M6.7 Guardian pairing. Do not prepare or implement it while waiting.

## P1 — Preserve M5 boundaries

1. Keep `.tripdebug` precise-private and the redacted summary separately versioned, local-only, and free of route, raw samples, identifiers, and wall-clock time.
2. Keep retention non-automatic and deletion user-directed, consequence-labeled, recorder-safe, and fail-closed.
3. Keep the Tecno LH8n +0.03 g Z-axis bias as fixture calibration context only; do not add a production phone-specific offset.

## P2 — Analysis foundation

1. Keep M4.1–M4.7 contracts as versioned synthetic baselines until controlled/field fixtures justify new versions.
2. Preserve M3 raw/derived version provenance through later event, scoring, baseline, and explanation outputs.

## Blocked / deferred

- Production ML training is blocked on stable telemetry schema + sufficient data.
- OBD-II, navigation, iOS, and advanced local LLM features are explicitly post-MVP unless scope is changed by the maintainer.
