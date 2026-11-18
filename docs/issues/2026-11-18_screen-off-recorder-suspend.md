# Unplugged screen-off recorder gaps

**Status:** Confirmed evidence-continuity defect; repair passes bounded physical
lifecycle and locked/unplugged continuity checks. Source CI/fix commit pending.

## Symptoms / evidence

M8.2's third isolated Tecno LH8n/API34 profile QA run survived USB disconnection
but failed its recording measurement. Its 30-minute screen timeout was unchanged;
the maintainer manually locked the screen. The native recorder finalized after
1,045,297 ms of wall time without a recorder error or recovery.

An on-device, aggregate-only inspection found 197 verified chunks (599,976 bytes),
zero corruption, orphaned writes or ordering violations; 19,181 accelerometer and
19,216 gyroscope samples; zero GNSS fixes. Maximum motion gaps were
263,012.9 ms and 262,923.3 ms. Raw evidence was privately backed up before exact
journal-owned QA cleanup; its ignored local backup is retained. No routes, raw vectors, identifiers or
private timestamps belong in this record.

Main recorder/Guardian/preferences fingerprints match the pre-run checkpoint.
The ordinary app was never reinstalled, cleared or used to collect the fixture.
Earlier harness failures (`idle_screen_off` and intentional warm-up cancellation)
are separate and provide no battery evidence.

## Cause / limits

Confirmed: the active foreground recorder used default non-wake-up sensors and
held no partial CPU wake lock. That violates Android's delivery prerequisite for
these sources while the screen is off. The physical gaps establish that the
USB-connected short matrix was insufficient. CPU suspension is the supported
causal explanation; this does not independently rule out every OEM/sensor effect.

The QA timer also used `SystemClock.sleep`, which waits in uptime and can resume
late after deep sleep. The original full phase samples were not durably retained
on failure, so the precise instant/exception that ended the measurement cannot
be reconstructed. The report's stage is `recording_baseline`; it is not a crash
classification or valid battery estimate. See [Android clock semantics](https://developer.android.com/reference/android/os/SystemClock).

## Repair / validation requirements

[ADR-0044](../decisions/ADR-0044-recorder-owned-cpu-lease.md) defines recorder-owned
CPU power policy v1, explicit lifecycle release and fail-closed lease loss. The
normal WAKE_LOCK permission is added; sensor timing/quality/raw schema remain.
The observer holds no lock during recording. Partial measurements are persisted;
the separate CPU-awake post-recording control is explicitly labeled.

Five focused lease tests, all 601 native tests, app/profile lint and builds pass.
Physical duplicate Start, destruction/recovery, error teardown and Stop ownership
checks pass. The corrected locked/unplugged run passes 602 seconds with maximum
motion gaps 10.009/14.931 ms and exact fixture cleanup/main preservation. GNSS
was intermittent (maximum measured gap 41.999 s); continuous GNSS absence after
repair is not established. CPU is ~41% of one core, and idle's separately requested
observer lease did not exclude all suspend. See the qualified
[performance baseline](../reference/PERFORMANCE_BASELINE_V1.md). Source CI and
fix-commit reference remain pending. Preserve
SENSOR_UNRELIABLE evidence; do not infer calibration, vehicle truth or promotion.

## Recovery / remaining risk

Aggregate failed evidence and a private QA-only backup are retained before any
exact journal-owned cleanup. Do not restore, modify or rescore ordinary history.
Long-duration/OEM, real GNSS loss/return, vehicle operation, battery efficiency,
M6.8 Guardian and M7 inference acceptance remain separate. Publication is held.
