# M6.8 registered receiver sign-out and recovery check

## Scope and current gate

Reviewed live check passed and ordinary build restored 2026-10-21. Preparation
alone did not authorize production changes. The completed two-account alert
check is recorded in [GUARDIAN_TWO_ACCOUNT_CHECK.md](GUARDIAN_TWO_ACCOUNT_CHECK.md).
This check used the Pixel emulator's existing guardian account and registered
receiver; the Tecno driver stayed signed in. No vehicle mount, recording or alert ran.
Emulator evidence cannot establish physical-device reliability.

The existing explicit sign-out path must confirm the signed-in owner's exact
server device revocation before deleting local receipt/provider state and
releasing Auth. Failure must retain a retryable signed-in state. Same-account
sign-in must preserve pairing while requiring a new explicit receiver review;
it must not register automatically. Unexpected Auth loss, third-account switching
and failed-network recovery are separate cases, covered synthetically but not
proved by this successful online path.

## Reviewable implementation and preparation

- `lib/features/guardian/guardian_account_binding.dart`: driver Stop, account-bound
  device revoke, confirmed native cleanup, owner rechecks and local Auth sign-out.
- `guardian_recipient_registration.dart` in the same directory: fresh review,
  durable reservation, guarded registration and receipt/provider cleanup.
- Existing account-binding/device-registration suites pass 45 tests, including
  revoke-before-cleanup ordering, failures retaining Auth, local retry after a
  confirmed revoke, concurrent sign-out and account replacement during revoke.
- Prepare a configured debug APK with recipient pilot true and driver/sending
  pilots false. Preserve the tested ordinary pilot-off APK for restoration.
  Do not update-install the pilot or change either registration before review.

Preparation checks pass: all 45 targeted tests and the configured recipient-only
debug build. The ignored prepared APK is
`.dart_tool/m6_8_recipient_lifecycle_pilot.apk`, SHA-256
`dab210f08dc3463dfe74f361f0c816c19cdc9e27e00add130fd56bfef8e1192f`.
The preserved ordinary source `37906dc` APK retains SHA-256
`dea3a9249eb760a60e24e83f791e4388103bb3e09a20243a7d281821c740323d`.
No runtime code or tests were changed. Both devices reauthorized/online/idle,
Pixel's local receipt is retained, and the hosted baseline is still
0/0/0/2/2/1/1 with both flags false. The reviewed live result is below.

## Proposed production review

Request approval to update-install that pilot on Pixel without clearing data,
sign out only its current account, observe its existing private device row
removed, then let the maintainer sign back into that same account with an email
link inside Pixel. Fresh receiver consent is required before registration:
Firebase receives installation/device metadata and a replacement routing token;
Supabase stores the account-bound routing token and receipt authority. Do not
paste credentials, emails, links, routing tokens or private row IDs into chat.

Both Guardian processing flags remain false. Create no driver session, event,
delivery, worker credential, synthetic fixture, scheduler or push. Make no
pairing, profile, permission, trip or Google backend-key change. Existing Android
notification permission may be checked; this scope does not request a new one.
The M6.8 plan requires concrete production review for revocation/re-registration;
the maintainer personally completes email-link sign-in and receiver consent.

## Bounded sequence after approval

1. Recheck both devices authorized, online and idle; both driver vaults absent.
   Record fresh private recorder manifests. Verify the Pixel is the existing
   guardian and both account-bound local receipts remain valid. Hosted baseline
   must be sessions/events/deliveries/devices/unexpired/pairs/ready pairs =
   0/0/0/2/2/1/1, with both enable digests false and no test worker file.
2. Update-install the recipient-only pilot on Pixel. Verify retained sign-in,
   hidden driver controls, matching recorder/receiver bytes and existing local
   registration before touching Sign out. Never uninstall or clear app data.
3. Use Account's explicit Sign out once. Require signed-out UI, hosted devices
   1/unexpired 1 and unchanged pair count 1. Confirm Pixel receipt/provider marker
   are absent and no driver vault or alert exists. If revocation fails, stop;
   retain the signed-in/retry state and inspect without deleting local authority.
4. Let the maintainer request/open the same account's fresh sign-in link inside
   Pixel. Verify Signed in and the retained guardian pairing. Before any new
   review, device count must remain 1 and Check this phone must say unregistered.
   Startup/account binding must not silently recreate a routing token or row.
5. Present recipient review. The maintainer reads and confirms both unchecked
   acknowledgements. Verify success, devices/unexpired = 2/2, pair count 1 and
   local owner-bound registration. Stop on an uncertain result; no blind retries
   or SQL deletion to force expected counts. If the user declines, leave Pixel
   unregistered and report that outcome honestly.
6. Restore the ordinary pilot-off APK without clearing data. Reopen/check Pixel
   registration and pairing; leave both accounts signed in if recovery completed.
   Recorder hashes must remain unchanged. Pixel receiver ciphertext intentionally
   changes for revocation/new generation; do not require pre-sign-out equality
   or restore old ciphertext. Tecno receipt/provider state must remain unchanged.
7. Verify final baseline 0/0/0/2/2/1/1, both flags false, no driver vault/notice,
   no temporary credential, and no remaining pilot controls. Record results and
   limits, synchronize the active plan/status/README and commit/push atomically.

No short production enable window is needed; pause safely for the maintainer's
sign-in/consent while both endpoints stay disabled. This procedure does not
complete M6.8 or authorize the deferred mounted, driving or physical checks.

## Live result — 2026-10-21

The maintainer approved the complete Pixel sign-out/recovery scope, completed
the same-account email-link sign-in inside Pixel, and personally confirmed both
fresh recipient acknowledgements. No email address, link, token or private row
identity was collected in this report.

- Both devices started authorized, online and idle with both driver vaults
  absent. Fresh private manifests captured 11,857 Tecno recorder files and zero
  Pixel recorder files. Initial hosted baseline was 0/0/0/2/2/1/1.
- The reviewed recipient-only pilot update preserved Pixel's recorder, encrypted
  receipt and provider marker bytes. Account still showed Signed in. The app's
  explicit Sign out was invoked once; it completed with the signed-out/local-
  trips-preserved message. Pixel receipt/provider files were absent, while
  hosted baseline became 0/0/0/1/1/1/0. The existing pairing remained active.
  Tecno's trip, receipt and provider hashes remained identical.
- After the maintainer signed back into the same account, Pixel showed Signed
  in and its existing guardian role/paired state. Before fresh consent, both
  receipt/provider files remained absent, Check this phone said unregistered,
  and hosted counts stayed 0/0/0/1/1/1/0: sign-in did not automatically register.
  An unrelated unsubmitted invite review encountered during UI inspection was
  cancelled; no invite was created and no pairing/permission change was made.
- Fresh user consent produced a valid account-bound local registration and
  restored hosted baseline 0/0/0/2/2/1/1. The new encrypted receipt intentionally
  differs from the revoked one. No receipt plaintext was inspected or restored.
- The preserved ordinary pilot-off source `37906dc` APK was update-installed.
  Its new receipt/provider bytes match the post-registration/pre-update snapshot;
  the ordinary build retains Signed in and a successful Check this phone result,
  with no driver controls. Both accounts remain signed in. All recorder hashes
  match the fresh baselines; Tecno receipt/provider hashes remain unchanged and
  both driver vaults are absent.
- Final hosted counts remain 0/0/0/2/2/1/1, both enable digests still equal false,
  and no local worker credential exists. No driver session, event, delivery,
  push, scheduler, new permission, profile edit, migration or trip upload ran.
  Both endpoints stayed disabled throughout; no backend secret/key changed.

The 45 targeted regression tests and configured build passed during preparation;
this live run required no runtime code or test change. This closes only the
successful online explicit sign-out/same-account recovery gate on Pixel.
Unexpected Auth loss/journal reconciliation, third-account replacement,
failed-network recovery and physical registered-device reliability remain
unverified live. Mounted/active-native/recording/performance checks remain
deferred/open. M6.8 is incomplete.
