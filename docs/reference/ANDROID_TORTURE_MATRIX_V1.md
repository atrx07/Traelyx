# M8.1 Android recorder torture matrix v1

## When to read

Use to reproduce bounded recorder lifecycle/failure checks. This is a QA
protocol, not permission to use live Guardian, replace the ordinary app, collect
a road trip or publish an APK. See the [active plan](../exec-plans/active/M8_ANDROID_HARDENING.md)
and [M7 acceptance/distribution boundary](M7_HANDOFF_V1.md).

## Isolation and evidence rules

`-PtraelyxRecorderHardening=true -PtraelyxFirebaseEnabled=false` opts debug builds
into `io.github.atrx07.traelyx.hardening`, a separate UID/storage/Keystore namespace.
Its test APK is `.hardening.test`. The QA manifest disables MainActivity and adds
a native, non-exported foreground host; Flutter/account initialization is absent.
The runner refuses the ordinary package before mutation, checks Firebase remains
uninitialized and checks that no Guardian provider marker exists. Default debug
and release identities remain unchanged; the QA activity is absent from them.

Do not install a QA artifact without checking its application ID. Never clear,
uninstall, force-stop, replace or delete files from the ordinary package for this
protocol. Discover ADB authorization, serial, boot completion, model/AVD identity
and main-recorder inactivity first. Coordinate device ownership with other work.
Personal unlock/debugging prompts remain personal; do not bypass a secure lock.

The operator fingerprints main recorder files, Guardian files and shared
preferences before/after every phase using on-device SHA-256. Raw file names and
hashes stay inside the operator process. This is preservation evidence for those
directories, not a database-upgrade rehearsal or a new hosted-account check.
Existing main-app trip history is never loaded by the QA app.

Passing recording observations require newly persisted accelerometer/gyroscope
samples and verified chunk progress, stable trip identity, a foreground notice,
and no writer overflow/late/write/time errors. Active-state alone is insufficient.
The verifier reads the committed chunk prefix while acquisition runs; a current
AtomicFile `.new` is not yet an orphan. Full catalogs are checked after Stop.
QA files are removed only from the journal-owned UUID after native stop and
finalization checks. A failed run retains its owned evidence for scoped cleanup.

## Matrix and limits

| Condition | Pixel_10, API37 | Tecno LH8n, API34 | Assertion / limitation |
| --- | --- | --- | --- |
| Duplicate Start | Executed | Executed | Same trip, no duplicate lifecycle |
| Activity recreation | 4 seconds progress | 4 seconds progress | Native recorder remains independent of Activity |
| Home/background | 8 seconds | 8 seconds | Both motion channels and chunks advance |
| Screen off | 10 seconds | 10 seconds | `isInteractive=false`, foreground notice, persisted motion advances |
| Location disabled/re-enabled | Controlled master switch and synthetic fix return | Device setting preserved; not run | IMU continues, provider-disabled health observed, fresh GPS accepted after restore |
| No active network | 6 seconds, airplane/Wi-Fi/data controlled | Radios preserved; not run | Accountless recording advances with `activeNetwork=null` |
| Battery saver | 6 seconds if Android accepts mode | Setting preserved; not run | Mode must be observed, otherwise explicitly unsupported; no efficiency claim |
| Service destruction/recreation | Executed | Executed | Same identity, explicit recovered state, committed checksums retained |
| Actual process interruption | Prepare → QA-only force-stop → PID absent → Resume | Same stationary method | Different process, pinned committed prefix retained, recovered flag and new motion/chunks |
| Stop/finalization/cleanup | Executed | Executed | Listeners/writer stop, notice removed, durable pending record, exact fixture cleanup |
| Queue/full-disk-like write rejection, invalid time, corrupt/truncated chunks | Existing JVM regression suites | Same software suites | Synthetic fault injection; no disk filling or user-file corruption |
| Deep suspend, real GNSS obstruction, reboot, OS/OEM kill, thermal/low-storage device behavior | Not established | Not established | Separate acceptance; USB/short tests cannot substitute |

“Screen off” is the tested display/power state; neither short test proves secure
keyguard operation or deep suspend. QA-only force-stop is a real process
interruption followed by explicit foreground recovery, not an Android low-memory
kill, automatic background restart guarantee or reboot test. An interrupted
atomic write may remain isolated: the verifier requires preserved committed
evidence and explicit incomplete/quality flags, never repairs it into a clean trip.
The present runs did not exercise an orphaned-write outcome on a device.

The controlled Pixel fixes use a constant synthetic `(1, 1)` emulator position,
not a real route or event truth. A zero-coordinate console attempt did not show
fix return within its bounded wait; this does not establish a recorder defect.
Physical sensor status, mount/frame quality, scoring truth and confidence gates
are unchanged. API34/API37 checks do not establish every supported Android/OEM.

## Reproduction

Use Java21 and the existing Android/Flutter toolchain. Follow the
[emulator runbook](ANDROID_EMULATOR_WORKFLOW.md) when device/host setup is needed.
Build from repository root, then copy both outputs into ignored `.dart_tool/`
before any ordinary build overwrites them:

```powershell
flutter build apk --debug --config-only
.\android\gradlew.bat -p android -PtraelyxRecorderHardening=true -PtraelyxFirebaseEnabled=false :app:assembleDebug :app:assembleDebugAndroidTest
# Check both application IDs using Android SDK apkanalyzer before installing.
# Outputs: build/app/outputs/apk/debug/app-debug.apk
#          build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
```

Flutter configuration must run first on a clean checkout: the wrapper
and local SDK setup are generated/ignored, not committed. CI exercises that order.

Install only those verified QA packages with explicit `adb -s $qaSerial install -r`.
Grant coarse/fine location and notifications to the QA package only. No mock
provider, global permission weakening, account setup or hosted endpoint is used.

```powershell
node tool/recorder_hardening.mjs --adb $adbExe --serial $qaSerial --kind pixel --phase matrix --output .dart_tool/pixel-matrix.json
node tool/recorder_hardening.mjs --adb $adbExe --serial $qaSerial --kind pixel --phase prepare --output .dart_tool/pixel-prepare.json
& $adbExe -s $qaSerial shell am force-stop io.github.atrx07.traelyx.hardening
# Require pidof io.github.atrx07.traelyx.hardening to report no process before Resume.
node tool/recorder_hardening.mjs --adb $adbExe --serial $qaSerial --kind pixel --phase resume --output .dart_tool/pixel-resume.json
```

Use `--kind tecno` for the verified Tecno serial. It omits GPS/radio/power toggles
and synthetic fix injection. Output files use exclusive creation: use fresh
names rather than overwrite failed evidence. `--phase cleanup` removes only the
QA journal's fixture; do not substitute the old lifecycle runner's cleanup modes.

Pixel settings are captured, restored and reread by the operator, including on
timeout. A failed operator command stops only QA before restoration, since killing
an ADB client alone may leave remote instrumentation alive. The runner also has
local restoration finally blocks. Both paths restore prior screen power state.
Successful Prepare deliberately leaves owned recovery evidence for interruption.
Check no QA recorder/journal remains after Resume/cleanup. Leave main data intact.

## Results and remaining gates

See [aggregate results](m8-android-v1-result.json) for exact durations and checks.
Source validation and CI are recorded in the active plan. These are bounded
stationary QA results, not acceptance of M6.8 active Guardian/vehicle/OEM behavior,
M7.4/M7.5 inference, or M8.2 battery/performance. Distribution remains held.
No new dependency, telemetry/schema/scoring version, sampling/batching/wake policy
or production behavior change is part of this matrix.
