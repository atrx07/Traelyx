# Traelyx — Priority Queue

> Keep this file concise. Detailed tasks belong in active execution plans.

## Current gate

M6 is active. M6.1–M6.7 are complete. M6.8 Guardian alerts includes the authorized live-evaluation and background-push prerequisites.

The urgent long-trip crash repair is verified on the phone: the 45m27s recording is recovered, all 4,290 raw chunks are unchanged, and cold startup succeeds. Private recovery backups remain local and ignored. Resume the existing M6.8 scope after reporting this repair; no new milestone is authorized.

## P0 — Define and implement M6.8 Guardian alerts

1. M6.7 pairing, account/revision guards, permissions, blocking and transient invite handling are implemented. All 273 Flutter tests, local SQL suites, analysis and debug/release builds pass.
2. The approved production migration and rollback-only synthetic tests pass; all four deployment checks are true and no fixtures remain.
3. The final app update preserves 7,546 raw files / 59,570 KiB. All GitHub CI gates pass in run 36265444147 for `d8b3823`. Physical inert opening, live reload, defaults and cancelled invite review pass. Sign-in is preserved; no real invitation, alert or trip upload was created. M6.7 is complete. M6.8 was subsequently authorized.

4. The isolated experimental evaluator/lifecycle and optional Firebase adapter pass 253 native tests, builds and physical inert-startup QA. Complete consent, durable persistence, recorder integration and background push before enabling it. Firebase `traelyx-e28ff` exists under `atrx07` on Spark with the Android app registered and FCM v1 enabled. The verified client config is staged at `.dart_tool/firebase/google-services.json` and Git-ignored; the restricted backend sender credential is installed. See the active plan for delivery/privacy gates.

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
one-permission Google sender exists. Its replacement key was installed in
Supabase Edge secrets on 2026-10-03 with a matching hosted digest. The
temporary local file and scoped Supabase token were removed, and inherited
Google key-creation enforcement and original organization access were restored.
Both functions remain disabled; live OAuth and delivery are untested. See
`docs/reference/GUARDIAN_DISPATCH_SETUP.md`. Scheduler setup,
native Auth/consent/recorder integration and physical end-to-end delivery
remain required.

The separate capability Edge function passes eleven local Deno tests and fixed
RPC/response checks, plus full CI run 36572524947. After concrete production
approval, it was deployed with processing disabled and its own legacy JWT gate
off. A direct unauthenticated synthetic POST returned 503 `capability_disabled`.
Native activation, registration and synthetic receipt still precede any enable.
See `docs/reference/GUARDIAN_CAPABILITY_SETUP.md`.

The isolated signed-in recipient device RPC gateway now passes adversarial
account-race and contract tests, the 302-test Flutter suite, analysis and a
configured debug build. Its registration path still has no caller; explicit
sign-out now uses its revocation path. Next bind recipient consent
to encrypted native device state and Firebase token registration, with fail-closed
account-change cleanup, before wiring the receiver or enabling delivery.

The separate native recipient receipt vault now passes seven focused tests and
an isolated physical Keystore proof, with no production caller or device row.
The dormant native coordinator/bridge and Flutter owner port now erase local
recipient authority on account change/sign-out; scoped physical and production
channel probes pass with the normal app restored. Next connect the short-lived
recipient review, signed-in server gateway and opt-in Firebase token lifecycle;
revoke the server device and delete the provider token on account change/opt-out
before any receiver or notification is enabled.

The dormant Firebase adapter now has a durable, account-free cleanup marker
before token acquisition and explicit restart-safe token/installation deletion.
Native tests, lint, configured build and scoped first-phone proof pass without
requesting a token. Provider cleanup is now attached to native owner changes;
complete the consented register/revoke transaction with the guarded server RPC;
the second phone is needed only for later two-account delivery validation.

Native owner binding now waits for marker-aware Firebase deletion when leaving
an opted-in owner, while preserving a valid same-owner restart. Tests cover
switching, failed deletion, orphaned state and timeout; the first-phone startup
remains inert. Explicit sign-out revocation is addressed below; unexpected
Auth-loss reconciliation and the reviewed opt-in transaction remain pending.

Explicit sign-out now revokes a stored recipient device through the signed-in
server RPC before native cleanup and Auth release. Offline revocation cancels
sign-out; a later local deletion retry does not repeat a confirmed server
revoke. Concurrent sign-out and account replacement fail closed. All 311 Flutter
tests, analysis, configured build and first-phone inert
startup pass. Next solve unexpected Auth-loss reconciliation and the reviewed
opt-in transaction before any production device can register or receive push.

An isolated encrypted native revoke journal now preserves only exact server-row
IDs for a later same-owner retry after unexpected Auth loss. Bounded capacity,
restart/tamper behavior, Android lint, configured build and a first-phone proof
pass. Native account-change capture is now connected below; guarded signed-in
reconciliation is still missing. No device registration or token was requested.
Native owner cleanup now writes the journal before erasing a receipt; failed
writes deny rebinding, and replacement receipts also retain the previous row
identity. First-phone proofs and CI pass. Same-owner signed-in server
reconciliation and exact ticket confirmation are now wired; finish full gates
and full CI passed. The dormant pre-registration bridge now reserves an exact
revoke ticket before future token acquisition; same-owner retry cleans up a
matching local receipt after server confirmation. Finish full gates and validate
a hosted synthetic row before considering any real opt-in. No production token
or device row exists.
The native receipt commit now requires that exact reservation and denies
overwriting an existing receipt. Full CI passed. A dormant reviewed-consent
transaction now sequences ticket reservation, injected token acquisition,
guarded server registration and local receipt commit with failure cleanup.
Full CI passed. The dormant native token adapter requires that exact reservation
and rechecks it after Firebase responds. A foreground status/review/withdrawal
UI is wired but opt-in remains paused in normal builds. Full CI passed. A
rollback-only recipient fixture passed CI, and the maintainer reported all
three hosted registration/retry/withdrawal checks true with no error. The
debug-only pilot APK and full CI pass. A separately consented first-phone
opt-in and withdrawal passed app/local checks; the maintainer reported hosted
device counts moving from 1/1 to 0/0. Browser control prevented direct SQL
observation. Next validate guarded alert processing and receiver behavior
before two-phone delivery. A dormant native incoming-push preflight now denies
messages without a matching local recipient receipt; server permission,
notification and receipt handling remain unwired. Both Edge functions and
actual sending remain off.

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
Six synthetic tests, all 292 Flutter tests, analysis, a debug APK and full CI
run 36747071540 pass. It has no UI caller or recorder hook. An isolated physical
proof passed native `begin`/`commit`/`disable` against a temporary encrypted
vault with no server call; full CI run 36750081398 passed. A separate physical
alternate-entrypoint probe passed production Flutter-to-Android binding,
proposal/abort, synthetic local commit, active snapshot and disable without a
server call. The normal configured app was restored with sign-in and the
recovered trip present; Guardian remains inactive. Connect explicit
mount/forward-axis consent, then validate hosted confirmation before attaching
recording. An old server session
may live until its eight-hour expiry if a late request cannot be revoked; local
authority remains unavailable.

A dormant review dialog now collects a selected device-forward axis and three
separate confirmations for a rigid mount, detection limits and limited sharing.
The activation service rejects incomplete, stale or future review before native
proposal. All 294 Flutter tests, analysis and a configured debug build pass.
Full CI run 36861945539 passed.
It is not connected to the Guardian screen or server yet; add an honest
activation control only after recipient opt-in and delivery gates are ready.

A separate dormant recipient notification review now requires acknowledgement
of experimental detection/delivery limits and Firebase registration disclosure.
It returns only short-lived foreground consent; it does not initialize Firebase
or register a device. All 296 Flutter tests, analysis and a configured debug
build pass. Next connect account-bound recipient opt-in to native token lifecycle
and guarded server registration, then validate account switching, background
receipt and revocation before exposing the control.

An isolated Android parser rejects push envelopes outside the exact
data-only version-1 contract; the full native unit suite passes. The native
preflight checks local registration, and a bounded receiver now requires a positive
server receipt plus a second local check before generic notification text.
The first phone opens after a data-preserving default-off update with its
withdrawn registration absent. Fixed data-free notice routing passed cold and
warm first-phone link checks and the signed-out widget gate; it does not reload
or acknowledge alerts. Next verify cold-process FCM callback behavior, negative
and positive hosted receipt paths, background/lock-screen copy and actual
notice taps with synthetic delivery before enabling Guardian processing or
using the second phone. Both Edge functions remain disabled.

The approved capability-only hosted denial window passed all seven checks on
2026-10-05. The flag was restored to explicit false, its digest verified, and
every POST again returned 503; all four Guardian state tables were directly
counted empty before and after. Durable duplicate claims and deterministic
receiver lifecycle checks now pass all 351 native tests, Android lint, a
configured default-off APK and the isolated first-phone Keystore proof.
Recipient plaintext v2 reads v1 and keeps up to 1,024 encrypted delivery IDs
without eviction; a failed display after claim can suppress a notice (ADR-0027).
Next validate actual cold-process FCM callback and controlled synthetic
receipt/notification behavior before positive two-phone delivery. Routine
ingestion, dispatch, recorder monitoring and second-phone delivery remain gated.

Both duplicate-claim source CI runs passed (37319268272 / 37319919712).
The maintainer freshly registered the first phone on the review pilot; app/local
checks and a direct hosted aggregate verify 1 device/1 unexpired device, with
zero sessions/events/deliveries and both function flags false. The next narrower
gate is the isolated positive receipt/retry check in
`docs/reference/GUARDIAN_RECEIPT_CHECK.md`: its staging/cleanup scripts pass all
ten local SQL suites and negative guards, and the phone probe compiles.
The concrete production window and cleanup were approved. The first attempt
found an Android regex initialization failure before HTTPS, then closed and
cleaned safely. The literal-brace repair passes 352 native tests, lint/build,
repository checks and the physical Android contract proof. Full repair source
CI run 37479031254 (`94eadff`) passed, then the approved hosted receipt and
idempotent retry passed on the first phone. Hosted `device_received` was
confirmed; local authority stayed unchanged and Firebase inactive. The window
was closed, synthetic records removed, and final counts were 0/1/1/0/0 with
both flags false. Sign-in and registration remain intact.
The approved first-phone background FCM send/notice/tap checks passed on
2026-10-06; see `docs/reference/GUARDIAN_PUSH_CHECK.md`. Each of two separately
authorized windows sent once: the maintainer cleared the first notice before
tap and explicitly requested the repeat with fresh synthetic IDs. Provider
acceptance, hosted receipt, generic/private notice and actual tap to unloaded
Guardian pass; tap did not acknowledge details viewed. Both flags are false,
both fixtures removed, temporary worker values retired and files deleted.
Final counts 0/1/1/0/0; sign-in and registration preserved. Full source CI
37484921020 (`76c02a7`) passes all jobs, eleven SQL suites and four probe tests;
352 native tests pass. The subsequent approved cold-process window with fresh
IDs 711–715 also passed: process absent/not force-stopped immediately before
one send, then hosted receipt, generic notice and actual tap to unloaded
Guardian without a viewed acknowledgement. Both functions closed at 16:07:27
UTC; disabled probes, worker retirement and cleanup pass. Final counts remain
0/1/1/0/0 with saved sign-in/registration preserved. Next verify
expiry/revocation and actual duplicate FCM under concrete reviewed windows,
then recorder hookup and two-phone gates. No second phone is needed yet;
routine sending remains disabled. No M7 work is authorized.
The reviewed locked/offline pair in `GUARDIAN_RECEIVER_CHECK.md` passed on
2026-10-07: one send and receipt per case, actual tap to unloaded Guardian and
no viewed acknowledgement. Copy was hidden until unlock. An initial offline
preflight aborted without sending; the corrected bounded-disconnect check passed
with a fresh fixture. Both functions are false and network settings restored.
Worker retirement/old-value 401/local deletion and both synthetic cleanups pass;
final hosted counts are 0/1/1/0/0. Fresh changed-phone checks confirm retained
sign-in/native registration, no recorder and reviewed network settings. Next review
expiry/revocation and actual duplicate FCM, then recorder integration and the
two-phone gates. The second phone is not needed yet.
The concrete follow-up `GUARDIAN_REJECTION_CHECK.md` proposes four sends across
duplicate-after-dismissal/restart, synthetic server expiry after queuing, and
guarded driver disconnect after queuing. Exact-marker SQL controls and the new
isolated regression suite pass full CI 37646111095 (`6734a3b`), including all
twelve SQL suites and app/native/build gates. Ignored copies reverse-verify and
bounded offline-hold helper syntax passes. The reviewed duplicate window sent its
first message successfully, but the fixture expired before requeue; no second send
occurred. Both flags are false, the worker retired and cleanup verified with
0/1/1/0/0. Review a fresh-ID contiguous two-send window within the existing event
lifetime, preserving durable claims; actual duplicate suppression is unverified.
Expiry/disconnect need separate review and reliable callback evidence.
Require specific hosted review before any new enable/send/control/network
change; both functions remain disabled and no temporary worker is active locally.
Replacement fixture 771–775 received once but had no observed notice or vault change;
the duplicate phase was aborted and cleanup/worker retirement verified on 2026-10-08.
Data-free debug receiver tracing passes 357 native tests, lint, configured build
and data-preserving signed-in startup. Full source CI 37803704159 (`4aecd2e`)
passes every job. A reviewed single diagnostic message 781–785 subsequently passed
callback/receipt/claim/post stages, one Android notice, hosted attempts=1/not viewed,
and actual notice tap to signed-in Guardian. Both flags are false; worker retirement
and approved synthetic cleanup pass with final counts 0/1/1/0/0. The prior missing
notice did not reproduce;
receipt-response failure remains a hypothesis, with no confirmed cause or fix.
The 791–795 repeat also stopped after its successful first receipt/notice/tap:
the guarded requeue refused because the existing lifetime buffer had elapsed.
Both flags are false, the worker retirement and approved cleanup are verified
on 2026-10-09; final hosted counts 0/1/1/0/0. Actual duplicate suppression is pending.
Use the bounded `tool/guardian_duplicate_phone.mjs` operator helper to batch the
first phone transition immediately after the confirmed send, then perform the
unchanged guarded requeue and one duplicate send. Twelve operator tests and
physical read-only preflight pass; its first live phase passes with 811–815 below.
Require source CI, a fresh-ID pair review and action-time enable confirmation
before running those live phases. Preserve durable claims and the existing event,
requeue and enable limits. Expiry/disconnect, recorder and two-phone gates follow;
the second phone is not needed yet.
Full source CI 37944918981 (`16cf9a5`) now passes all jobs. Fresh 801–805 ignored
stage/control/cleanup copies reverse-verify as UUID-only substitutions. That
approved pair sent its first message, with positive receiver/notice/hosted receipt
checks. The operator phase aborted; both flags closed 14:52:35 UTC, worker retired
14:55:42 with digest/401/local deletion verified. No requeue or second send.
The helper's notification parser rejected raw Windows CRLF; normalization and
static failure codes pass twelve operator tests/syntax. The corrected parser
reads the real notice; a later full helper attempt lacked trace observations and
is not a live helper pass. Manual existing-notice tap after closure opens unloaded
Guardian. Action-time-approved 801–805 cleanup passes; final hosted counts are
0/1/1/0/0 and zero synthetic notices remain. Full repair source CI 37949413443
(`77dd2c1`) passes every job; the separate local operator-tag timestamp check
passes. The corrected 811–815 pair subsequently passes the full first helper
phase and one guarded requeue. Operator latency exhausted the buffers before
the second invocation; hosted attempts remain one. Both flags closed at
15:38:30 UTC; worker retirement at 15:46:58 passes digest/401/local deletion.
Approved marker cleanup and final counts 0/1/1/0/0 pass. USB wake setting is
restored and physical read-only readiness passes. Duplicate suppression remains
unverified. The bounded `tool/guardian_duplicate_pair.ps1` bridge waits at most
45 seconds for the browser's exact verified-requeue signal, then starts the
duplicate phase immediately; 23 local gate checks and twelve existing operator
tests pass. Full source CI 37956582373 (`223cc48`) passes every job. Obtain
fresh-ID pair review and action-time enable confirmation before its live use.
Fresh 821–825 ignored SQL copies reverse-verify as UUID-only substitutions.
Preserve the first-notice
guard, native claims and all existing lifetime/security limits. No new pair is
staged or enabled; the second phone is still not needed.
Preparation source CI run 37331996250 (`fd139db`) passed every job. The test
runner was installed; the receipt-only gate now passes.

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
