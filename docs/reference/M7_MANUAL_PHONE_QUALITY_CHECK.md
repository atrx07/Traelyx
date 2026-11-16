# M7 manual phone quality check

## When to read

Use for the maintainer-authorized Redmi Note 9 / Android 10 stationary sensor
check. ADB, an MIUI account, a Traelyx account and API keys are not required.
This does not authorize a driving test or establish model acceptance.

## Build and private files

Use the ordinary `lib/main.dart` arm64 debug build, with no QA entrypoint,
account/provider configuration file or model activation. The app's minimum SDK
is 24 (Android 7); Android 10 is API 29. Installation and actual Redmi behavior
remain unverified until the maintainer reports the result. This is a development
APK, not a release/signing acceptance claim.

Task-local APK, hash and build log are under ignored `.dart_tool/m7-manual-phone/`.
Keep the export under that directory's `incoming/` folder on the computer. The
`.tripdebug` file contains precise location, wall times and raw motion; transfer
locally by USB/MTP, not public upload or a committed fixture. Preserve original
bytes. Source inspection is read-only and does not imply training consent.

## Stationary procedure

1. Copy the supplied APK to the Redmi and install it manually. If Android reports
   a signing/package conflict, retain the existing installation/data and report
   the message. Do not uninstall or clear data to resolve it.
2. Open Traelyx. Use local Drive mode without signing in. Allow location through
   its normal prompt so the recorder can start. Leave cloud, Guardian and optional
   providers unconfigured.
3. Put the phone screen-up on a stable level surface, ideally with a clear sky
   view for GPS. Start a drive recording while stationary. Leave the app visible
   and the phone untouched for 60 seconds. Do not travel, shake, drop or rotate
   the phone during this first check. A GPS limitation is a recorded result,
   not a reason to fabricate or override readiness.
4. End the recording and confirm the normal save. Wait until Drive shows the
   recorder idle and the saved recording is available.
5. On Drive, scroll to **Local tools → Export private drive fixture → Export
   private .tripdebug**. Choose a private local folder in Android's file picker.
   Copy that file to the computer's ignored `incoming/` folder by USB/MTP.
6. Report whether install/record/save/export passed and the local export filename.
   Any error text is useful; another recording is not automatically required.

This is a stationary QA recording. Keep it excluded from driving performance,
training and model evaluation. Do not label it as ordinary driving or a maneuver.
No raw file is committed or uploaded. If a step fails, preserve the existing
state; the result informs the next bounded investigation.

## Inspection criteria

Verify archive/hash/sequence/timestamp integrity, source accelerometer and
gyroscope accuracy/flags, GNSS availability, coverage gaps and stationary sample
behavior. Preserve all raw units, frames, sensor statuses and missing evidence.
One quiet minute does not prove calibration over orientations, stable mounting,
background reliability, driver diversity, driving labels or battery performance.
The existing Tecno offset proposal is not applied to the Redmi.
