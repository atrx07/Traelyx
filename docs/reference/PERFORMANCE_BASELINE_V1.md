# M8.2 performance baseline v1

Scope: one stationary Tecno LH8n/API34, profile/AOT replay and native recorder QA,
plus an ordinary arm64 release-validation inventory. See the
[aggregate report](m8-performance-v1-result.json) for exact values and artifact
hashes, and the [execution plan](../exec-plans/active/M8_PERFORMANCE_BASELINE.md)
for source validation/CI. This establishes observations and regression workloads;
it does not accept field/OEM reliability or energy efficiency.

## Results and interpretation

| Workload | Observation | Limit |
| --- | --- | --- |
| Locked, unplugged recording | 602.481 s, CPU 41.155% of one core, PSS p95 94,106 KiB, 32–33 C | Includes native QA monitor overhead; substantial CPU cost needs investigation |
| Battery | One percentage point and 50,000 microAh reported drop; extrapolated 5.975 points/hour and 298.765 mA | A single coarse level step; counter calibration/resolution unvalidated; not a long-run prediction |
| Persisted storage | 2,987,255 bytes / 945 chunks added; 17.023 MiB/hour interval rate | Committed-prefix delta, not retained DB size or compression-independent payload |
| Measured-window motion | ~200.64 Hz per stream; max accelerometer/gyro gaps 10.009/14.931 ms | Request was 100 Hz; sensor rates are hints. Unreliable-accuracy flags retained |
| GNSS | 488 window samples, max gap 41.999 s | Intermittent fixes; does not repeat continuous GNSS absence from the failed run |
| Post-recording idle observer | 184.446 s, CPU 0.222%, PSS p95 88,463 KiB; zero rounded battery change | Separate CPU lease requested, but 23.458 s elapsed-minus-uptime suspend observed; neither continuously-awake nor deep-suspend idle acceptance |
| Profile replay | 3,489 frames; build/raster p95 5.033/5.281 ms; 14/0 above 16.67 ms | 30 s after 3 s warm-up, 120 Hz display; full result screen and sustained thermal load unmeasured |
| Profile DB | 1,000 trips / 12,000 events / 1,000 scores; history/detail p95 11.433/40.373 ms | Synthetic file-backed metadata fixture; 3,600 chunks on selected trip, no raw telemetry |
| APK | 23,375,571 bytes, zero bundled model files | Arm64 runnable Flutter payload; auxiliary libraries also include two other ABIs. Development signing, no distribution |

Recording elapsed time equaled uptime. Native QA held no observer CPU lease during
recording. Frozen pre-run continuity checks required at least 90% of requested
motion rate and maximum gaps <=1,000 ms per channel; both passed. Whole-trip
unreliable IMU samples remain explicit (126,370); no rejected samples, clock
discontinuities or dropout flags were observed. This does not establish sensor
truth or resolve the earlier ML input-quality gates. GNSS and motion count deltas
from committed chunks differ slightly from exact decoded-window counts because
chunk boundaries straddle window endpoints.

Idle's zero rounded drop does not mean zero consumption. The native report called
the control CPU-awake based on requested lease ownership; measured uptime shows
that description is not a tested guarantee. Retain the original evidence and
disclose the discrepancy. Never subtract this short control from recording to
claim attributable recorder battery drain. No numeric efficiency gate is set from
one coarse battery observation. CPU cost, delivered rates and longer-run battery
behavior remain explicit follow-up concerns.

## Workloads / reproduction

Use the existing Flutter/Android toolchain, Java21 and no new dependency. Run:

```powershell
flutter test test/performance/performance_baseline_test.dart
node --test tests/tool/test_recorder_hardening.mjs tests/tool/test_performance_math.mjs
python -W error::ResourceWarning -m unittest tests.tool.test_inventory_apk
```

The Flutter test writes host DB results to `build/reports/host-performance-v1.json`.
Host/JIT timing is separate from Android profile performance. Quantiles use nearest
rank, with 3 warm-ups and 20 correctness-checked production repository queries per
operation. The replay fixture uses 1,000 synthetic route points, two segments and
50 events with the production offline renderer, evidence timeline and normal-speed
clock. It opens only its temporary synthetic DB and deletes it before frame capture.

For profile device QA, follow the isolation/preservation rules in the
[Android matrix](ANDROID_TORTURE_MATRIX_V1.md). Build from the repository root:

```powershell
flutter build apk --profile --target tool/performance_probe.dart --target-platform android-arm64 --android-project-arg=traelyxRecorderHardening=true --android-project-arg=traelyxRecorderHardeningProfile=true --android-project-arg=traelyxFirebaseEnabled=false
.\android\gradlew.bat -p android '-PtraelyxRecorderHardening=true' '-PtraelyxRecorderHardeningProfile=true' '-PtraelyxFirebaseEnabled=false' '-Ptarget=tool/performance_probe.dart' :app:assembleProfileAndroidTest :app:lintProfile
```

Verify application IDs `.hardening` and `.hardening.test` before installing only
these isolated artifacts. Preserve copies/hashes under ignored `.dart_tool/`
before ordinary builds replace their output paths. Grant QA location/notifications
only. Never reinstall/clear/stop the ordinary app. No accounts, Firebase activation,
Guardian provider, hosted endpoint, telemetry upload or battery exemption is used.
The QA profile is debuggable for private extraction; Dart profile/AOT is verified.
Its shell entry is protected by `android.permission.DUMP`, not available to normal
apps; the native controller and replay host are absent from ordinary packages.

Supply verified `$adbExe` and `$qaSerial` explicitly. Use fresh output/checkpoint
names; operators refuse overwriting retained evidence:

```powershell
node tool/performance_device.mjs --adb $adbExe --serial $qaSerial --phase replay --checkpoint .dart_tool/replay-before.json --output .dart_tool/replay-result.json
node tool/performance_device.mjs --adb $adbExe --serial $qaSerial --phase recorder --checkpoint .dart_tool/recorder-before.json
# Verify visible Ready and saved ready_to_unplug_and_lock before unplugging.
# Manually lock, leave stationary/unused ~15 minutes, then reconnect/authorize ADB.
node tool/performance_device.mjs --adb $adbExe --serial $qaSerial --phase collect --checkpoint .dart_tool/recorder-before.json --output .dart_tool/recorder-result.json
```

The independent foreground controller survives host disconnect, waits for observed
discharging and manual lock, settles 10 s, records 10 min, stops/finalizes, settles
5 s, then observes post-recording idle for 3 min. Screen timeout is unchanged.
Native cumulative partials are saved every 10 s. On reconnection read progress
first; never start instrumentation while the controller is measuring. Unlocking
or movement after completed windows is outside the measurement. A failed run
retains its exact journal-owned evidence; inspect/back it up privately before
scoped cleanup. No broad directory wipe or ordinary-history operation is allowed.

Main recorder/Guardian/preferences fingerprints matched before/after. Successful
owned cleanup and finalized catalog checks passed. Public results contain only
aggregates and build hashes; no raw samples, routes, device serials, sample wall
timestamps or private fingerprints. Power policy v1 and its normal WAKE_LOCK
permission are documented in [ADR-0044](../decisions/ADR-0044-recorder-owned-cpu-lease.md).
No schema/scoring/model migration or dependency was introduced. Native inference
stays disabled; local neural narration remains unavailable. Historical M7 isolated
rejected-model timings do not admit a model. M6.8/M7 and distribution holds remain.
