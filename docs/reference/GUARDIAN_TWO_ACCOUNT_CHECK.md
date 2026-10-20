# M6.8 two-account delivery and inbox check

## Scope and limits

Prepared 2026-10-21; no production fixture or send has run. The existing Tecno
driver and Pixel_10 emulator guardian are already paired and registered. This
check uses their existing relationship and shared name snapshots. The Pixel is
valid for account/inbox integration, not second-physical-phone reliability.
Mounted consent, native detection, ingestion, calibration and driving/performance
validation remain separate deferred gates. Do not confirm vehicle mounting on a
desk or start a recorder for this test.

## Reviewable artifacts

- `supabase/manual_tests/guardian_two_account_stage.sql`: fixture 1001–1003 only.
  Requires empty driver/event/delivery tables, exactly one active allowed pair,
  exactly two device rows, one unexpired device per participant, and the existing
  possible-crash-only permission. Refuses changed permission, extra devices,
  active sessions, queue contents and identity collisions. Inserts one test
  session, generated event and pending delivery, expiring after eight minutes.
  It creates no account, profile, relationship, device, permission or revision
  metadata. It reads only the recipient device ID/generation, not routing or
  receipt credentials. No usable driver ingestion credential is retained.
- `supabase/manual_tests/guardian_two_account_cleanup.sql`: exact UUID, owner,
  activation, event kind/version and timestamp-lineage checks. Deletes only those
  test delivery/event rows and the exact matching test session. A newer session
  survives. Missing delivery after cascade is tolerated; ambiguous, mismatched
  or partial lineage is refused for separately reviewed recovery. No deletion of
  accounts, profiles, pairing, devices or driver revision metadata.
- `supabase/tests/guardian_two_account_fixture.sql`: disposable PostgreSQL only.
  Covers refusal guards, unrelated collisions, existing-state preservation,
  one worker claim/target, both authenticated inbox roles, unrelated-account
  denial, recipient-only viewing, cleanup refusal, newer-session protection and
  idempotence. Never paste this wrapper into production.
- Existing `tool/guardian_push_probe.mjs` and server processing-window contract:
  one dispatch invocation; no automatic retry on timeout or ambiguous result.
  See [push check](GUARDIAN_PUSH_CHECK.md) and
  [rejection check](GUARDIAN_REJECTION_CHECK.md) for worker retirement and finite
  processing-window behavior. No scheduler is added.

## Production review required before starting

Review one generated possible-crash-pattern event for the existing pair, one
data-only FCM message to the Pixel guardian, normal receipt, generic notice tap,
explicit inbox reads and recipient opening. This is a synthetic test; no crash
or personal trip is being reported. The existing shared name snapshots can
appear in the authenticated inbox; Google receives only its existing routing
token, opaque delivery/generation IDs and fixed delivery options. Supabase
receives normal receipt and authenticated list/view requests. No location,
speed, route, raw telemetry or trip history is uploaded.

The review must also cover one temporary restricted local worker credential,
setting its Edge secret, a fresh server-enforced window capped at six minutes
and the exact two enable-flag changes. Both endpoints are active under existing
authorization checks only during that window. Create no credential or fixture
before approval. Browser setting changes and permanent cleanup retain their
action-time confirmation requirements.

## Bounded sequence after approval

1. Recheck both accounts, role direction, unchanged pairing/permission, receipt
   validity, notification permission, network, idle recorder and absent driver
   vaults. Read-only hosted counts must still be 0/0/0/2/2/1/1 for sessions,
   events, deliveries, devices, unexpired devices, active pairs and ready pairs.
   Keep both enable flags false during setup. Reconfirm no active external worker.
2. Prepare the temporary worker and finite server window only after review, then
   stage the exact SQL. Verify only the expected delivery is pending/unclaimed,
   and recheck event/window lifetime immediately before the sole invocation.
   Start only with more than 300 seconds remaining. Otherwise close unused;
   never extend the fixture or resend to compensate for operator latency.
3. Enable only the reviewed settings. Invoke the existing probe once. A result
   must be exactly one processed/provider-accepted delivery with no other work;
   ambiguous response aborts without retry. Recheck receiver receipt/notice
   using fixed booleans and known fixture IDs, never tokens or raw logs.
4. Disable both functions as soon as receipt is observed, on any failure, or
   within 90 seconds of provider acceptance. The finite server window remains
   an independent fail-closed bound if the operator is interrupted.
5. Tap the Pixel's generic notice. It must open Guardian without auto-loading
   details or recording a view. Explicitly reload alerts on Pixel and Tecno:
   Pixel sees an incoming event; Tecno sees its outgoing delivery. Only Pixel
   offers Open alert. Opening records `viewed`; a Tecno reload must then show
   recipient-opened status. Session/event must still be unexpired for reads.
   An expired fixture is an incomplete test, not permission to extend or resend.
6. Retire the worker to a fresh server-only value, verify its old credential
   returns 401, and delete the restricted local test copy. Keep functions false.
   Obtain action-time cleanup approval and run only the lineage-checked cleanup.
   Verify 0/0/0/2/2/1/1 again, account/pairing preservation, unchanged recorder/
   receiver hashes and no retained driver vault. A real concurrent change needs
   reassessment rather than deleting unrelated rows to force these counts.

## Preparation evidence

On 2026-10-21 both devices were authorized, signed in, online and idle after the
saved Pixel AVD restart. Ordinary configured source `37906dc` was update-installed
without clearing data. Fresh preservation checks match all 11,857 Tecno recorder
files, zero Pixel recorder files and both receiver vaults; both driver vaults
are absent. Explicit pairing reloads show Paired on both. Hosted aggregate
readiness is 0/0/0/2/2/1/1 and both enable digests equal SHA-256 of `false`.
The SQL bundle still requires exact-source disposable CI before production
review. No live staging, worker rotation, enablement or send has occurred.
