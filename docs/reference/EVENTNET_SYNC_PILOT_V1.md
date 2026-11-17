# EventNet parked synchronization pilot v1

## When to read

Use for the isolated software-marker app and host checker supporting the
[evidence-collection protocol](EVENTNET_EVIDENCE_COLLECTION_V1.md). This tool
provides reproducible draw journals and clock arithmetic, not physical clock,
recording, label or model acceptance. A separate camera/reference and physical
timing/strength evidence are still required. No new drive is requested.

## Isolated marker capture

`ml/android-sync-pilot` is a plain Java Android application with package
`io.github.atrx07.traelyx.syncpilot`, minimum SDK 24 / target 36. It uses the
existing AGP 9.0.1 / Gradle 9.1.0 toolchain. No app runtime dependency is packaged;
a build task rejects nonempty runtime artifacts. Automatic Kotlin stdlib is
disabled using the [documented Gradle property](https://kotlinlang.org/docs/gradle-configure-project.html#dependency-on-the-standard-library).
The separate package has no permissions, native library/model assets, recorder,
sensors, microphone/camera, network, provider/service/receiver or backup access.
It does not install over or change Traelyx, accounts, trips, scores or Guardian.

Build/lint using the existing SDK/Java 21 host setup:

```text
gradle -p ml/android-sync-pilot assembleDebug lintDebug --no-daemon
```

The current debug APK is `sync-pilot-v1.0.1` (version code 2) at
`ml/android-sync-pilot/build/outputs/apk/debug/TraelyxSyncPilot-debug.apk`.
It is development tooling, not a release APK/signing acceptance. Manual APK
installation and local export work without ADB; Android 10 compatibility is
declared by SDK settings, with real Redmi execution still unverified.

When a parked pilot is separately arranged:

1. Install the separate APK and open **Traelyx Sync Pilot**. Arrange the independent
   reference to observe the screen before starting; this app records no footage.
2. Tap **Start parked markers**. Identifiable `M0001`…`M0064` tokens advance roughly
   every two seconds. Scheduling is not assumed exact. The screen stays awake
   only during the active pilot; no wake permission/service is used.
3. Tap **Stop and save**. Moving the activity to the background also stops it;
   reopening does not restart. All runs remain separate private files. A process
   kill can leave an unfinished journal, which the host rejects.
4. Choose the desired retained journal in the selector and tap **Export selected
   private journal**. Use Android's file picker for a private local destination,
   then transfer by USB/MTP. Export cancellation/failure retains the source.
   Do not start a new trip or operate this while driving.

Each run contains at most 64 draw records; at most 64 journal files are retained
before new starts are refused. Nothing is automatically deleted. Journals are
atomically replaced within each run and earlier runs are preserved. Storage
failure stops the pilot without pretending a completed journal exists. No device
serial, account, wall-clock route time or sensor sample is recorded. Native boot
times and session aliases are still private, not public fixture material.

## What the timestamps establish

Each token records `SystemClock.elapsedRealtimeNanos()` immediately before and
after its Canvas draw commands. Android documents this as monotonic boot time
including deep sleep, unlike uptime clocks. See
[SystemClock](https://developer.android.com/reference/android/os/SystemClock) and
[View drawing](https://developer.android.com/reference/android/view/View#onDraw(android.graphics.Canvas)).
Journal writes occur outside that draw-command interval. The actual photons,
compositor/display scanout, camera exposure/rolling shutter and video PTS offsets
are **not** measured. A draw callback is not a presentation timestamp. A constant
unknown display delay can be absorbed by an affine offset and still produce
tiny residuals; that does not establish correct physical alignment. Journals
therefore always retain unknown presentation delay and false reference alignment.

## Reference observations and exact host audit

Copy [the empty observation template](sync-pilot-observations-v1.template.json)
into ignored private storage. It intentionally cannot pass until the required
identity, interval and diagnostic-budget fields are supplied. Hash the complete
journal and reference artifact; keep private paths/hashes out of Git.

Add at least two `fit` and two distinct `check` anchors in chronological sequence:

```json
{"sequence": 1, "role": "fit", "reference_before_ns": 0, "reference_after_ns": 33333333}
```

This row is illustrative only. Read actual frame PTS/time-base information, not
`frame_index / nominal_fps`. Convert rational PTS to nanoseconds with outward
rounding (lower bound down, upper bound up) and preserve its original time base
in the review evidence. Bracket the token transition between the last prior
frame and first frame that unambiguously shows the new token; account for any
ambiguous/partial frame. The host uses integer nanoseconds. It does not decode,
OCR or hash-open a video, verify its provenance or judge a human's observations.

Two outer fit anchors can fit the clock; independent interior check anchors
must also enclose the requested `native_start_ns`…`native_end_ns`. Endpoint
measurement intervals shrink the usable support. Do not claim the entire session
if only its interior is checked. The checker rejects duplicate/reused markers,
unordered/overlapping reference brackets, native resets, insufficient anchors,
extrapolation and rate drift beyond the supplied predeclared pilot bound.

`presentation_delay_bound_ns` is an independently justified nonnegative delay
ceiling after the draw interval; `reference_latency_bound_ns` is a symmetric
reference timestamp/capture uncertainty. Each requires its evidence SHA-256.
Keep either unknown as `null` with its evidence field null. Do not substitute
zero because the UI printed nanoseconds or a fitted residual was small. The
optional same-boot evidence hash is also only a declaration; the host does not
verify that a recorder/video came from that boot. Physical evidence remains a
separate review, and checked anchors do not bound all intervening drift.
For later recorder alignment, marker and recorder timestamps must come from the
same physical handset and boot with explicit recording bounds. Two phones' boot
clocks are not interchangeable. The isolated app cannot verify that binding.

The standard-library checker uses centered exact `Fraction` least squares for
reference-time → native-time mapping; large boot times never pass through
float64. Fit anchors alone determine slope/offset. Check error combines nominal
check residual, native draw/presentation interval width and scaled reference
bracket/capture uncertainty. It reports a ceiling in nanoseconds, not invented
precision. Unknown physical bounds produce an unknown checked error and an
unsatisfied budget. Diagnostic error/rate budgets must be chosen before checking
the pilot; they are not production acceptance thresholds.

```text
python -m tool.check_sync_pilot --journal <local.json> --expected-journal-sha256 <sha256> --observations <observations.json> --expected-observations-sha256 <sha256>
```

Inputs are bounded to 256 KiB each, pinned before parsing, strict-key/version
checked, and reject duplicate JSON keys, nonfinite/boolean/fractional timestamps,
unknown states and malformed bounds. Stdout contains aggregate private diagnostics
only: counts, residual/error ceilings, rate error and explicit blockers. It omits
aliases, raw times, paths, hashes, slope and offsets. Failures emit a fixed code,
not source data or filesystem exception details. Exit zero means the audit ran;
inspect its false verification/admission fields rather than treating it as pass.

For an explicitly requested private map, add `--private-map <new-local-file.json>`.
That file contains exact rational coefficients, supplied observations/hashes and
claimed bounds. Creation is exclusive; existing files and inputs are never
overwritten. It remains `precise_private`. No source/video upload, archive scan,
camera access, recorder operation or fitting of model weights occurs.

`declared_check_budget_satisfied` can become true only under the supplied bounds.
`physical_alignment_verified`, `between_anchor_error_bound_verified`,
`reference_artifact_verified`, `recording_binding_verified`, `training_admitted`
and `model_accepted` remain false even then. This is a candidate clock diagnostic,
not an automatic dataset-admission mechanism.

## Validation and limits

The [Tecno follow-up](sync-pilot-tecno-v1-result.json) verifies API34 software
capture/lifecycle/export via ADB inspection, without an external camera. It also
found and repaired the [inactive-pause export-selection reset](../issues/2026-11-17_sync-pilot-export-selection.md).
Earlier `sync-pilot-v1` / Pixel evidence remains a separate historical snapshot.

The repaired source adds a separate platform-only Android instrumentation APK:

```text
gradle -p ml/android-sync-pilot assembleDebug assembleDebugAndroidTest lintDebug --no-daemon
adb -s <selected-device> install --user <active-user> -r -t ml/android-sync-pilot/build/outputs/apk/androidTest/debug/TraelyxSyncPilot-debug-androidTest.apk
adb -s <selected-device> shell am instrument --user <active-user> -w -r io.github.atrx07.traelyx.syncpilot.test/io.github.atrx07.traelyx.syncpilot.PilotSelectionInstrumentation
```

Run only with the isolated pilot idle. The test creates two exclusive synthetic
selection fixtures, invokes real Android pause/resume callbacks and verifies a
nondefault selection is retained. It removes only its own files. Fixture content
is explicitly unsupported as clock evidence if interrupted. No new library is
required, and the test runner is absent from the main pilot APK. CI builds/lints
the harness; its actual lifecycle execution was verified on the Tecno, not claimed
as a headless CI device test. The full two-run file-picker cancel/retry and byte
comparison are additionally checked on the device.

Generated Java tests cover journal ordering, timestamp/cap/state rules and retained
snapshots; Python independently parses the Java output. Host tests exercise known
100 ppm drift above float64's exact integer range, disjoint holdouts, uncertainty,
unknown physical delays, budget failures, invalid input and private-map/CLI privacy.
Packaged APK checks reject permissions, extra components, SDK drift, native/model
assets and wrong package; CI builds/lints the same isolated target. Runtime/native
recorder and historical model behavior remain unchanged.

Emulator software smoke results and source/check outcomes are recorded in
[aggregate evidence](sync-pilot-v1-result.json). No emulator result establishes
optical timing, healthy phone sensors, driving truth or sustained battery behavior.
The next physical check needs a parked working phone plus an independent reference;
the Tecno's sensor offset is not applied and neither physical phone is operated
by this implementation unit. M7.4/M7.5 remain open and M8 inactive.
