# Android emulator workflow used during M6.8

## When to read

Use for the existing Windows-hosted Pixel emulator, ADB authorization, app
installation, UI inspection and recovery after an interrupted QA session.
This records the M6.8 workflow; it is not permission to repeat a completed live
test. Consult the current task/checkpoint before changing an account or device.

## Which device and why

- M6.8 initially used the physical Tecno Pova 5 Pro. The Redmi Note 9 proposed
  as the second phone blocked installation/input behind Xiaomi account/SIM
  requirements. The maintainer selected their existing **Pixel_10** Android
  Studio AVD instead; no new emulator or Android account was created by setup.
- The Pixel was the second, independently authenticated account and usually the
  Guardian recipient. The Tecno retained its original driver account and real
  local trips. The emulator was not used for all of M6.
- Existing AVD configuration inspected on 2026-11-16: display name **Pixel 10**,
  `AvdId=Pixel_10`, `x86_64`, Play Store enabled, image path
  `system-images\android-37.1\google_apis_playstore_ps16k\x86_64\`.
  Reuse the installed AVD; do not substitute a plain AOSP image for FCM QA.
- Its historical ADB serial was **emulator-5554**. Discover the current serial
  each session; ports/serials can change. Select every ADB operation explicitly
  when the physical phone is also connected.

## Host tools and launch

The verified host paths are:

```powershell
$sdkRoot = 'C:\Users\atrx07\AppData\Local\Android\Sdk'
$emulatorExe = Join-Path $sdkRoot 'emulator\emulator.exe'
$adbExe = Join-Path $sdkRoot 'platform-tools\adb.exe'

# Read-only inventory. Check for an existing running Pixel before launching.
& $emulatorExe -list-avds
& $adbExe devices -l
```

For a stopped or stalled saved session, the recovery launch used was:

```powershell
Start-Process -FilePath $emulatorExe `
  -ArgumentList @('-avd', 'Pixel_10', '-no-snapshot-load') `
  -WindowStyle Hidden
```

`-no-snapshot-load` cold-boots the existing AVD while retaining its user-data
disk. It does **not** wipe the app, accounts or Play Store state. Do not add
`-wipe-data`, delete/recreate the AVD or clear Traelyx data. Do not launch a second
copy when the AVD is already running. `-WindowStyle Hidden` applies to the
Windows launcher; this command does not use the emulator's `-no-window` option.

### Window behavior and personal ADB approval

Maintainer preference clarified on 2026-11-16: show the **emulator GUI**, but
keep launcher/helper terminal windows hidden. Use the direct `Start-Process`
pattern above; do not open a visible PowerShell/cmd wrapper for background
launching. Explain that the saved Pixel is opening before starting it. Do not
use `-no-window` when the maintainer needs to unlock Android or approve ADB.

Start the visible emulator first, then allow the maintainer to accept Android's
**Allow USB debugging?** prompt. If ADB reports `unauthorized`, pause device
operations and wait for that approval; continue unrelated host work only when
the current task is still authorized. Do not work around the prompt by changing
debugging keys, disabling authentication, or repeatedly starting alternate ADB
servers. Do not restart the user's existing ADB server merely for an unauthorized
device. Once the maintainer approves, rediscover the serial and verify readiness.

Wait for Android startup and inspect readiness with the discovered serial:

```powershell
$pixelSerial = 'emulator-5554' # Replace from the inventory above if different.
& $adbExe -s $pixelSerial get-state
& $adbExe -s $pixelSerial shell getprop sys.boot_completed
```

Require an authorized `device` state and boot completion `1`, then check that
Android services, network and the actual app screen are ready. ADB presence alone
does not establish those facts. If the sandbox blocks ADB's daemon/cache or the
emulator launcher, use the normal tool escalation path; do not reset devices or
alter global host configuration to bypass the restriction.

## Debugging authorization and UI control

- After several emulator restarts, ADB reported **unauthorized**. The maintainer
  unlocked the emulator and personally accepted **Allow USB debugging** for the
  computer. Recheck `adb devices -l` afterward. Do not assume a saved AVD stays
  authorized, or attempt ADB input while it is unauthorized.
- UI control used **ADB from terminal/Node scripts**, independent of browser
  control. Scripts invoked the official `adb.exe` with `execFile`, specifying
  `-s <serial>` and timeouts. `shell input tap`/`swipe` operated the Android UI.
- `shell uiautomator dump` created a specifically named temporary hierarchy file;
  scripts read it privately, found known labels/bounds, emitted only allowlisted
  status booleans and removed that exact temporary file. Raw XML can contain
  account details: do not print or commit it. Missing first dumps after launch
  are handled as documented in [known tooling issues](KNOWN_TOOLING_ISSUES.md).
- Screenshots used `exec-out screencap -p`, preserving binary output in ignored
  local files for inspection. Screenshots and raw device logs are not public QA
  artifacts by default. Check the actual current screen before tapping; do not
  reuse stale coordinates after a restart/dialog/navigation change.
- Coordinate emulator ownership with any other active agent/chat before
  installing a build, tapping controls or restarting it. Concurrent operators
  can replace each other's APK or invalidate account/recovery observations.

## App installation and authentication

Use a **current compatible configured debug build**, following
[AUTH_SETUP.md](AUTH_SETUP.md). Account builds used the ignored
`auth-config.local.json` via `--dart-define-from-file`; an unconfigured APK does
not provide the same account setup. Firebase receiver checks also require the
configured Firebase Android app and the specifically reviewed recipient pilot.
Do not reuse an old M6 APK over a newer database schema.

```powershell
# $apkPath must identify the build approved for the current task.
& $adbExe -s $pixelSerial install -r $apkPath
& $adbExe -s $pixelSerial shell am start -W `
  -n 'io.github.atrx07.traelyx/.MainActivity'
```

`install -r` was used for data-preserving updates and alternate QA entrypoints.
No uninstall or `pm clear` was used. After a scoped probe, restore the current
ordinary pilot-off app through another `-r` update and verify its actual screen,
sign-in and preservation results. Do not infer success solely from launch output.

The Gmail already signed into Play Store enabled access to that emulator's
Google environment; it **did not sign into Traelyx**. M6 used Supabase email-link
Auth, not Google OAuth. The maintainer personally entered a different email from
the Tecno account and opened the new link **inside the same Pixel emulator**
(Gmail/Chrome). Opening it on Windows or the Tecno is not an equivalent PKCE
callback. Neither addresses, links nor session credentials belong in chat/logs.

Guardian receiver registration was a separate personal review: the maintainer
checked both acknowledgements, confirmed and allowed Android notifications.
Sign-in or pairing alone never substitutes for that consent. Later fault checks
occasionally signed Pixel out, reconciled its old receiver on same-owner sign-in
and required fresh personal receiver consent. Do not replay these completed
checks from their historical approvals.

## What the emulator established

The Pixel supported two-account pairing/inbox roles, scoped FCM receipt/tap and
explicit alert-view checks, and reviewed recipient Auth loss, sign-out, offline
failure/retry, account replacement, normal refresh and terminal rejection/recovery.
The relevant reports start at [two-account checks](GUARDIAN_TWO_ACCOUNT_CHECK.md),
[receiver lifecycle](GUARDIAN_RECIPIENT_LIFECYCLE_CHECK.md) and
[terminal refresh/recovery](GUARDIAN_TERMINAL_REFRESH_CHECK.md).

Those results do not establish real sensor evidence, correct vehicle mounting,
active physical-driver ingestion, battery/performance or physical/OEM background
reliability. Later [desk-safe driver coverage](GUARDIAN_DRIVER_RECOVERY_REVIEW.md)
used JVM tests and fake services, not this emulator. Backend enable/send windows
were separately reviewed and disabled after testing; having the emulator running
is not authorization to enable or send anything.

## Resuming after interruption

1. Read the current task checkpoint and relevant report; distinguish a spent
   one-shot test from unfinished recovery. Ignored `.dart_tool/` manifests were
   private preservation evidence, not a substitute for this durable runbook.
2. Discover both devices. Reuse/cold-boot the existing Pixel only if needed;
   obtain personal debugging authorization if requested.
3. Recheck boot, network, app/build, sign-in, local registration and recorder
   state. Compare private recorder/receiver manifests before and after changes.
   Never print credentials or rebaseline away unexpected trip additions.
4. Resume only the remaining authorized operation. Keep ordinary app data and
   profiles intact; personally completed email-link/consent steps must not be
   automated or assumed from the previous session.

This runbook was reconstructed from the M6.8 execution record and saved operator
scripts on 2026-11-16. Paths and allowlisted AVD config were checked; neither
device was started, installed, inspected for account state or changed to write it.
