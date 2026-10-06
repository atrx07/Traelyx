# M6.8 locked-phone and offline delivery check

## Prepared boundary

The [background and cold-process checks](GUARDIAN_PUSH_CHECK.md) passed on
2026-10-06. The next review covers **at most two synthetic FCM messages**, one
locked-phone notice and one offline queued delivery after network restoration.
It does not activate recording, a driver, real-contact alerts or a scheduler.
Expiry, permission revocation and actual duplicate FCM checks remain separate.
The second phone is not needed.

The provider acceptance/receipt distinction remains mandatory. FCM can keep a
message while the device is disconnected, subject to the message TTL; neither
queuing nor later delivery is guaranteed. The worker already sends the remaining
event TTL, restricted package and opaque IDs. See [FCM lifespan](https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan).
Generic notification content and `VISIBILITY_PRIVATE` are unchanged; Android
and the user's lock-screen settings control what is visible. See [Android notifications](https://developer.android.com/develop/ui/views/notifications).

## Exact review scope

- Stage and remove two sequential disposable fixtures using the tested
  `guardian_push_stage.sql` / `guardian_push_cleanup.sql` text. Locked case uses
  reserved UUID suffixes 721–725; offline case uses 731–735. Reverse substitution
  verifies UUID constants are the only differences. Each stage requires an empty
  session/event/delivery queue and exactly one device with over ten minutes left.
  No routing token, receipt credential or real name is read by these scripts.
- Rotate the worker secret to one private temporary 256-bit value, use it only
  for these two explicit sends/checks, then replace it with a fresh server-only
  value, verify 401 for the old value and delete its ignored local file.
- Briefly enable capability and dispatch for each phase. Send once per fixture;
  never repeat after timeout or an uncertain response. Restore both flags after
  receipt or failure/timeout, before cleanup and before the next stage.
- Google receives the existing first-phone routing token, opaque delivery and
  generation IDs, and fixed delivery options. Supabase receives the normal
  guarded receipt. No personal trip telemetry, location, driver name or new
  registration is uploaded.
- Temporarily sleep/lock the password-free phone for the first phase; wake it
  to observe only generic Traelyx notice content before dismissing the keyguard
  and testing the actual tap.
- For the second phase only, temporarily turn off phone Wi-Fi and mobile data,
  then restore the reviewed baseline (currently Wi-Fi on, mobile data off,
  airplane mode off). A changed baseline aborts before toggling. Keep USB ADB.
  Do not change airplane mode, VPN, notification privacy or battery settings.
- Permanently remove only each marked synthetic principal and its cascading
  fixture records. Preserve real profile, registration, sign-in and trips,
  dedicated Google key and existing notification claims.

This production enable/send/cleanup scope requires specific approval under the
active M6.8 review gate and Computer Use confirmation policy. Preparation makes
no hosted mutation, credential, new push or network/lock-setting change.

## Concrete artifacts

Ignored files under `.dart_tool/`:

- `m6_8_locked_push_stage.sql` / `m6_8_locked_push_cleanup.sql` (721–725).
- `m6_8_offline_push_stage.sql` / `m6_8_offline_push_cleanup.sql` (731–735).
- `m6_8_receiver_offline_once.ps1`: fixed phone/host probe; baseline,
  inactive-recorder, process-absence, non-stopped package and no-active-default-
  network guards. One host-side dispatch, then independent Wi-Fi/data
  restoration in `finally`, including failure/timeout paths. It logs booleans
  and the existing redacted aggregate probe result only. Syntax is parsed
  without executing it during preparation. Abrupt host termination can bypass
  `finally`; restore the baseline immediately if the run is interrupted.

No app/backend source, dependency, migration or sampling changes. The existing
source CI 37484921020 passed all gates, eleven SQL suites and 352 native tests;
the dispatcher/probe's 22 Node tests pass again during this preparation.

## Bounded execution after approval

1. Recheck ADB, inactive recorder, notification permission, network baseline,
   native registration availability, hosted empty queues/one unexpired device,
   both false digests and no scheduler. Preserve each actual setting value.
   Install no app update and inspect no real credential/account/route content.
2. Set the temporary worker without printing it, verify its digest/private local
   ACL and authenticated disabled 503. Stage 721–725; require all three true.
3. With no recording, Settings → Home → app-specific `am kill` establishes
   process absence without force-stop. Sleep the phone. Require lock-policy
   `showing=true` and `occluded=false`; abort without sending if unavailable.
   Enable both functions, verify digests, then recheck process absence and lock
   before the sole locked dispatch. Observe hosted one-attempt receipt within
   90 seconds without opening or instrumenting Traelyx. Close both flags.
4. Wake without dismissing keyguard first. Observe only generic Traelyx notice
   text/bounds, not other notifications. If lock settings hide the notice,
   report that visibility limit. Then dismiss keyguard, tap the actual notice,
   confirm unloaded Guardian/Reload alerts and hosted `device_received`, not
   viewed. Run marker-checked cleanup; require three absence booleans true,
   device_rows=1 and final 0/1/1/0/0. Stop the second phase if this one fails.
5. Stage 731–735 while both flags are false. Re-establish process absence,
   non-stopped package and the exact Wi-Fi-on/data-off baseline. Enable both
   functions, then execute the offline helper once. It refuses dispatch if a
   default network remains and restores settings immediately when the single
   bounded probe ends. Do not manually open/instrument Traelyx before receipt.
6. Verify restored settings and validated connectivity. Observe hosted receipt
   within 90 seconds after restoration without a second dispatch; then close
   both flags. Provider acceptance alone or absence of a notice is insufficient
   to claim offline recovery. Observe/tap the generic notice and verify unloaded
   Guardian plus no view acknowledgement. If recovery fails, record the outcome,
   close processing and remove the fixture; a late message must fail receipt
   authorization after cleanup. Do not extend network outage or resend.
7. Verify false digests, authenticated disabled 503 and capability 503; retire
   the worker, verify its old value gets 401 and erase the private file. Cleanup
   731–735, require absence checks true and 0/1/1/0/0. Verify network settings,
   sign-in and real registration are preserved. Save ignored proof screenshots,
   record observed outcomes/limits, synchronize status and commit/push.

Do not claim natural Doze, a PIN-protected lock screen, extended outages, device
reboot/direct boot, expiry/revocation, actual duplicate delivery, two-phone or
emergency reliability from these checks. Further hosted tests need review.
