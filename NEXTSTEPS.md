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

The approved retry-worker migration `20260927020000_guardian_dispatch_worker.sql`
is deployed after green CI run 36334866638 (`85ece8f`). All eight local SQL suites
and the exact production rollback-fixture bundle pass, with all four checks true.
The isolated Edge/FCM adapter passes 18 synthetic Deno tests and full CI run
36336437458. Its deployed function remains disabled; hosted missing-secret and
valid-secret calls returned 401 and 503 without claiming or sending. A dedicated
one-permission Google sender exists, but organization policy
`iam.disableServiceAccountKeyCreation` blocked its JSON key. Resolve backend FCM
authentication with a reviewed method before enabling dispatch. No policy was
weakened. See `docs/reference/GUARDIAN_DISPATCH_SETUP.md`. Scheduler setup,
native Auth/consent/recorder integration and physical end-to-end delivery
remain required.

The separate capability Edge function passes eleven local Deno tests and fixed
RPC/response checks, plus full CI run 36572524947. After concrete production
approval, it was deployed with processing disabled and its own legacy JWT gate
off. A direct unauthenticated synthetic POST returned 503 `capability_disabled`.
Native activation, registration and synthetic receipt still precede any enable.
See `docs/reference/GUARDIAN_CAPABILITY_SETUP.md`.

A dormant Android activation bridge serializes encrypted-vault calls on one
process worker and checks the current boot count. Flutter Auth now binds the
local owner on startup/account changes, and sign-out requires local cleanup.
Native and all 284 Flutter tests, analysis, Android lint and the debug APK
build pass; source CI run 36583140285 is green. A configured, data-preserving
physical update and cold launch preserved sign-in and local trip history, with
Guardian still inactive. Next implement explicit driver consent and
server-confirmed activation before attaching the recorder or enabling dispatch.
Physical account switching and background behavior remain unverified.

The Auth decorator briefly made six optional cloud providers unavailable
because they required the concrete Supabase gateway type. A delegated optional
client source fixes their provider graph. All 286 Flutter tests, analysis and a
configured APK pass; a data-preserving phone update completed Guardian's
read-only hosted reload with sign-in and local history intact. Full source CI
run 36743035626 passed. Continue the activation UI; physical account-switch
behavior remains open.

The dormant two-stage Flutter activation service now validates the signed-in
server lease before a local encrypted commit and fails closed on owner changes.
Six synthetic tests, all 292 Flutter tests, analysis and a debug APK build pass.
It has no UI caller or recorder hook. Verify CI, then connect an explicit
mount/forward-axis consent flow and test native `begin`/`commit` on the phone
without sending alerts. An old server session may live until its eight-hour
expiry if a late request cannot be revoked; local authority remains unavailable.

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
