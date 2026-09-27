# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M6 is active. M6.1–M6.7 are complete. M6.8 Guardian alerts includes the authorized live-evaluation and background-push prerequisites.

The urgent long-trip crash repair is verified on the phone: the 45m27s recording is recovered, all 4,290 raw chunks are unchanged, and cold startup succeeds. Private recovery backups remain local and ignored. Resume the existing M6.8 scope after reporting this repair; no new milestone is authorized.

## P0 — Define and implement M6.8 Guardian alerts

1. M6.7 pairing, account/revision guards, permissions, blocking and transient invite handling are implemented. All 273 Flutter tests, local SQL suites, analysis and debug/release builds pass.
2. The approved production migration and rollback-only synthetic tests pass; all four deployment checks are true and no fixtures remain.
3. The final app update preserves 7,546 raw files / 59,570 KiB. All GitHub CI gates pass in run 36265444147 for `d8b3823`. Physical inert opening, live reload, defaults and cancelled invite review pass. Sign-in is preserved; no real invitation, alert or trip upload was created. M6.7 is complete. M6.8 was subsequently authorized.

4. The isolated experimental evaluator/lifecycle and optional Firebase adapter pass 253 native tests, builds and physical inert-startup QA. Complete consent, durable persistence, recorder integration and background push before enabling it. Firebase `traelyx-e28ff` exists under `atrx07` on Spark with the Android app registered and FCM v1 enabled. The verified client config is staged at `.dart_tool/firebase/google-services.json` and Git-ignored; backend credentials remain pending. See the active plan for delivery/privacy gates.

The M6.8 server draft now passes local SQL suites for owner/device capabilities,
current permissions, deduplication, quota/expiry, retry exhaustion and revocation.
Approved production deployment and rollback-only hosted checks pass (all four
true); implementation CI run 36317565469 is green. Native encrypted outbox
storage passes 264 tests and isolated physical Keystore QA. Connect it to consent
UI, recorder integration and Edge/FCM dispatch; those remain pending. Firebase client CI run 36316643251 is green; no registrations or
alerts have been sent.

The explicit-load alert inbox and guarded opening are implemented and pass 20
Guardian tests, analysis and a configured debug build. Physical screen/hosted
empty reload passes after restoring phone connectivity. Requests have a bounded
20-second timeout. Continue native consent activation/account teardown and
dispatch integration. No push or driver activation is enabled by the inbox. The two-stage
native activation coordinator passes 275 native tests and a configured debug
build; connect it to Auth/bridge/consent and recording before exposing activation.

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
