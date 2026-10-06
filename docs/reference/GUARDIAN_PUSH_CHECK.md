# M6.8 controlled first-phone FCM check

## Scope and current boundary

The [receipt-only check](GUARDIAN_RECEIPT_CHECK.md) passed on 2026-10-06, after
the [Android parser repair](../issues/2026-10-06_android-guardian-receipt-regex.md).
The approved background and cold-process delivery/tap checks passed on
2026-10-06. They exercise
the existing backend OAuth/FCM adapter, native background receiver, receipt,
durable notice claim, generic notice and data-free tap. Each uses one synthetic
severe-drive event for the already consented first-phone registration.

It bypasses real driver pairing/activation/detection/ingestion only in this
reviewed fixture. No personal telemetry or real driver name is uploaded. It
does not validate crash detection, recorder integration, real-contact alerts,
two-phone behavior or emergency reliability. The second phone is not needed.
There is no scheduler; both hosted functions are disabled after the closed checks.

## Reviewable artifacts

- `supabase/manual_tests/guardian_push_stage.sql`: standalone SQL contents,
  not a migration. Requires zero sessions/events/deliveries, exactly one device
  with at least ten minutes of remaining authority, a recipient profile and
  unused reserved identities. Brief table locks protect staging preconditions.
  Creates one private synthetic principal/profile/connection/session/event and
  one **pending** delivery with zero attempts. Reads no token or credential;
  substitutes synthetic name snapshots. Event expiry is eight minutes;
  connection/session expiry is ten minutes. No usable driver capability is
  returned. Reserved identifiers end in 691–695.
- `supabase/manual_tests/guardian_push_cleanup.sql`: marker-checked,
  idempotent deletion of only that disposable principal and cascading records.
  Preserves the real recipient/profile/device. Run after both flags are false.
- `supabase/tests/guardian_push_fixture.sql`: disposable PostgreSQL only.
  Checks exactly one worker claim/target, no second reservation, early receipt
  racing provider completion, and cleanup/recipient preservation. Never paste
  this test wrapper into production.
- `tool/guardian_push_probe.mjs`: explicit operator CLI. Reads only the exact
  64-byte temporary worker secret in ignored
  `.dart_tool/guardian-push-worker-once.secret`. Its fixed destination is the
  Traelyx `guardian-dispatch` endpoint. Each invocation makes one bounded
  request with `{}`, rejects redirects, and never retries. Output contains only
  a verified denial or exact aggregate counters. A timeout or uncertain result
  requires inspection and closure, not another send. Modes are `disabled`
  (expect 503), `send` (expect one provider acceptance) and `retired` (expect 401
  for the retired test secret).
- Android instrumentation mode `guardian-push-observe`: read-only observation
  of this app's own synthetic delivery 695. Requires its durable encrypted
  notice claim and one active notification with the fixed generic title/text,
  private visibility, auto-cancel and a tap intent. Reads no Auth session and
  sends no request. Run only after the hosted receipt is observed; it is not a
  simulator for FCM arrival. Its process invocation is recorded separately
  from the initial cold-process check.
- Android mode `guardian-push-ready`: read-only preconditions for registration,
  remaining expiry, absent synthetic notice claim and notification permission.
  It requests no token, notice, network call or Auth session.

No runtime dependency, migration, permission or production service code changes
are introduced by this preparation.

## Exact production review required

Before any hosted mutation, obtain approval for all of:

1. Commit the disposable synthetic fixture for the sole real registered phone.
2. Rotate `GUARDIAN_WORKER_SECRET` to a newly generated temporary 256-bit
   value. The old setup copy was removed; no scheduler or other worker uses it.
   Keep the temporary copy only in the ignored file, restricted to this user.
3. Briefly set **both** `GUARDIAN_CAPABILITY_ENABLED` and
   `GUARDIAN_DISPATCH_ENABLED` to true, under their existing capability and
   worker-secret authentication. Make one dispatch invocation.
4. Allow the existing dedicated Google sender to exchange its backend-only
   credential for OAuth and send one data-only message through FCM to this
   phone. Google receives the existing routing token, opaque delivery ID,
   device-generation ID and fixed Android delivery options. It receives no
   driver identity, event kind, route, speed, trip ID or receipt credential.
   Supabase receives the phone's normal receipt-only credential and delivery
   acknowledgement, as in the previous approved receipt check.
5. Show the one generic local notice and test its actual tap into Guardian.
   This check's notice comes from a synthetic event; its fixed lock-screen copy
   contains no driver or event details.
6. Restore both flags to false, retire the temporary worker credential by
   rotating to a fresh server-only random value with no retained local copy,
   verify the test credential returns 401, erase its local file, and permanently
   remove only the synthetic fixture. The dedicated Google sender key stays
   in Supabase; real profile/device and trips remain intact.

Rotation is a persistent backend setting change, even though the test secret
is retired. An unrelated active worker/scheduler or changed device state
requires reassessment; do not assume an earlier empty-queue count still holds.

## Bounded sequence after approval

1. Confirm relevant source CI, local probe tests and compiled observation
   runner. Recheck phone authorization, validated network, notification
   permission, registration/marker presence, no RecorderService, no active
   driver control or scheduler, both false digests, and hosted 0/1/1/0/0 counts.
   Check the fixture delivery ID is absent from the phone's claim history.
   Do not inspect server token/credential rows or unrelated phone notifications.
2. Generate/set the temporary worker secret without printing it; verify its
   hosted SHA-256 digest. Run `node tool/guardian_push_probe.mjs disabled`.
   This must return the worker's own 503, without OAuth or a claim.
3. Run the **contents** of the stage script. Require all three result booleans
   true. If it fails, keep both flags false and retire the temporary secret.
4. Background Traelyx using Home. For a cold-process attempt use `am kill`
   only with recording inactive; record whether `pidof` is absent. Do not use
   force-stop: it suppresses delivery until manual reopening. Leave the phone
   unlocked for this initial notice/tap check. If a process remains, report
   background-only evidence rather than claiming a cold-process pass.
   On this phone, Home alone left Traelyx alive. A read-only foreground switch
   to Android Settings, then Home and the same app-specific `am kill`,
   established process absence without force-stop or a setting change.
   Recheck `pidof` immediately before dispatch. Do not run instrumentation or
   reopen Traelyx between that observation and the incoming FCM callback.
5. Enable capability processing, then dispatch. Verify both true digests.
   Run `node tool/guardian_push_probe.mjs send` exactly once. It must report
   processed=1, provider_accepted=1, and all other counters=0. Record ambiguity
   or failures without resending. Provider acceptance is not device receipt.
6. Observe only boolean/count state for delivery 695: one attempt and status
   `device_received` or `viewed`. Allow at most 90 seconds for receipt, checking
   at bounded intervals without running another dispatch. Close both flags
   immediately after receipt or on failure/timeout/interruption. Verify false
   digests and `503 capability_disabled`; the worker's disabled probe must
   return 503. Fixture TTLs **do not reset Edge flags**.
7. Run `guardian-push-observe` with the compiled runner. If a generic notice
   was actually posted, use its real system-tray tap and verify Guardian opens
   without auto-reload or view acknowledgement. The fixture details need not
   be opened; any separate detail-view check remains consented/authenticated.
8. Retire the worker secret as reviewed; prove the old test secret now returns
   401, then erase its local copy. Run cleanup contents and require all three
   absence checks true/device_rows=1. Confirm final 0/1/1/0/0 counts. Dismiss
   any remaining test notice; its durable local claim may remain until ordinary
   withdrawal/expiry, preventing a late duplicate from recreating it.
9. Reopen normal Traelyx, confirm preserved sign-in/registration, document each
   observed layer and any unverified layer, synchronize status and commit/push.
   No routine dispatch, scheduler, real alert or second-phone test follows
   automatically from this check.

## Delivery limits and references

FCM gives `onMessageReceived` only several seconds for processing; high
priority permits slightly more time but does not guarantee completion. The
existing receipt transport has three-second connection/read limits; the live
check must validate actual callback behavior rather than infer it from tests.
Messages can be delayed or suppressed. Force-stopped Android applications
require manual reopening before messages resume.

Primary references:

- [Android receipt handling](https://firebase.google.com/docs/cloud-messaging/android/receive-messages)
- [Android priority and processing limits](https://firebase.google.com/docs/cloud-messaging/android-message-priority)
- [Force-stop precondition](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
- [Existing worker boundary](GUARDIAN_DISPATCH_SETUP.md)

## Preparation evidence

Four synthetic Node probe tests and all 352 native unit tests pass. Both
read-only Android helper modes compile; the first-phone readiness proof passes
after updating only the test runner, preserving the app and registration.
The observation mode passed after the first approved synthetic FCM arrival.
Full preparation source CI run
[37484921020](https://github.com/atrx07/Traelyx/actions/runs/37484921020)
(`76c02a7`) passed every job, including all eleven SQL suites on disposable
PostgreSQL 17, the new negative staging/cleanup and receipt-race checks, and
the four Node probe tests. Docker Desktop failed during local startup before
any container was created; it exited without data/configuration changes. The
SQL validation used CI rather than local Docker. Before the approved window,
hosted aggregate counts were 0/1/1/0/0 and both enable digests matched false.

## Hosted and physical results — 2026-10-06

The maintainer approved the complete single-phone fixture, worker rotation,
temporary enablement, one send and cleanup. The first window enabled capability
at 15:33:01 UTC and dispatch at 15:33:19; both were false again at 15:34:15.
One invocation returned processed=1/provider_accepted=1 and zero skipped,
failed or deferred deliveries. Hosted checks confirmed one attempt and
`device_received`. Android's read-only own-notice observation passed: one
generic private notification, durable encrypted claim, fixed public copy,
auto-cancel and tap intent. The app process remained alive after `am kill`, so
this is background evidence, not a cold-process pass.

The maintainer accidentally cleared the notification before its actual tap,
then explicitly requested one repeat send and agent control. After the first
fixture was removed, the same stage/cleanup text was used with only its five
reserved UUIDs changed from suffixes 691–695 to 701–705. A new delivery ID
preserved the duplicate guard; no claim history was erased. Capability was
enabled at 15:39:38 UTC, dispatch at 15:40:05, and both were false again at
15:41:09. The repeat invocation also returned exactly one provider acceptance
and no other outcomes. Hosted receipt passed before closure. The real
system-tray notice was located and tapped; Guardian opened with its inbox
unloaded and “Reload alerts” available. A post-tap hosted check confirmed one
attempt still in `device_received`, with no detail-view acknowledgement.
This second window did not run the observation helper hardcoded to delivery
695; its notice/tap evidence came from the actual phone UI and hosted state.

Both temporary worker values were replaced with fresh server-only random
values, verified by their hosted digests; each old value returned 401 and its
private local file was deleted. The final replacement was saved at 15:42:20
UTC. Both fixture cleanups returned all absence checks true/device_rows=1.
Final counts are 0 sessions / 1 device / 1 unexpired device / 0 events /
0 deliveries. Both enable digests match false; capability POST probes return
503, and the first window also verified the authenticated dispatch 503 after
closure. Saved sign-in and registration remain intact. No app update, schema
change, personal telemetry upload, scheduler or Google sender-key change ran.

Proof files are private and ignored: `.dart_tool/m6_8_push_positive.jpg` and
`.dart_tool/m6_8_push_closed.jpg`. At this checkpoint cold-process arrival was
still unverified; it subsequently passed below. Locked/offline/expiry and
revocation behavior, actual duplicate FCM delivery, recorder integration and
two-phone delivery remain unverified. M6.8 remains in progress; a further
hosted push window requires its own concrete review.

## Cold-process window — preparation and results

On 2026-10-06, the first phone remained ADB-authorized with no RecorderService.
The Settings/Home/background-kill sequence above established an absent app
process with package `stopped=false`. Fresh hosted read-only checks passed:
zero sessions/events/deliveries, one device, and over ten minutes of remaining
device authority. Both enable digests still matched false.

The ignored review copies `.dart_tool/m6_8_cold_push_stage.sql` and
`.dart_tool/m6_8_cold_push_cleanup.sql` use fresh reserved IDs 711–715.
Reverse substitution verifies that UUID constants are their only difference
from the already tested standalone scripts. The one-request worker probe and
production receiver are unchanged; full source CI and the previous physical
background send/receipt/tap remain applicable. Preparation created no new
credential, hosted fixture, enablement, OAuth exchange or push.

After specific approval, repeat the bounded sequence once, with fresh
preconditions. Require process absence and `stopped=false` immediately before
dispatch; otherwise close without sending and report the unmet precondition.
Observe the normal callback through hosted one-attempt receipt and the actual
generic notice/tap, without starting instrumentation or reopening the app
before receipt. The observation helper is fixed to delivery 695 and must not
be claimed as evidence for 715. Restore both flags, retire the test worker,
remove only fixture 711–715 and verify the real registration/sign-in as before.
The second phone is not needed. Readiness proof:
`.dart_tool/m6_8_cold_ready.jpg`.

The maintainer then explicitly approved this complete window. Fresh ADB,
inactive-recorder, validated-network, notification-permission and non-stopped
package checks passed. Stage returned all three booleans true. Capability was
enabled at 16:05:25 UTC and dispatch at 16:06:25 on 2026-10-06. The command
immediately preceding the sole dispatch required process absence and
`stopped=false`; both passed. It returned processed=1/provider_accepted=1,
with zero skipped/failed/deferred outcomes. No instrumentation or app opening
ran between that process observation and hosted `device_received` confirmation.
The incoming callback started the app process. Both flags were restored to
false at 16:07:27; authenticated dispatch and capability probes verified 503.

The actual generic system-tray notice was located and tapped. Guardian opened
with Reload alerts available and its inbox unloaded. A post-tap SQL check
confirmed one attempt still in `device_received`, without acknowledging a
detail view. This proves one cold-process delivery on this phone/network;
it does not establish delivery guarantees under other lifecycle conditions.
The hardcoded delivery-695 observation helper was not used for delivery 715.

The test worker was replaced with a fresh server-only value at 16:09:10 UTC;
its digest matched, the old value returned 401 and its local file was deleted.
Marker-checked cleanup returned all three absence booleans true/device_rows=1.
Final counts are 0/1/1/0/0, both flags false, and sign-in/registration preserved.
No runtime update, schema change, personal telemetry, scheduler or Google key
change ran. Proof: `.dart_tool/m6_8_cold_positive.jpg` and
`.dart_tool/m6_8_cold_closed.jpg`. Locked/offline/expiry/revocation, actual
duplicate FCM, recorder integration and two-phone gates remain pending.
