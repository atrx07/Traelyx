# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M6 is active. M6.1–M6.7 are complete. M6.8 Guardian alerts includes the authorized live-evaluation and background-push prerequisites.

## P0 — Define and implement M6.8 Guardian alerts

1. M6.7 pairing, account/revision guards, permissions, blocking and transient invite handling are implemented. All 273 Flutter tests, local SQL suites, analysis and debug/release builds pass.
2. The approved production migration and rollback-only synthetic tests pass; all four deployment checks are true and no fixtures remain.
3. The final app update preserves 7,546 raw files / 59,570 KiB. All GitHub CI gates pass in run 36265444147 for `d8b3823`. Physical inert opening, live reload, defaults and cancelled invite review pass. Sign-in is preserved; no real invitation, alert or trip upload was created. M6.7 is complete. M6.8 was subsequently authorized.

4. The isolated experimental evaluator/lifecycle passes 246 native tests and a debug build. Complete consent, durable persistence, recorder integration and background push before enabling it. Firebase `traelyx-e28ff` exists under `atrx07` on Spark with the Android app registered and FCM v1 enabled. The verified client config is staged at `.dart_tool/firebase/google-services.json` and Git-ignored; backend credentials remain pending. See the active plan for delivery/privacy gates.

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
