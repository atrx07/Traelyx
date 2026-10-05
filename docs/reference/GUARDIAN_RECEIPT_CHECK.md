# M6.8 isolated hosted receipt check

This is a protocol check before FCM sending. It does not verify actual push
arrival, notification display, driver monitoring or emergency reliability.

## Reviewable artifacts

- `supabase/manual_tests/guardian_receipt_stage.sql` stages one disposable
  synthetic driver/profile, connection, session, event and delivery for the
  sole consented recipient device. It reads only device identity, generation,
  owner and expiry; it copies no routing token, receipt credential or real
  profile name. The real profile and device are not modified.
- `supabase/manual_tests/guardian_receipt_cleanup.sql` removes only the
  marker-checked synthetic principal and its cascading fixture rows, preserving
  the real recipient. It refuses a mismatched principal and is idempotent.
- `supabase/tests/guardian_receipt_fixture.sql` runs staging, positive receipt,
  idempotent retry and cleanup in a disposable PostgreSQL database, asserting
  recipient preservation. **Never run this test wrapper in production.**
- Instrumentation mode `guardian-hosted-receipt` uses the existing encrypted
  phone authority and normal bounded HTTPS receipt gateway. It sends two
  receipt requests to the configured Traelyx Supabase endpoint, checks the
  local receipt is unchanged and verifies Firebase remains uninitialized.
  It shows no notification, makes no notice claim and reads no Auth session.

The fixture explicitly stages `provider_accepted` with one attempt; no provider
call has occurred. Its labels and event are synthetic. This bypasses pairing,
activation, detection, ingestion and dispatch **only in this reviewed fixture**;
it does not prove those paths. The synthetic event expires after eight minutes,
and the synthetic connection/session after ten minutes. Fixed fixture IDs are
not credentials. No usable driver capability is returned.

## Production sequence — separate approval required

1. Verify green affected tests/CI, the connected consented phone, no active
   recorder, exactly one unexpired device and zero driver sessions/events/
   deliveries. Verify both Edge enable flags are false. Never inspect tokens
   or account row identities in the dashboard.
2. Obtain concrete production approval for staging the disposable fixture,
   briefly setting `GUARDIAN_CAPABILITY_ENABLED=true`, sending the phone's
   normal receipt-only capability to this Supabase project, restoring false,
   and permanently removing the synthetic fixture. Dispatch stays false;
   no FCM send, worker-secret change, scheduler or trip upload is authorized.
3. Run the **contents** of `guardian_receipt_stage.sql` in the reviewed
   Traelyx SQL Editor. Require `fixture_ready` and `one_device` both true.
4. Install the reviewed instrumentation APK without clearing app data. With
   recording inactive, enable only capability processing, then run:

   ```text
   adb -s 1094731392113210 shell am instrument -w -e mode guardian-hosted-receipt io.github.atrx07.traelyx.test/io.github.atrx07.traelyx.recorder.RecorderLifecycleInstrumentation
   ```

   Require the synthetic receipt/retry proof to pass. A static rejection message
   contains no credential. This intentionally sends no FCM message or notice.
5. Restore capability processing to explicit false immediately, including on
   failure. Verify its false digest and `503 capability_disabled`. If the run
   is interrupted, restore that flag before resuming; fixture TTLs do not
   reset an Edge secret automatically. Verify the synthetic delivery reached
   `device_received` using a boolean/count only.
6. Run the cleanup **contents**, requiring all three absence checks true and
   `device_rows=1`. Confirm final aggregate counts are 0 sessions, 1 device,
   1 unexpired device, 0 events and 0 deliveries. Reopen the normal signed-in
   app; preserve its trip data and recipient registration. Keep both functions
   disabled. Actual FCM and two-phone delivery remain subsequent review gates.

## Preparation evidence

On 2026-10-05 all ten SQL suites passed against isolated PostgreSQL 17 with
no network/host port and a read-only SQL mount. Additional local script checks
denied empty/multiple/soon-expiring devices, existing fixture identities and
mismatched cleanup; valid cleanup preserved the recipient and unrelated profile.
The phone probe compiled without running it; all 351 native unit tests,
Android lint and repository validation also passed. Hosted staging/positive receipt
has not yet run. The fresh consented first-phone registration is directly
verified as 1 device/1 unexpired device; sessions/events/deliveries remain zero,
and both enable-secret digests match false.
