# Execution Plan — M8.2 battery/performance baseline

**Status:** Complete at the bounded baseline scope below
**Owner:** agent/maintainer
**Milestone:** M8.2
**Started / last updated:** 2026-11-18

## Goal / references

Establish reproducible, qualified baselines for recorder battery/CPU/memory/storage,
replay frames, 1,000-trip database queries, model disposition and APK size. Use
root/app/Android/test AGENTS, PERFORMANCE_BUDGETS and affected tracking/storage/
replay contracts. Results and reproduction live in
[PERFORMANCE_BASELINE_V1](../../reference/PERFORMANCE_BASELINE_V1.md) and the
[aggregate report](../../reference/m8-performance-v1-result.json).

User authorized M8.2 after M8.1 at `c0cbf00`. No M8.3 authorization, staged driving,
live Guardian/accounts, model activation, schema/scoring migration, dependency,
signing or distribution change. The installed ordinary app remains untouched.

## Evidence-driven scope amendment

Run three exposed ~263-second motion gaps without GNSS in an intact ~1,045-second
locked/unplugged trip. Default non-wake-up sensors lacked a recorder CPU lease.
Android's delivery prerequisite and attribution limits are in
[ADR-0044](../../decisions/ADR-0044-recorder-owned-cpu-lease.md) and the
[issue](../../issues/2026-11-18_screen-off-recorder-suspend.md).

Implement production CPU power policy v1: normal WAKE_LOCK permission,
non-reference-counted 120-second bounded acquisition, 30-second renewal,
start/recovery ownership, Stop/error/destruction release, explicit lost-lease
failure. No sampling/batching/frame/quality/history changes. Low battery usage
caused by missing samples cannot become an efficiency result.

## Gates

- [x] Inspect budgets/implementation and verify available Tecno.
- [x] Implement versioned workloads, quantiles, battery math and regression checks.
- [x] Execute host DB/APK, Android profile replay/DB and unplugged recorder observations.
- [x] Confirm precision limits, measured motion continuity, exact cleanup and main preservation.
- [x] Complete full source CI (local and post-fix process regressions pass).
- [x] Synchronize final status, commit/push and verify local HEAD equals origin/main.

## Collected results / limits

Fourth run finished before USB reconnection/unlock. Native progress is complete;
report passed, owned fixture cleanup true, main recorder/Guardian/preferences
fingerprints unchanged. User's 30-minute timeout was never changed. All recording/
idle samples and endpoints were unplugged/discharging, with zero screen-on
observations. Post-completion unlocking/movement is outside the measured windows.

- Recording: 602.481 s elapsed = uptime, ~41.155% one-core CPU, PSS p95 94,106 KiB,
  32–33 C. No observer lease during recording. High CPU cost remains a concern.
- Battery: one percentage point / 50,000 microAh observed drop. Extrapolation
  ~5.975 points/hour / 298.765 mA is coarse, not calibrated long-run acceptance.
- Raw committed-prefix growth: 2,987,255 bytes / 945 chunks, ~17.023 MiB/hour.
- Exact decoded-window motion: ~200.64 Hz per stream for 100 Hz requests,
  max gaps 10.009/14.931 ms. Frozen >=90%-rate and <=1,000-ms-gap checks pass.
  Unreliable-accuracy flags remain; no sensor calibration or model admission.
- GNSS: 488 exact-window samples, max gap 41.999 s. Continuous GNSS absence after
  repair is not established; do not conflate this run with run three.
- Idle observer: 184.446 s, 0.222% CPU, zero rounded battery change. Its requested
  separate bounded lease did not prevent 23.458 s elapsed-minus-uptime suspend.
  Neither continuously-awake nor deep-suspend idle is accepted; no energy subtraction.
- Final profile replay: 3,489 frames, build/raster p95 5.033/5.281 ms, 14/0 above
  16.67 ms, 120 Hz display. 3 s warm-up + 30 s; not full result UI/sustained thermal.
- Android profile DB: 1,000 trips/12,000 events/1,000 scores; 3 warm-ups + 20
  correctness-checked queries; history/detail p95 11.433/40.373 ms. Selected trip
  has 3,600 metadata chunks; no raw telemetry. DB allocated 4,427,776 bytes.
- Ordinary arm64 release-validation APK: 23,375,571 bytes, zero bundled model files.
  Native classifiers remain disabled; local neural narrator unavailable. Historical
  rejected M7 model timings do not establish production inference.

## Local validation / source provenance

- Flutter analysis and 595 Flutter tests pass; Dart workload unchanged since.
- All 601 native tests pass (533 app + 68 dependency), no failures/errors/skips;
  five focused lease tests cover duplicate/renewal/loss/expiry/failure/release.
- App debug lint and profile lint pass, with explicit API26/29 QA guards.
  Ignored local.properties restored byte-for-byte after temporary lint escaping.
- Ordinary debug/release builds pass; correct ordinary identity, CPU permission
  and QA component exclusion verified. Separate QA profile/AOT and debug/test
  builds pass; IDs checked before QA-only installs.
- Physical v4 power-lifecycle passes duplicate Start, destruction release,
  recovery acquisition, error release, Stop release and exact cleanup.
- Thirteen Node operator/math tests and one Python inventory test pass.
  Formatting and repository JSON/YAML/secret checks pass.
- Post-fix Tecno background/screen-off/service-recreation matrix passes, with
  motion/chunk progress and lease ownership/release. Finalization/cleanup and
  main preservation pass; physical radio/location/power settings preserved.
- Actual QA-process interruption/recovery passes: seven pinned committed chunks
  retained, recovered state and fresh motion/chunks observed, finalized fixture
  cleaned, main preservation unchanged.
  Source checkpoint `dfc316a` is pushed and local HEAD/origin/main matched.
  [Full source CI 44239049290](https://github.com/atrx07/Traelyx/actions/runs/44239049290)
  passes all four jobs, including profile build/lint, package isolation, native
  regressions and both ordinary builds. CI builds/lints profile QA, restores/checks
  ordinary identity and retains synthetic host/ordinary APK-model inventories.

Frozen artifact hashes are in the public aggregate report. Source base was
`c0cbf00`; no recorder/probe source changed between fourth-run installation and
these measurements. Host report math now additionally rejects screen-on/charging
samples and exposes elapsed-minus-uptime suspend; original private reports remain.

## Private checkpoints / resolved attempts

No phone run is waiting. Do not reuse historical unplug/reconnect instructions.
Collected fourth-run files (ignored):
`.dart_tool/m8-performance/recorder-before-fourth.json`,
`tecno-profile-recorder-fourth.json`, `tecno-profile-replay-v4.json`,
`power-lifecycle.json`. Profile binaries: `profile-qa-v4.apk`,
`profile-qa-test-v4.apk`; ordinary frozen artifact:
`ordinary-arm64-release-validation-v4.apk`.

Attempt one failed at idle_screen_off before timed measurement; user's Home-screen
observation and host transport interruption do not establish the exact cause.
Attempt two was intentionally canceled while USB-connected to fix stale visible
Preparing/Ready status. Neither provides battery evidence. Third-run raw evidence
was privately backed up as `third-recording-private-evidence.tar`, then only its
verified journal-owned fixture was cleaned before v4 installation. No raw vectors,
coordinates, serials, sample wall timestamps or private fingerprints are published.

## Completion summary

M8.2 is complete as a qualified baseline, with implementation `dfc316a` and all
four source CI jobs 44239049290 passing. Completion documents/report are committed
and pushed to main, with local HEAD/origin/main synchronization verified. No numeric
efficiency gate is invented from one run. Long-run CPU/battery optimization,
entirely GNSS-absent/OEM operation, mounted/vehicle/M6.8/M7 acceptance and
distribution remain open. No new dependency, schema/scoring migration, cloud
request or ordinary-app installation. Normal WAKE_LOCK permission accompanies
the recorder-owned policy. Stop for explicit M8.3 authorization; no work on it
has begun.

## Deferred optimization decision — 2026-11-18

Following the maintainer's sequencing discussion, keep M8.2 complete as a
baseline and defer recorder profiling to a required pre-release follow-up.
NEXTSTEPS and release-checklist.yaml require CPU/delivered-rate investigation,
longer unplugged battery/thermal/continuity measurement, and a recorded measured
optimization or efficiency-acceptance rationale. Preserve CPU ownership, sample
continuity and quality semantics. No optimization is implemented by this decision;
M8.3 remains the next approval-gated substep and distribution remains held.
