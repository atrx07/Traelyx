# M6.8 two-account delivery and inbox check

## Scope and limits

Live check passed and exact cleanup completed 2026-10-21. The existing Tecno
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
   Verify 0/0/0/2/2/1/1 again, account/pairing preservation, unchanged recorder
   hashes, unchanged nonreceiving Tecno vault and no retained driver vault.
   The Pixel receiver vault must be allowed to change: successful `claimNotice`
   persists the delivery ID in that encrypted record before showing a notice.
   Check its retained owner-bound registration; do not restore the pre-send
   ciphertext or extract receipt credentials to force a byte-equality check.
   A real concurrent change needs
   reassessment rather than deleting unrelated rows to force these counts.

## Preparation evidence

On 2026-10-21 both devices were authorized, signed in, online and idle after the
saved Pixel AVD restart. Ordinary configured source `37906dc` was update-installed
without clearing data. Fresh preservation checks match all 11,857 Tecno recorder
files, zero Pixel recorder files and both receiver vaults; both driver vaults
are absent. Explicit pairing reloads show Paired on both. Hosted aggregate
readiness is 0/0/0/2/2/1/1 and both enable digests equal SHA-256 of `false`.
The current role direction is confirmed as Tecno driver / Pixel guardian; both
notification permissions and existing provider markers are present. The separate
read-only permission-contract check returns true.

Source `8ad6be0` passes full
[CI 39482359166](https://github.com/atrx07/Traelyx/actions/runs/39482359166): all three
jobs, fourteen SQL suites plus revision upgrade, Flutter/native tests,
debug/release APKs and artifacts. Initial CI caught a missing synthetic profile
in the negative-case setup; the required profile and teardown were added without
weakening assertions. Preparation introduced no runtime or schema change.

## Live result — 2026-10-21

The maintainer approved the complete one-message scope and the exact enable and
cleanup actions. After an accidental emulator shutdown, Pixel_10 restarted with
saved data and renewed ADB authorization; both devices were online and idle.
Ordinary source `37906dc`, accounts, role direction and existing registrations
were retained. The reviewed worker digest and disabled probe passed before
staging. No new account, pairing, receiver registration or native activation ran.

- Fixture 1001–1003 returned all three readiness booleans true. A fresh audit
  showed exactly one session/event/delivery, pending, attempts zero and unclaimed.
  Both event and window had more than 300 seconds left before the sole invocation.
- The six-minute server lease was 01:18:16.509–01:24:16.509 IST. Dispatch returned
  at 01:18:37.967 IST with processed=1, provider_accepted=1 and every other counter
  zero. Pixel showed one generic notice; hosted status was device_received,
  attempts=1. Both flags were restored false at 01:19:05 IST, about 30 seconds
  after provider acceptance. Disabled dispatch and capability probes passed.
- Tapping the actual notice removed it and left Guardian at its retained scroll
  position. The first viewport-only unloaded check was inconclusive; scrolling
  to the inbox showed Reload alerts with no loaded event or Open action. Explicit
  reloads then showed Pixel's incoming event/Open alert and Tecno's outgoing
  delivery without Open alert. Pixel's explicit Open displayed the experimental
  details; Tecno reload and hosted status became viewed, still attempts=1.
  This records an app action, not a claim that a person saw or responded to danger.
- Worker retirement matched its hosted digest, the old credential returned 401,
  and its restricted local file and clipboard copy were removed. The lineage-
  checked cleanup returned all absence booleans true and device_rows=2. Final
  counts are 0/0/0/2/2/1/1; explicit inbox reloads show no remaining test event.
- All 11,857 Tecno recorder hashes and its receiver vault remain unchanged;
  Pixel still has zero recorder files and both driver vaults are absent. The
  original generic preservation comparator flagged Pixel receiver ciphertext
  inequality. Inspection of `EncryptedGuardianRecipientVault.claimNotice` and
  its existing preservation/restart tests confirms the expected encrypted rewrite
  of `noticeDeliveryIds`. Pixel's owner-bound Check this phone still succeeds.
  No plaintext vault contents were extracted, and the old comparison evidence
  was retained rather than relabelled as byte-equality success.

This closes the synthetic two-account delivery/inbox check only. No driving,
recording, native driver activation, permission change, app update, migration,
scheduler, real-contact alert or personal trip upload occurred in the window.
Mounted review, active recording/calibration/performance, native live ingestion
and physical-device reliability gates remain open/deferred. Pixel emulator
results do not establish second-physical-phone reliability. M6.8 is incomplete.
