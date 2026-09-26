# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M6 is active. M6.1–M6.3 are complete. M6.4 is authorized and in progress.

## P0 — M6.4 final CI validation and persistence

1. M6.3 is complete: explicit compact-summary consent, account-bound durable queue, safe retries, local schema-2 upgrade, and hosted owner-only access are validated.
2. All 216 Flutter tests, analysis, generated/schema checks, repository validation, local/hosted SQL checks, physical upgrade/Keep local checks, and debug/release builds pass. GitHub CI run 36224500242 also passes native Kotlin and all remaining gates.
3. The phone remains signed in; four trips remain local with zero queued/synced, and all 7,546 raw telemetry files are preserved. No personal trip upload was performed.
4. M6.4 implementation, 235 Flutter tests, hosted access/account-guard checks, final guarded private saves/cache restore, and local debug/release builds pass. Finish CI and completion persistence; stop before M6.5.

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
