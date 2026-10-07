# M6.8 duplicate, expiry and revocation receiver checks

**Status:** Prepared for isolated CI validation; no hosted mutation or send.
**Owner:** agent/maintainer. **Updated:** 2026-10-07. M6.8 remains active.

## Goal and references

Validate a dismissed notice cannot reappear after an actual duplicate FCM message,
and queued messages cannot show a notice after server event expiry or disconnect.
Read only Guardian spec sections 3, 7, 8 and 10, the permission matrix, receipt /
preflight / durable claim implementation, existing dispatcher and manual fixtures.
Prior [locked/offline results](GUARDIAN_RECEIVER_CHECK.md) passed and are closed.

## Proposed review boundary

At most **four synthetic FCM messages** across three sequential fixtures:

| Case | Reserved IDs | Sends | Expected result |
|---|---|---|---|
| Duplicate after dismissal/restart | 741–745 | 2, same delivery/generation | Two receipts/attempts; second message does not recreate the dismissed notice |
| Server expiry after queuing | 751–755 | 1 | Shortened synthetic server expiry denies receipt/display after reconnection |
| Disconnect after queuing | 761–765 | 1 | Guarded driver disconnect increments revision/audits; queued receipt/display denied |

Use one explicitly reviewed temporary worker value, private ignored file and
fixed-endpoint probe; retire to a fresh server-only value, prove old-value 401 and
delete the local copy after closure. Briefly enable both functions only during
each phase, with current capability/worker authorization unchanged. No scheduler,
app update, driver activation, real-contact alert or personal trip upload.
Google receives the existing routing token and opaque delivery/generation IDs;
Supabase receives only normal receipt requests. Preserve real profile/device,
sign-in, trips, Google key and durable notice claims. Second phone is not needed.

This is a proposed production enable/send/network/fixture-control/cleanup scope.
It needs specific M6.8 review and action-time browser confirmation before execution.

## Concrete controls and validation

Source controls in `supabase/manual_tests/` are standalone SQL, not migrations:

- `guardian_push_requeue.sql`: exact private marker/IDs, received once, attempts=1,
  no claim, one delivery, current authority and over two minutes of event lifetime.
  Requeue once with the same IDs/generation; preserve attempts and native claims.
- `guardian_push_expire.sql`: only the exact accepted-once synthetic fixture.
  Shorten its server event expiry, preserving the already queued provider TTL.
  This exercises current server receipt authorization; it does not test natural
  FCM TTL exhaustion or prove that FCM always delivers a queued message.
- `guardian_push_disconnect.sql`: same accepted-once guards. Transaction-local
  synthetic Auth context calls the existing guarded disconnect API, preserving
  audit/revision semantics. No reusable credential or grant is created.
- Existing marker-checked stage/cleanup scripts are unchanged. Nine ignored
  `.dart_tool/m6_8_{duplicate,expiry,revocation}_{stage,control,cleanup}.sql` copies
  reverse-verify as UUID-only substitutions. Never run the test wrapper in production.
- `supabase/tests/guardian_receiver_controls.sql` runs in disposable PostgreSQL:
  wrong-state/marker refusals, one requeue with attempts preserved, third-send
  refusal, denied expired/disconnected receipts, disconnect audit/cascading cleanup,
  and unchanged receiver routing/generation/credential/lifetime. Added to CI.

The ignored `m6_8_receiver_negative_once.ps1 -Case expiry|revocation` requires the
same Wi-Fi-on/data-off/airplane-off baseline, inactive recorder, absent process and
non-stopped package. It waits at most 15 seconds for no active default network,
dispatches exactly once, then holds offline for at most 90 seconds awaiting a
fixed local signal. Create that signal only after the appropriate hosted control
query verifies denial. Independent `finally` restoration runs on success/failure;
abrupt host termination can bypass it, requiring immediate baseline restoration.
No credential or private payload is logged. Syntax is checked without execution.

## Execution and acceptance after approval

1. Recheck changed phone/hosted state, no recording, notification permission,
   exact network baseline, retained native registration, empty queues/one ready
   device, both false digests and no scheduler. Abort if any precondition differs.
2. Duplicate: stage fresh 741–745, establish process absence, enable reviewed
   flags and send once. Require normal receipt/notice, then disable. Tap the
   actual notice to dismiss it; verify unloaded Guardian/not viewed, zero active
   records for this delivery and snapshot only the encrypted vault's hash.
   Re-establish process absence. Run the guarded one-time requeue, reopen the
   reviewed window and dispatch once. Require hosted attempts=2/device_received,
   absent recreated notice and unchanged encrypted vault hash. Do not erase claims.
3. Close both flags and remove only the marker-checked fixture before the next case.
4. Expiry then disconnect: stage each fresh fixture while disabled. Establish
   process absence and enable reviewed flags. Run the negative helper once; after
   provider acceptance/process-absence proof, run its control SQL while the phone
   remains offline. Require all denial/audit booleans true, then create its exact
   local signal. Verify radio restoration and normal callback process start,
   unchanged vault hash, no notification for the synthetic delivery, hosted
   denial and provider_accepted/attempts=1 without receipt/view. Do not open or
   instrument Traelyx before callback observation. Close flags within 90 seconds
   of reconnection or failure, then cleanup before the next case.
5. Provider acceptance with no callback evidence is inconclusive, not a receiver
   rejection pass. Never resend after an uncertain response or timeout. Cleanup
   still runs; record any late-message observations honestly.
6. Verify final false digests/disabled probes, retired worker 401/local deletion,
   three fixture absence checks and final 0/1/1/0/0. Verify retained sign-in/device
   and network baseline. Save ignored proof, synchronize status, commit/push.

## Pending gates

- [x] Guarded SQL controls and isolated regression wrapper prepared.
- [x] Ignored fixture copies reverse-verified; bounded helper syntax parsed.
- [ ] Isolated SQL CI and remaining affected checks pass.
- [ ] Obtain concrete hosted review and execute bounded cases.
- [ ] Record observed results/limits and complete cleanup/persistence.

No schema, app/backend runtime, dependency, sampling, battery or permission change.
These checks do not prove natural Doze, long outages, reboot/direct boot, recorder
integration, two-phone delivery or emergency reliability. Complete those remaining
M6.8 gates independently; M7 is not authorized.
