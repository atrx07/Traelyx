# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M6 is active. M6.1–M6.5 are complete. M6.6 is authorized and in progress,
including the explicitly approved local-analysis and ranking-validation prerequisites.

## P0 — Complete M6.6 safe leaderboards

1. M6.5 is complete: mutual requests, participant-only name snapshots, account/revision guards, removal/blocking, expiry/cooldown, and request quotas are validated.
2. All 244 Flutter tests, analysis, local/hosted SQL suites, repository checks, physical reload/no-match checks, and debug/release builds pass. GitHub CI run 36244993247 passes generated/schema checks, native Kotlin, and all remaining gates for implementation commit `d79c5ae`.
3. The phone remains signed in with its private metadata and local trips. All 7,546 raw telemetry files / 59,570 KiB are preserved. No real friend requests or personal trip uploads were sent; hosted synthetic fixtures were rolled back and cleanup verified.
4. M6.6 local analysis, separate consent and server validation are implemented. All 260 Flutter / 222 native tests, local and hosted SQL tests, and debug/release builds pass. Synthetic phone analysis and live empty comparison reload pass; final GitHub CI and completion persistence remain. M6.7 stays gated.

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
