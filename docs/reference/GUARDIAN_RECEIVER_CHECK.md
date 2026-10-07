# M6.8 locked-phone and offline delivery check

**Result (2026-10-07):** Both bounded checks passed. Both functions are disabled,
the worker is retired and both synthetic fixtures are removed. Final counts are
0/1/1/0/0 with real sign-in/registration retained. M6.8 remains in progress.

## Reviewed boundary

The [background and cold-process checks](GUARDIAN_PUSH_CHECK.md) passed on
2026-10-06. The approved checks covered **two synthetic FCM messages**, one
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
  network guards, including a 15-second bound for asynchronous disconnect. One
  host-side dispatch, then independent Wi-Fi/data
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

## Locked-phone checkpoint — 2026-10-07

The reviewed first phase sent exactly one message for fixture 721–725. Capability
enabled at 09:16:30 UTC and dispatch at 09:17:00 UTC. Immediately before sending,
Traelyx had no process, its package was not force-stopped, the screen was off and
keyguard was showing without occlusion. The probe reported one processed message,
one provider acceptance and zero skipped, failed or deferred messages. Hosted
delivery 725 reached `device_received` with one attempt before opening Traelyx.
Both flags returned to false at 09:18:55 UTC, with matching digests.

The current lock-screen settings hid the generic text before unlocking. A scoped
Android notification check confirmed one active Traelyx record for delivery 725;
after unlocking, the generic title and text were visible. Tapping that actual
notice opened Guardian with Reload alerts available and private details unloaded.
The post-tap hosted query confirmed one attempt and `device_received`, not viewed.
Proof is ignored locally at `.dart_tool/m6_8_locked_positive.jpg`.

The maintainer confirmed the irreversible cleanup action. Marker-checked cleanup
returned all three absence checks true and device_rows=1. Between-phase hosted
counts are 0 sessions / 1 device / 1 unexpired device / 0 events / 0 deliveries;
the authenticated disabled dispatch probe passes. Closed proof is ignored at
`.dart_tool/m6_8_locked_closed.jpg`. Wi-Fi remains on, mobile data off and airplane
mode off. No runtime/schema update, personal telemetry or Google key change ran.

At this checkpoint the temporary worker remained installed and its private local
file was available for the second phase. Offline fixture 731–735 was staged with
all readiness checks true and process absence established without force-stop.
Both functions remained disabled while the filled, unsaved enable settings
awaited action-time confirmation. No second message or network change had run.
The subsequent execution, worker retirement and cleanup are recorded below.

### Offline preflight abort — no dispatch

Both flags enabled at 09:43:00 UTC. The helper's immediate active-network guard
aborted before invoking the dispatch probe: Android still reported a default
network after the disable command. Its `finally` restored Wi-Fi on/mobile data
off, and a follow-up check confirmed active connectivity and airplane mode off.
Both flags returned to false at 09:43:47 UTC. Hosted checks confirmed the fixture
was still allowed and its sole delivery remained pending with attempts=0 and no
claim. No offline message was sent, so this proves neither queuing nor recovery.

The ignored operator helper now waits at most 15 seconds for the current default
network to become absent after the asynchronous setting change. It still aborts
without sending if a network remains, invokes the probe once only and restores
both settings in `finally`. Revised syntax passed; execution then awaited renewed
confirmation at the production enable action and a fresh fixture lifetime check.

The maintainer approved the corrected enable window. At 09:53 UTC the fresh
lifetime check returned fixture_valid=false / one_unsent=true: the original
synthetic fixture had expired during review. Both flags stayed false; no dispatch
ran. Marker-checked deletion/recreation of only that expired, unsent fixture was
prepared and confirmed at the deletion action before the corrected run below.
The normal stage script supplied a new lifetime; no expired event was extended.

### Corrected offline delivery — 2026-10-07

After action-time approval, the expired unsent fixture was removed with all three
absence checks true/device_rows=1. The unchanged tested stage script recreated
731–735 with its normal lifetime and all readiness checks true. No expired event
was extended in place. Both flags enabled at 09:57:48 UTC.

The revised helper confirmed no active default network and no Traelyx process
before its sole dispatch. The probe returned processed=1/provider_accepted=1 and
zero skipped/failed/deferred. The process remained absent while offline. Both
settings restored in `finally`; a separate check confirmed active connectivity,
Wi-Fi=1/mobile_data=0/airplane_mode=0. The normal receiver then reached
`device_received` with attempts=1 before any app opening or instrumentation,
within the 90-second observation bound. Both flags returned to false at
09:59:17 UTC, with matching digests; authenticated dispatch 503 and capability
503 checks pass.

The actual generic notice in Android's shade was tapped. Guardian opened with
Recent Guardian alerts and Reload alerts, no alert cards and no loaded-empty
state. The post-tap hosted check remained `device_received` with one attempt,
not viewed. Proof is ignored at `.dart_tool/m6_8_offline_positive.jpg`.

The temporary worker was replaced at 10:03:38 UTC with a fresh server-only value;
its digest matched and the old credential returned 401. The exact ignored local
worker file was deleted, and private browser-runtime strings were cleared. The
Google sender key remains unchanged. After action-time confirmation, final
marker-checked cleanup returned all three absence checks true/device_rows=1.
Final hosted counts are 0 sessions / 1 device / 1 unexpired device / 0 events /
0 deliveries. Both flags remain false. Closed proof is ignored at
`.dart_tool/m6_8_offline_closed.jpg`.

The maintainer reported changed phone state before closure. Fresh checks found
ADB authorized, screen on/keyguard absent, Wi-Fi=1/mobile_data=0/airplane_mode=0,
inactive recording and the retained native registration vault. Traelyx was not
initially foreground; bringing its existing task forward restored the signed-in
Guardian screen without an app update, data clearing or alert reload. The
provider-consent marker was also verified present. Real trip contents were not
read or modified by these checks. Repository validation and diff checks pass;
the result documents are synchronized for the bounded completion commit.

These results cover two synthetic sends on one Android 14 Tecno, a password-free
lock screen with hidden notice copy until unlock, and one short offline interval.
Expiry/revocation, actual duplicate FCM, natural Doze, long outages, reboot/direct
boot, recorder integration and two-phone delivery remain unverified. M6.8 is in
progress; no scheduler or real-contact alerts are enabled.

The next proposed cases are concrete in
[GUARDIAN_REJECTION_CHECK.md](GUARDIAN_REJECTION_CHECK.md). Their new isolated
SQL controls passed full CI 37646111095. The first reviewed duplicate phase passed
one receipt/tap, but the event expired before a second send; that window is closed,
worker retired and fixture cleaned. Actual duplicate suppression remains unverified;
the reference records a fresh-window review requirement.
