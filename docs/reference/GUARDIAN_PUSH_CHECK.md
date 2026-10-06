# M6.8 controlled first-phone FCM check

## Scope and current boundary

The [receipt-only check](GUARDIAN_RECEIPT_CHECK.md) passed on 2026-10-06, after
the [Android parser repair](../issues/2026-10-06_android-guardian-receipt-regex.md).
This next check is prepared, not executed or approved for sending. It exercises
the existing backend OAuth/FCM adapter, native background receiver, receipt,
durable notice claim, generic notice and data-free tap. It uses one synthetic
severe-drive event for the already consented first-phone registration.

It bypasses real driver pairing/activation/detection/ingestion only in this
reviewed fixture. No personal telemetry or real driver name is uploaded. It
does not validate crash detection, recorder integration, real-contact alerts,
two-phone behavior or emergency reliability. The second phone is not needed.
There is no scheduler; both hosted functions remain disabled during preparation.

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
The observation mode awaits a separately approved real synthetic FCM arrival.
The new PostgreSQL fixture/negative guards are pending CI. Docker Desktop
failed during local startup before any container was created; it exited
without data/configuration changes. Use CI's disposable PostgreSQL 17 for the
SQL gate. No hosted fixture, worker-secret rotation, enablement, OAuth or FCM
send has run for this check.
